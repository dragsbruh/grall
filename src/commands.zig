const std = @import("std");

const lib = @import("grall_lib");

pub fn train(allocator: std.mem.Allocator, model_path: []const u8, depth: u32, text_files: []const []const u8) !void {
    const stderr = std.io.getStdErr().writer();

    var chain = try lib.TrainerChain.init(depth);
    defer chain.deinit(allocator);

    for (text_files) |file_path| std.fs.cwd().access(file_path, .{}) catch |err| {
        try stderr.print("error: could not access text file: {}\n", .{err});
        return error.Exit;
    };

    const progress = std.Progress.start(.{ .root_name = "training", .estimated_total_items = text_files.len + 1 });
    defer progress.end();

    var seq = try lib.SeqManager.init(allocator, chain.depth);
    defer seq.deinit(allocator);

    for (text_files) |file_path| {
        const progress_name = try std.fmt.allocPrint(allocator, "training on {s}", .{std.fs.path.basename(file_path)});
        defer allocator.free(progress_name);

        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        defer progress.completeOne();
        const p = progress.start(progress_name, (try file.stat()).size);
        defer p.end();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        while (reader.readByte() catch null) |byte| {
            defer p.completeOne();

            const node = try chain.getNode(allocator, seq.seq);
            try node.feed(allocator, byte);
            seq.push(byte);
        }
    }

    var file = try std.fs.cwd().createFile(model_path, .{});
    defer file.close();

    var buffered_writer = std.io.bufferedWriter(file.writer());

    try lib.serializer.serializeTrainer(
        chain,
        buffered_writer.writer().any(),
        progress.start("serializing", 0),
    );
    try buffered_writer.flush();
}

fn load_model(allocator: std.mem.Allocator, path: []const u8, progress: ?std.Progress.Node) !lib.RuntimeChain {
    const stderr = std.io.getStdErr().writer();

    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        try stderr.print("error: could not open file: {}\n", .{err});
        return error.Exit;
    };
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());

    return try lib.serializer.deserializeRunner(allocator, buffered_reader.reader().any(), progress);
}

pub fn run(allocator: std.mem.Allocator, model_path: []const u8, infinite: bool, limit: ?usize) !void {
    const stdout = std.io.getStdOut().writer();

    var chain = try load_model(allocator, model_path, null);
    defer chain.deinit(allocator);

    var seq = try lib.SeqManager.init(allocator, chain.depth);
    defer seq.deinit(allocator);

    var buffered_writer = std.io.bufferedWriter(stdout);
    const writer = buffered_writer.writer();

    var prng = std.Random.RomuTrio.init(std.crypto.random.int(u64));
    var random = prng.random();

    while (true) {
        const byte = chain.sampleNode(seq.seq, .nearest, &random) orelse if (infinite) {
            seq.reset();
            continue;
        } else break;

        seq.push(byte);
        try writer.writeByte(byte);

        if (limit) |l| {
            std.Thread.sleep(l * std.time.ns_per_ms);
            try buffered_writer.flush();
        }
    }

    try buffered_writer.flush();
}

pub fn yaml(allocator: std.mem.Allocator, model_path: []const u8, yaml_path: []const u8) !void {
    var model_file = try std.fs.cwd().openFile(model_path, .{});
    defer model_file.close();

    var yaml_file = try std.fs.cwd().createFile(yaml_path, .{});
    defer yaml_file.close();

    var buffered_writer = std.io.bufferedWriter(yaml_file.writer());
    var buffered_reader = std.io.bufferedReader(model_file.reader());

    const progress = std.Progress.start(.{ .root_name = "loading model", .estimated_total_items = 1 });
    defer progress.end();

    try lib.serializer.convertYaml(
        allocator,
        buffered_reader.reader().any(),
        buffered_writer.writer().any(),
        progress.start("converting", 0),
    );

    try buffered_writer.flush();
}

pub fn inspect(model_path: []const u8) !void {
    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var file = std.fs.cwd().openFile(model_path, .{}) catch |err| {
        try stderr.print("error: could not open model file - {}\n", .{err});
        return error.Exit;
    };
    defer file.close();

    const info = try lib.serializer.getInfo(file.reader().any());

    try stdout.print(
        \\depth: {d}
        \\nodes: {d}
        \\weights: {d}
        \\
    , .{ info.depth, info.nodes, info.weights });
}
