const std = @import("std");

/// assumes a.len = b.len
pub fn revCmp(a: []const u8, b: []const u8) std.math.Order {
    var i: usize = a.len;
    while (i >= 8) : (i -= 8) {
        const aa = std.mem.bytesToValue(u64, a[i - 8 .. i]);
        const bb = std.mem.bytesToValue(u64, b[i - 8 .. i]);
        if (aa != bb) return if (aa < bb) .lt else .gt;
    }

    while (i > 0) {
        i -= 1;
        if (a[i] != b[i]) return if (a[i] < b[i]) .lt else .gt;
    }

    return .eq;
}
