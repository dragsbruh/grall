const std = @import("std");

const NodeWeight = @import("root.zig").NodeWeight;
const revCmp = @import("util.zig").revCmp;
const WeightType = @import("root.zig").WeightType;

/// has optimizations specifically made for runtime
pub const RuntimeChain = struct {
    depth: u32,
    nodes: []Node,
    random: std.Random,

    /// used for deserialized models to speed up loading
    deser_buf: DeserializedBuffer,

    pub const DeserializedBuffer = struct {
        weights: []NodeWeight,
        cum_weights: []usize,
        sequences: []u8,
    };

    pub const Node = struct {
        seq: []u8,
        weights: []NodeWeight,

        // tradeoff memory for performance hopefully but if it goes well
        //ill remove storing seq/weights in node and directly access from deser buf
        cum_weights: []usize,

        /// does not own seq or (cum_weights, will recalculate cumulative weights anyway so fill that with undefined
        pub fn init(seq: []u8, weights: []NodeWeight, cum_weights: []usize) !Node {
            const node = Node{
                .seq = seq,
                .weights = weights,
                .cum_weights = cum_weights,
            };

            var sum: usize = 0;
            for (weights, 0..) |wt, wi| {
                sum += @intCast(wt.weight);
                node.cum_weights[wi] = sum;
            }

            return node;
        }

        pub fn sample(self: *@This(), random: std.Random) u8 {
            const num = random.intRangeLessThan(usize, 0, self.cum_weights[self.cum_weights.len - 1]);
            var sum: usize = 0;
            for (self.weights) |w| {
                sum += @intCast(w.weight);
                if (sum > num) return w.char;
            }

            unreachable;
        }
    };

    pub fn init(depth: u32, nodes: []Node, deser_buf: DeserializedBuffer) RuntimeChain {
        var alg = std.Random.RomuTrio.init(std.crypto.random.int(u64));
        return RuntimeChain{
            .nodes = nodes,
            .depth = depth,
            .deser_buf = deser_buf,
            .random = alg.random(),
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.deser_buf.sequences);
        allocator.free(self.deser_buf.weights);
        allocator.free(self.nodes);
    }

    pub fn sampleNode(self: *@This(), seq: []const u8, matcher: NodeMatchType) ?u8 {
        var low: usize = 0;
        var high: usize = self.nodes.len;

        while (low < high) {
            const mid: usize = (low + high) / 2;
            const node = &self.nodes[mid];

            switch (revCmp(seq, node.seq)) {
                .lt => high = mid,
                .gt => low = mid + 1,
                .eq => return node.sample(self.random),
            }
        }

        return switch (matcher) {
            .precise => null,
            .nearest => if (self.nodes[low].seq[0] == seq[0]) self.nodes[low].sample(self.random) else null,
        };
    }
};

pub const NodeMatchType = enum { precise, nearest };
