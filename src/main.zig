const std = @import("std");

const lib = @import("grall_lib");

const commands = @import("commands.zig");

fn printUsage(out: anytype) !void {
    try out.print(
        \\usage: grall <command> [...args]
        \\
        \\commands:
        \\  train   <modelfile> <depth> [...text-files]
        \\  run     <modelfile>
        \\  yaml    <modelfile> <yamlfile>
        \\          convert model to yaml (for debugging)
        \\  help
        \\  version
        \\
    , .{});
}

fn run(allocator: std.mem.Allocator) anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const args_alloc = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_alloc);

    if (args_alloc.len == 1) {
        try printUsage(stderr);
        return error.Exit;
    }

    const command_str = args_alloc[1];
    const command = std.meta.stringToEnum(Command, command_str) orelse {
        try stdout.print("error: unknown command - {s}\n", .{command_str});
        return error.Exit;
    };

    switch (command) {
        .train => {
            if (args_alloc.len < 5) {
                try stderr.print("error: expected atleast 5 arguments, got {d}\n\n", .{args_alloc.len});
                try printUsage(stderr);
                return error.Exit;
            }

            const model_path = args_alloc[2];
            const depth_str = args_alloc[3];
            const text_files = args_alloc[4..];

            const depth = std.fmt.parseInt(u32, depth_str, 10) catch |err| {
                try stderr.print("error: invalid depth: {}\n", .{err});
                return error.Exit;
            };

            try commands.train(allocator, model_path, depth, text_files);
        },

        .run => {
            if (args_alloc.len < 3) {
                try stderr.print("error: expected atleast 3 arguments, got {d}\n\n", .{args_alloc.len});
                try printUsage(stderr);
                return error.Exit;
            }

            const model_path = args_alloc[2];
            const infinite = if (args_alloc.len > 3 and std.mem.eql(u8, args_alloc[3], "infinite")) true else false;
            const limit = if (args_alloc.len > 4) blk: {
                break :blk try std.fmt.parseInt(usize, args_alloc[4], 10);
            } else null;

            try commands.run(allocator, model_path, infinite, limit);
        },

        .yaml => {
            if (args_alloc.len != 4) {
                try stderr.print("error: expected exactly 4 arguments, got {d}\n\n", .{args_alloc.len});
                try printUsage(stderr);
                return error.Exit;
            }

            const model_path = args_alloc[2];
            const yaml_path = args_alloc[3];

            try commands.yaml(allocator, model_path, yaml_path);
        },

        .help => try printUsage(stdout),

        .version => try stdout.print(
            \\grall v{s}
            \\serializer format v{d}
            \\
        , .{ lib.VERSION, lib.serializer.VERSION }),
    }
}

const Command = enum { train, run, help, version, yaml };

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    run(allocator) catch |err| switch (err) {
        error.Exit => return 1,
        else => return err,
    };

    return 0;
}
