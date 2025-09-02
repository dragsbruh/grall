const std = @import("std");

const lib = @import("grall_lib");

const Task = struct {
    name: []u8,
    generated: usize,
    limit: usize,
    seq: lib.SeqManager,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.seq.deinit(allocator);
    }
};

pub fn api(allocator: std.mem.Allocator, model_path: []const u8) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var buffered_writer = std.io.bufferedWriter(stdout);
    var writer = buffered_writer.writer();

    var chain = blk: {
        const file = std.fs.cwd().openFile(model_path, .{}) catch |err| {
            try stderr.print("error: could not open file - {}\n", .{err});
            return error.Exit;
        };

        var buffered_reader = std.io.bufferedReader(file.reader());
        const reader = buffered_reader.reader().any();
        break :blk try lib.serializer.deserializeRunner(allocator, reader, null);
    };
    defer chain.deinit(allocator);

    try stdout.print("msg:model loaded\n", .{});
    try stdout.print("info:{d}:{d}\n", .{ chain.depth, chain.nodes.len });

    var pollFds = [_]std.posix.pollfd{
        .{ .fd = 0, .events = std.posix.POLL.IN, .revents = 0 },
    };

    var line_buffer: [4096]u8 = undefined;

    var tasks = std.StringHashMapUnmanaged(Task).empty;
    defer {
        var iter = tasks.valueIterator();
        while (iter.next()) |task| task.deinit(allocator);
        tasks.deinit(allocator);
    }

    var completedTasks = std.ArrayListUnmanaged([]const u8).empty;
    defer completedTasks.deinit(allocator);

    var delay: usize = 0;

    var flush_timer: usize = 0;
    var flush_max: usize = 20;

    while (true) {
        const timeout: i32 = if (tasks.size > 0) 0 else 20;
        const n = try std.posix.poll(&pollFds, timeout);
        if (n > 0 and (pollFds[0].revents & std.os.linux.POLL.IN) != 0) {
            const line = stdin.readUntilDelimiter(&line_buffer, '\n') catch |err| switch (err) {
                error.StreamTooLong => {
                    try stderr.print("error: buffer overflow\n", .{});
                    continue;
                },
                else => return err,
            };

            var iter = std.mem.tokenizeScalar(u8, line, ':');

            const command_str = iter.next() orelse continue;
            const command = std.meta.stringToEnum(Command, command_str) orelse {
                try stderr.print("error: unknown command - {s}\n", .{command_str});
                continue;
            };

            switch (command) {
                .new => {
                    const task_name_buf = iter.next() orelse {
                        try stderr.print("error: task name not provided\n", .{});
                        continue;
                    };
                    const task_name = try allocator.dupe(u8, task_name_buf);

                    const limit_str = iter.next() orelse "0";
                    const limit = std.fmt.parseInt(usize, limit_str, 10) catch |err| {
                        try stderr.print("error: could not parse limit `{s}` - {}\n", .{ limit_str, err });
                        continue;
                    };

                    var seq = try lib.SeqManager.init(allocator, chain.depth);

                    if (iter.next()) |a| for (a) |c| seq.push(c);

                    try tasks.put(allocator, task_name, Task{
                        .name = task_name,
                        .generated = 0,
                        .limit = limit,
                        .seq = seq,
                    });

                    try stdout.print("new:{s}\n", .{task_name});
                },

                .end => {
                    const task_name_buf = iter.next() orelse {
                        try stderr.print("error: task name not provided\n", .{});
                        continue;
                    };
                    const task_name = try allocator.dupe(u8, task_name_buf);

                    const task = tasks.fetchRemove(task_name);
                    if (task) |t| {
                        try stdout.print("end:{s}\n", .{task_name});
                        var tt = t.value;
                        tt.deinit(allocator);
                    } else {
                        try stderr.print("error: task not found `{s}`\n", .{task_name});
                    }
                },

                .delay => {
                    const delay_str = iter.next() orelse {
                        try stderr.print("error: no delay provided\n", .{});
                        continue;
                    };

                    delay = std.fmt.parseInt(usize, delay_str, 10) catch |err| {
                        try stderr.print("error: couldnt parse delay `{s}` - {}\n", .{ delay_str, err });
                        continue;
                    };
                    try stdout.print("delay:{d}\n", .{delay});
                },

                .quit => return,

                .flush => try buffered_writer.flush(),

                .setflush => {
                    const flush_max_str = iter.next() orelse {
                        try stderr.print("error: no max flush timer provided\n", .{});
                        continue;
                    };

                    flush_max = std.fmt.parseInt(usize, flush_max_str, 10) catch |err| {
                        try stderr.print("error: couldnt parse flush max `{s}` - {}\n", .{ flush_max_str, err });
                        continue;
                    };
                    try stdout.print("flush:{d}\n", .{flush_max});
                },
            }
        }

        var iter = tasks.valueIterator();
        while (iter.next()) |task| {
            defer if (delay != 0) std.Thread.sleep(delay * std.time.ns_per_ms / tasks.size);

            const byte = chain.sampleNode(task.seq.seq, .nearest) orelse {
                try completedTasks.append(allocator, task.name);
                continue;
            };
            task.seq.push(byte);

            try writer.print("g:{s}:{c}\n", .{ task.name, byte });

            task.generated += 1;
            if (task.limit > 0 and task.generated >= task.limit) try completedTasks.append(allocator, task.name);
        }

        for (completedTasks.items) |task_name| {
            try buffered_writer.flush();
            try stdout.print("end:{s}\n", .{task_name});
            const task = tasks.fetchRemove(task_name);
            if (task) |t| {
                var tt = t.value;
                tt.deinit(allocator);
            }
        }
        completedTasks.clearRetainingCapacity();

        if (flush_max > 0) {
            flush_timer += 1;
            if (flush_timer > flush_max) {
                flush_timer = 0;
                try buffered_writer.flush();
            }
        }
    }
}

const Command = enum { new, end, delay, quit, flush, setflush };
