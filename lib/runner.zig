const std = @import("std");

const NodeWeight = @import("root.zig").NodeWeight;
const revCmp = @import("util.zig").revCmp;
const WeightType = @import("root.zig").WeightType;

/// has optimizations specifically made for runtime
pub const RuntimeChain = struct {
    depth: u32,
    nodes: []*Node,
    random: std.Random,

    /// used for deserialized models to speed up loading
    deser_buf: DeserializedBuffer,

    pub const DeserializedBuffer = struct {
        weights: []NodeWeight,
        sequences: []u8,
    };

    pub const Node = struct {
        seq: []u8,
        weights: []NodeWeight,

        /// does not own seq or weights
        pub fn init(allocator: std.mem.Allocator, seq: []const u8, weights: []const NodeWeight) !*Node {
            const node = try allocator.create(Node);

            node.seq = seq;
            node.weights = weights;

            return node;
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }

        pub fn sample(self: *@This(), random: std.Random) u8 {
            var sum: usize = 0;
            for (self.weights) |w| sum += @intCast(w.weight);

            const num = random.intRangeLessThan(usize, 0, sum);
            sum = 0;
            for (self.weights) |w| {
                sum += @intCast(w.weight);
                if (sum > num) return w.char;
            }

            unreachable;
        }
    };

    pub fn init(depth: u32, nodes: []*Node, deser_buf: DeserializedBuffer) RuntimeChain {
        var alg = std.Random.RomuTrio.init(std.crypto.random.int(u64));
        return RuntimeChain{
            .nodes = nodes,
            .depth = depth,
            .deser_buf = deser_buf,
            .random = alg.random(),
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.nodes) |node| node.deinit(allocator);

        allocator.free(self.deser_buf.sequences);
        allocator.free(self.deser_buf.weights);
        allocator.free(self.nodes);
    }

    pub fn getNode(self: *@This(), seq: []const u8, matcher: NodeMatchType) ?*Node {
        var low: usize = 0;
        var high: usize = self.nodes.len;

        while (low < high) {
            const mid: usize = (low + high) / 2;
            const node = self.nodes[mid];

            switch (revCmp(seq, node.seq)) {
                .lt => high = mid,
                .gt => low = mid + 1,
                .eq => return node,
            }
        }

        return switch (matcher) {
            .precise => null,
            .nearest => if (self.nodes[low].seq[0] == seq[0]) self.nodes[low] else null,
        };
    }

    pub fn sampleNode(self: *@This(), seq: []const u8, matcher: NodeMatchType) ?u8 {
        const node = self.getNode(seq, matcher) orelse return null;
        return node.sample(self.random);
    }

    pub fn serializeYaml(self: *@This(), writer: std.io.AnyWriter) !void {
        try writer.print("depth: {d}\n", .{self.depth});
        try writer.print("node_count: {d}\n", .{self.nodes.len});

        var weights_count: usize = 0;
        for (self.nodes) |node| weights_count += node.weights.len;
        try writer.print("weights_count: {d}\n", .{weights_count});

        try writer.print("nodes:\n", .{});
        for (self.nodes) |node| {
            try writer.print("  - seq: {x}\n", .{node.seq});
            try writer.print("    weights:\n", .{});

            for (node.weights) |wt| {
                try writer.print("      - char: {d}\n      - weight: {d}\n", .{ wt.char, wt.weight });
            }
        }
    }
};

pub const NodeMatchType = enum { precise, nearest };
