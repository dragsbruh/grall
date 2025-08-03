const std = @import("std");
const io = @import("io.zig");

pub fn start(allocator: std.mem.Allocator) anyerror!void {
    const input = "123 67 89,99";

    var list = std.ArrayList(u32).init(allocator);
    // Ensure the list is freed at scope exit.
    // Try commenting out this line!
    defer list.deinit();

    var it = std.mem.tokenizeAny(u8, input, " ,");
    while (it.next()) |num| {
        const n = try std.fmt.parseInt(u32, num, 10);
        try list.append(n);
    }

    try io.stdout.print("{any}\n", .{list.items});
}
