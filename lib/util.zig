const std = @import("std");

/// assumes a.len = b.len
pub fn revCmp(a: []const u8, b: []const u8) std.math.Order {
    var i = a.len;
    while (i > 0) {
        i -= 1;
        if (a[i] < b[i]) return .lt else if (a[i] > b[i]) return .gt;
    }

    // const size = (a.len + 7) / 8;
    // var i = size;
    // while (i > 0) {
    //     i -= 1;

    //     const end = @min((i + 1) * 8, a.len);

    //     const aa = std.mem.readVarInt(u64, a[i * 8 .. end], .big);
    //     const bb = std.mem.readVarInt(u64, b[i * 8 .. end], .big);
    //     if (aa > bb) return .gt;
    //     if (bb > aa) return .lt;
    // }

    return .eq;
}
