const std = @import("std");

const lib = @import("grall_lib");

const Task = struct {
    name: []u8,
    generated: usize,
    limit: usize,
    seq: lib.SeqManager,
    delay: usize,
    token_buf: [4]u8,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.seq.deinit(allocator);
    }
};

const data_types = struct {
    pub fn read_u32(reader: std.io.AnyReader) !u32 {
        return try reader.readInt(u32, .big);
    }

    pub fn write_u32(writer: std.io.AnyWriter, value: u32) !void {
        try writer.writeInt(u32, value, .big);
    }

    pub fn read_opcode(reader: std.io.AnyReader) !Opcode {
        const byte = try reader.readByte();
        const opcode = try std.meta.intToEnum(Opcode, byte);
        return opcode;
    }

    pub fn write_rescode(writer: std.io.AnyWriter, rescode: Rescode) !void {
        try writer.writeByte(@intFromEnum(rescode));
    }

    pub fn read_sequence(allocator: std.mem.Allocator, reader: std.io.AnyReader) ![]u8 {
        const len = try read_u32(reader);
        const seq = try allocator.alloc(u8, len);
        try reader.readNoEof(seq);
        return seq;
    }

    pub fn write_sequence(writer: std.io.AnyWriter, seq: []const u8) !void {
        try write_u32(writer, @intCast(seq.len));
        try writer.writeAll(seq);
    }
};

const Opcode = enum(u8) {
    ping = 1,
    new = 2,
    end = 3,
    delay = 4,
    close = 5,
};

const Rescode = enum(u8) {
    pong = 1,
    gen = 2,
    end = 3,
    err = 4,
};

fn processCommand(
    allocator: std.mem.Allocator,
    tasks: *std.StringHashMapUnmanaged(Task),
    chain: *lib.RuntimeChain,
    reader: std.io.AnyReader,
    writer: std.io.AnyWriter,
) !void {
    const opcode_raw = try reader.readByte();

    const op = std.meta.intToEnum(Opcode, opcode_raw) catch {
        var buf: [1024]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "unknown opcode - {d}", .{opcode_raw});

        try data_types.write_rescode(writer, .err);
        try data_types.write_sequence(writer, msg);
        return;
    };

    switch (op) {
        .new => {
            const name = try data_types.read_sequence(allocator, reader);
            const seed = try data_types.read_sequence(allocator, reader);
            defer allocator.free(seed);

            const limit = try data_types.read_u32(reader);
            const delay = try data_types.read_u32(reader);

            var task = Task{
                .name = name,
                .delay = delay,
                .limit = limit,
                .generated = 0,
                .token_buf = undefined,
                .seq = try lib.SeqManager.init(allocator, chain.depth),
            };
            for (seed) |c| task.seq.push(c);

            try tasks.put(allocator, name, task);
        },

        .end => {
            const name = try data_types.read_sequence(allocator, reader);

            const task = tasks.fetchRemove(name);
            if (task) |t| t.value.deinit(allocator);
        },

        .ping => {
            try data_types.write_rescode(writer, .pong);
        },

        .delay => {
            const name = try data_types.read_sequence(allocator, reader);
            const delay = try data_types.read_u32(reader);

            const task = tasks.getPtr(name);
            if (task) |t| t.delay = delay;
        },

        .close => return error.Close,
    }
}

fn connHandler(allocator: std.mem.Allocator, chain: *lib.RuntimeChain, conn: std.net.Server.Connection) !void {
    defer conn.stream.close();

    const reader = conn.stream.reader().any();
    const writer = conn.stream.writer().any();

    var seq = try lib.SeqManager.init(allocator, chain.depth);
    defer seq.deinit(allocator);

    var prng = std.Random.RomuTrio.init(std.crypto.random.int(u64));
    var random = prng.random();

    var tasks = std.StringHashMapUnmanaged(Task).empty;
    defer {
        var iter = tasks.valueIterator();
        while (iter.next()) |t| t.deinit(allocator);

        tasks.deinit(allocator);
    }

    var fds = [_]std.posix.pollfd{
        .{ .fd = conn.stream.handle, .events = std.posix.POLL.IN, .revents = 0 },
    };

    var inputBuffer = std.ArrayList(u8).init(allocator);
    defer inputBuffer.deinit();

    var completedTasks = std.ArrayListUnmanaged([]const u8).empty;
    defer completedTasks.deinit(allocator);

    try data_types.write_rescode(writer, .pong);

    while (true) {
        const n = try std.posix.poll(&fds, if (tasks.size > 0) 0 else 10);
        if (n > 0 and (fds[0].revents & std.posix.POLL.IN) != 0) {
            processCommand(allocator, &tasks, chain, reader, writer) catch |err| switch (err) {
                error.Close => return,
                else => return err,
            };
        }

        var iter = tasks.valueIterator();
        ol: while (iter.next()) |task| {
            for (0..4) |i| {
                const maybe_byte = chain.sampleNode(task.seq.seq, .nearest, &random);
                if (maybe_byte) |byte| {
                    task.token_buf[i] = byte;
                    task.seq.push(byte);
                } else {
                    if (i > 0) {
                        try data_types.write_rescode(writer, .gen);
                        try data_types.write_sequence(writer, task.name);
                        try data_types.write_sequence(writer, task.token_buf[0..i]);
                    }

                    try completedTasks.append(allocator, task.name);
                    if (task.delay > 0) std.Thread.sleep(task.delay * std.time.ns_per_ms);
                    continue :ol;
                }
            }

            try data_types.write_rescode(writer, .gen);
            try data_types.write_sequence(writer, task.name);
            try data_types.write_sequence(writer, &task.token_buf);

            task.generated += 4;
            if (task.limit > 0 and task.generated >= task.limit) try completedTasks.append(allocator, task.name);
            if (task.delay > 0) std.Thread.sleep(task.delay * std.time.ns_per_ms);
        }

        for (completedTasks.items) |task_name| {
            const task = tasks.fetchRemove(task_name) orelse continue;
            defer task.value.deinit(allocator);

            try data_types.write_rescode(writer, .end);
            try data_types.write_sequence(writer, task_name);
        }
    }
}

pub fn start(allocator: std.mem.Allocator, model_path: []const u8, socket_path: []const u8) !void {
    const stderr = std.io.getStdErr().writer();

    var chain = blk: {
        const file = std.fs.cwd().openFile(model_path, .{}) catch |err| {
            try stderr.print("error: could not open file - {}\n", .{err});
            return error.Exit;
        };
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());
        const reader = buffered_reader.reader().any();

        break :blk try lib.serializer.deserializeRunner(allocator, reader, null);
    };
    defer chain.deinit(allocator);

    try stderr.print("starting unix socket on {s}\n", .{socket_path});

    std.fs.cwd().deleteFile(socket_path) catch {};

    const addr = try std.net.Address.initUnix(socket_path);
    var server = try addr.listen(.{});

    var threads = std.ArrayListUnmanaged(std.Thread).empty;
    defer {
        for (threads.items) |t| t.join();
        threads.deinit(allocator);
    }

    while (true) {
        const conn = try server.accept();
        const t = try std.Thread.spawn(.{}, struct {
            pub fn inner(ally: std.mem.Allocator, cha: *lib.RuntimeChain, con: std.net.Server.Connection) !void {
                connHandler(ally, cha, con) catch |err| {
                    try std.io.getStdErr().writer().print("error in conn handler: {}\n", .{err});
                };
            }
        }.inner, .{ allocator, &chain, conn });
        try threads.append(allocator, t);
    }
}
