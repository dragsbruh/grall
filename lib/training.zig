const std = @import("std");

const revCmp = @import("util.zig").revCmp;

pub const TrainerChain = struct {
    depth: u32,
    nodes: [256]std.ArrayListUnmanaged(Node),

    pub const Node = struct {
        seq: []u8,
        weights: std.ArrayListUnmanaged(NodeWeight),

        pub const NodeWeight = struct { char: u8, weight: u32 };

        pub fn init(allocator: std.mem.Allocator, seq: []const u8) !Node {
            return Node{
                .seq = try allocator.dupe(u8, seq),
                .weights = .empty,
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.weights.deinit(allocator);
            allocator.free(self.seq);
        }

        pub fn feed(self: *@This(), allocator: std.mem.Allocator, char: u8) !void {
            var low: usize = 0;
            var high: usize = self.weights.items.len;

            while (low < high) {
                const mid: usize = (low + high) / 2;
                var item: *NodeWeight = &self.weights.items[mid];

                switch (std.math.order(char, item.char)) {
                    .lt => high = mid,
                    .gt => low = mid + 1,
                    .eq => {
                        item.weight += 1;
                        return;
                    },
                }
            }

            try self.weights.insert(allocator, low, NodeWeight{
                .char = char,
                .weight = 1,
            });
        }
    };

    pub fn init(depth: u32) TrainerChain {
        var self = TrainerChain{
            .depth = depth,
            .nodes = undefined,
        };

        for (0..self.nodes.len) |i| self.nodes[i] = .empty;

        return self;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (0..self.nodes.len) |i| {
            for (0..self.nodes[i].items.len) |j| self.nodes[i].items[j].deinit(allocator);
            self.nodes[i].deinit(allocator);
        }
    }

    pub fn incrementWeight(self: *@This(), allocator: std.mem.Allocator, seq: []const u8, byte: u8) !void {
        const hunk = &self.nodes[seq[seq.len - 1]];

        var low: usize = 0;
        var high: usize = hunk.items.len;

        while (low < high) {
            const mid: usize = (low + high) / 2;
            const node: *Node = &hunk.items[mid];

            switch (revCmp(seq, node.seq)) {
                .lt => high = mid,
                .gt => low = mid + 1,
                .eq => {
                    try node.feed(allocator, byte);
                    return;
                },
            }
        }

        var node = try Node.init(allocator, seq);
        try node.feed(allocator, byte);
        try hunk.insert(allocator, low, node);
    }
};
