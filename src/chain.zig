const std = @import("std");

pub const Node = struct {
    value: []const u8,

    // the char is the index
    weights: [256]usize = undefined,

    pub fn init(allocator: std.mem.Allocator, value: []const u8) !*Node {
        const node = try allocator.create(Node);
        node.value = try allocator.dupe(u8, value);
        for (0..node.weights.len) |i| node.weights[i] = 0;
        return node;
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub const Chain = struct {
    depth: u32,

    nodes: std.ArrayListUnmanaged(*Node),

    pub fn init(depth: u32) Chain {
        return Chain{
            .depth = depth,
            .nodes = .empty,
        };
    }

    /// insertion -> returns null if found and actual index if not found and closest
    /// selection -> returns null if not found and actual index only if found
    pub inline fn node_index(self: @This(), value: []const u8) ?u32 {
        var low: u32 = 0;
        var high: u32 = @intCast(self.nodes.items.len);

        while (low < high) {
            const mid = (low + high) / 2;
            switch (cmp_fixed(value, self.nodes.items[mid].*.value)) {
                -1 => high = mid,
                1 => low = mid + 1,
                0 => return mid,
                else => unreachable,
            }
        }

        return null;
    }

    /// state -> a string
    /// next_char -> the char that comes after the "state"
    pub fn train_char(self: *@This(), allocator: std.mem.Allocator, state: []const u8, next_char: u8) !void {
        const node = try self.get_create_node(allocator, state);
        node.*.weights[next_char] += 1;
    }

    pub fn predict_char(self: *@This(), state: []const u8) ?u8 {
        const node = self.get_node(state) orelse return null;
        return @intCast(std.crypto.random.weightedIndex(usize, &node.weights));
    }

    pub fn get_node(self: @This(), value: []const u8) ?*Node {
        const index = self.node_index(value) orelse return null;
        return self.nodes.items[index];
    }

    pub fn create_node(self: *@This(), allocator: std.mem.Allocator, value: []const u8) !*Node {
        const node = try Node.init(allocator, value);
        try self.nodes.append(allocator, node);
        return node;
    }

    pub fn get_create_node(self: *@This(), allocator: std.mem.Allocator, value: []const u8) !*Node {
        return self.get_node(value) orelse try self.create_node(allocator, value);
    }

    pub fn sort(self: *@This()) void {
        std.mem.sort(*Node, self.nodes.items, {}, struct {
            pub fn inner(_: void, a: *Node, b: *Node) bool {
                return cmp_fixed(a.*.value, b.*.value) == -1;
            }
        }.inner);
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.nodes.items) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        self.nodes.deinit(allocator);
    }
};

// assume lhs len = rhs len
// made it 2x faster for depth 5 on my machine
fn cmp_fixed(lhs: []const u8, rhs: []const u8) i32 {
    for (lhs, rhs) |a, b| {
        if (a < b) return -1;
        if (a > b) return 1;
    }
    return 0;
}
