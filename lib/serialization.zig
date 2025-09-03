const std = @import("std");

const RuntimeChain = @import("runner.zig").RuntimeChain;
const TrainerChain = @import("training.zig").TrainerChain;

/// serializer version is different from main version since i dont think ill change the model format much
pub const VERSION: u8 = 1;

// FORMAT
// root -> GRIL{version:u8}{depth:u32}{node_count:u32}{total_weights_count:u32}{content}LIRG
// content -> {node * node_count}
// node -> {node_weights_count-1:u8}{seq:[]u8}{char_weight * node_weights_count}
// char_weight -> {char:u8}{weight:u32}

// ill probably add gzipping

/// ends progress
pub fn serializeTrainer(chain: TrainerChain, writer: std.io.AnyWriter, progress: ?std.Progress.Node) !void {
    defer if (progress) |p| p.end();

    try writer.writeAll("GRIL");
    try writer.writeByte(VERSION);

    try writer.writeInt(u32, chain.depth, .little);
    try writer.writeInt(u32, @intCast(chain.nodes.items.len), .little);

    var weights_count: usize = 0;

    if (progress) |p| p.setEstimatedTotalItems(chain.nodes.items.len);
    for (chain.nodes.items) |node| weights_count += node.weights.items.len;

    try writer.writeInt(u32, @intCast(weights_count), .little);

    for (chain.nodes.items) |node| {
        try writer.writeByte(@intCast(node.weights.items.len - 1));
        try writer.writeAll(node.seq);
        for (node.weights.items) |wt| {
            try writer.writeByte(wt.char);
            try writer.writeInt(u32, wt.weight, .little);
        }

        if (progress) |p| p.completeOne();
    }

    try writer.writeAll("LIRG");
}

/// ends progress
pub fn deserializeRunner(allocator: std.mem.Allocator, reader: std.io.AnyReader, progress: ?std.Progress.Node) !RuntimeChain {
    defer if (progress) |p| p.end();

    var endsBuf: [4]u8 = undefined; // storing GRIL and LIRG
    _ = try reader.readAll(&endsBuf);
    if (!std.mem.eql(u8, &endsBuf, "GRIL")) return error.InvalidHeader;

    if (try reader.readByte() != VERSION) return error.VersionMismatch;

    const depth = try reader.readInt(u32, .little);
    const node_count = try reader.readInt(u32, .little);
    const weights_count = try reader.readInt(u32, .little);

    if (progress) |p| p.setEstimatedTotalItems(node_count);

    var chain = RuntimeChain.init(
        depth,
        try allocator.alloc(RuntimeChain.Node, node_count),
        RuntimeChain.DeserializedBuffer{
            .weights = try allocator.alloc(RuntimeChain.Node.NodeWeight, weights_count),
            .sequences = try allocator.alloc(u8, node_count * depth),
        },
    );

    var weights_offset: usize = 0;
    for (0..node_count) |i| {
        const node_weights_count: usize = @as(usize, @intCast(try reader.readByte())) + 1;

        var node = try RuntimeChain.Node.init(
            chain.deser_buf.sequences[i * depth .. (i + 1) * depth],
            chain.deser_buf.weights[weights_offset .. weights_offset + node_weights_count],
        );

        weights_offset += node_weights_count;

        _ = try reader.readAll(node.seq);
        var weight_sum: u32 = 0;
        for (0..node_weights_count) |wi| {
            const char = try reader.readByte();
            const weight = try reader.readInt(u32, .little);

            weight_sum += weight;

            node.weights[wi] = RuntimeChain.Node.NodeWeight{
                .char = char,
                .cum_weight = weight_sum,
            };
        }

        chain.nodes[i] = node;
        if (progress) |p| p.completeOne();
    }

    _ = try reader.readAll(&endsBuf);
    if (!std.mem.eql(u8, &endsBuf, "LIRG")) return error.InvalidHeader;

    return chain;
}

pub fn convertYaml(allocator: std.mem.Allocator, reader: std.io.AnyReader, writer: std.io.AnyWriter, progress: ?std.Progress.Node) !void {
    defer if (progress) |p| p.end();

    var endsBuf: [4]u8 = undefined;

    _ = try reader.readAll(&endsBuf);
    if (!std.mem.eql(u8, &endsBuf, "GRIL")) return error.InvalidHeader;

    if (try reader.readByte() != VERSION) return error.VersionMismatch;

    const depth = try reader.readInt(u32, .little);
    const node_count = try reader.readInt(u32, .little);
    const weights_count = try reader.readInt(u32, .little);

    if (progress) |p| p.setEstimatedTotalItems(node_count);

    try writer.print(
        \\depth: {d}
        \\node_count: {d}
        \\weights_count: {d}
        \\nodes:
        \\
    , .{ depth, node_count, weights_count });

    const seq_buf = try allocator.alloc(u8, depth);
    defer allocator.free(seq_buf);

    for (0..node_count) |_| {
        const node_weights_count: usize = @as(usize, @intCast(try reader.readByte())) + 1;

        _ = try reader.readAll(seq_buf);

        try writer.print("  - seq: |\n      ", .{});
        for (seq_buf) |c| {
            try writer.print("{c}", .{c});
            if (c == '\n') try writer.print("\n      ", .{});
        }

        try writer.print("\n    weights:\n", .{});

        for (0..node_weights_count) |_| {
            const char = try reader.readByte();
            const weight = try reader.readInt(u32, .little);

            try writer.print(
                \\      - char: {d}
                \\        weight: {d}
                \\
            , .{ char, weight });
        }
    }

    _ = try reader.readAll(&endsBuf);
    if (!std.mem.eql(u8, &endsBuf, "LIRG")) return error.InvalidHeader;
}

pub const ModelInfo = struct {
    depth: usize,
    nodes: usize,
    weights: usize,
};

/// does not seek back to zero
pub fn getInfo(reader: std.io.AnyReader) !ModelInfo {
    var endsBuf: [4]u8 = undefined;

    _ = try reader.readAll(&endsBuf);
    if (!std.mem.eql(u8, &endsBuf, "GRIL")) return error.InvalidHeader;

    if (try reader.readByte() != VERSION) return error.VersionMismatch;

    const depth = try reader.readInt(u32, .little);
    const node_count = try reader.readInt(u32, .little);
    const weights_count = try reader.readInt(u32, .little);

    return ModelInfo{
        .depth = depth,
        .nodes = node_count,
        .weights = weights_count,
    };
}
