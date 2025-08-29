const std = @import("std");

const NodeWeight = @import("root.zig").NodeWeight;
const revCmp = @import("util.zig").revCmp;
const WeightType = @import("root.zig").WeightType;

pub const TrainerChain = struct {
    depth: u32,
    nodes: std.ArrayListUnmanaged(*Node),

    pub const Node = struct {
        seq: []u8,
        weights: std.ArrayListUnmanaged(NodeWeight),

        pub fn init(allocator: std.mem.Allocator, seq: []const u8) !*Node {
            const self = try allocator.create(Node);

            self.seq = try allocator.dupe(u8, seq);
            self.weights = .empty;

            return self;
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.weights.deinit(allocator);
            allocator.free(self.seq);
            allocator.destroy(self);
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

    pub fn init(depth: u32) !TrainerChain {
        return TrainerChain{
            .depth = depth,
            .nodes = .empty,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.nodes.items) |node| node.deinit(allocator);

        self.nodes.deinit(allocator);
    }

    pub fn getNode(self: *@This(), allocator: std.mem.Allocator, seq: []const u8) !*Node {
        var low: usize = 0;
        var high: usize = self.nodes.items.len;

        while (low < high) {
            const mid: usize = (low + high) / 2;
            const node: *Node = self.nodes.items[mid];

            switch (revCmp(seq, node.seq)) {
                .lt => high = mid,
                .gt => low = mid + 1,
                .eq => return node,
            }
        }

        const node = try Node.init(allocator, seq);
        try self.nodes.insert(allocator, low, node);

        return node;
    }
};
