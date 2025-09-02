const std = @import("std");

const revCmp = @import("util.zig").revCmp;
const WeightType = @import("root.zig").WeightType;

/// has optimizations specifically made for runtime
pub const RuntimeChain = struct {
    depth: u32,
    nodes: []Node,
    random: std.Random.RomuTrio,

    /// used for deserialized models to speed up loading
    deser_buf: DeserializedBuffer,

    indexes: [256]?Index,

    pub const Index = struct { begin: usize, end: usize };

    pub const DeserializedBuffer = struct {
        sequences: []u8,
        weights: []Node.NodeWeight,
    };

    pub const Node = struct {
        seq: []u8,
        weights: []NodeWeight,

        // tradeoff memory for performance hopefully but if it goes well
        //ill remove storing seq/weights in node and directly access from deser buf
        // cum_weights: []usize,

        pub const NodeWeight = struct { char: u8, cum_weight: u32 };

        /// does not own seq or (cum_)weights. caller must also call .memoize() before sampling
        pub fn init(seq: []u8, weights: []NodeWeight) !Node {
            const node = Node{
                .seq = seq,
                .weights = weights,
            };

            return node;
        }

        pub fn sample(self: *@This(), random: *std.Random.RomuTrio) u8 {
            const num = random.random().intRangeLessThan(usize, 0, self.weights[self.weights.len - 1].cum_weight);
            for (self.weights) |w| {
                if (w.cum_weight > num) return w.char;
            }

            unreachable;
        }
    };

    /// must call .build_index() after this
    pub fn init(depth: u32, nodes: []Node, deser_buf: DeserializedBuffer) RuntimeChain {
        return RuntimeChain{
            .nodes = nodes,
            .depth = depth,
            .deser_buf = deser_buf,
            .random = std.Random.RomuTrio.init(std.crypto.random.int(u64)),
            .indexes = undefined,
        };
    }

    pub fn build_index(self: *@This()) void {
        var i: usize = 0;
        while (i < self.nodes.len) : (i += 1) {
            const b: u8 = self.nodes[i].seq[self.depth - 1];
            if (self.indexes[b] == null) {
                self.indexes[b] = .{ .begin = i, .end = i + 1 };
            } else {
                self.indexes[b].?.end = i + 1;
            }
        }
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.deser_buf.sequences);
        allocator.free(self.deser_buf.weights);
        allocator.free(self.nodes);
    }

    pub fn sampleNode(self: *@This(), seq: []const u8, matcher: NodeMatchType) ?u8 {
        const idx = self.indexes[seq[seq.len - 1]];
        var low: usize = if (idx) |i| i.begin else 0;
        var high: usize = if (idx) |i| i.end else self.nodes.len;

        while (low < high) {
            const mid: usize = (low + high) / 2;
            const node = &self.nodes[mid];

            switch (revCmp(seq, node.seq)) {
                .lt => high = mid,
                .gt => low = mid + 1,
                .eq => return node.sample(&self.random),
            }
        }

        return switch (matcher) {
            .precise => null,
            .nearest => if (self.nodes[low].seq[0] == seq[0]) self.nodes[low].sample(&self.random) else null,
        };
    }
};

pub const NodeMatchType = enum { precise, nearest };
