const std = @import("std");
const io = @import("./io.zig");

const Chain = @import("chain.zig").Chain;
const Node = @import("chain.zig").Node;

pub fn train(allocator: std.mem.Allocator, args_alloc: [][:0]u8) !void {
    if (args_alloc.len < 3) {
        try io.stderr.print("error: incorrect number of arguments\n", .{});
        try io.stderr.print("usage: train <depth>\n", .{});
        return error.Exit;
    }

    const depth = std.fmt.parseInt(u32, args_alloc[2], 10) catch |err| switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => {
            try io.stderr.print("error: invalid depth - {s}\n", .{args_alloc[2]});
            return error.Exit;
        },
        else => {
            return err;
        },
    };

    var chain = Chain.init(depth);
    defer chain.deinit(allocator);
}
