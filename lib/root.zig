const std = @import("std");

pub const NodeMatchType = @import("runner.zig").NodeMatchType;
pub const RuntimeChain = @import("runner.zig").RuntimeChain;
pub const serializer = @import("serialization.zig");
pub const TrainerChain = @import("training.zig").TrainerChain;

pub const VERSION = "0.0.1";

pub const SeqManager = struct {
    seq: []u8,

    pub fn init(allocator: std.mem.Allocator, size: usize) !SeqManager {
        var self = SeqManager{
            .seq = try allocator.alloc(u8, size),
        };
        self.reset();

        return self;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.seq);
    }

    pub fn reset(self: *@This()) void {
        for (0..self.seq.len) |i| self.seq[i] = 0;
    }

    pub fn push(self: *@This(), byte: u8) void {
        for (1..self.seq.len) |i| self.seq[i - 1] = self.seq[i];
        self.seq[self.seq.len - 1] = byte;
    }
};

test {
    std.testing.refAllDecls(@This());
}
