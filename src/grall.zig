const std = @import("std");
const io = @import("io.zig");

const train = @import("train.zig").train;

pub fn start(allocator: std.mem.Allocator) anyerror!void {
    const args_alloc = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_alloc);

    if (args_alloc.len == 1) {
        try io.stderr.print("error: no command provided\n", .{});
        return error.Exit;
    }

    const command = std.meta.stringToEnum(Command, args_alloc[1]) orelse {
        try io.stderr.print("error: unknown command - {s}\n", .{args_alloc[1]});
        return error.Exit;
    };

    try switch (command) {
        .train => train(allocator, args_alloc),
    };
}

const Command = enum { train };
