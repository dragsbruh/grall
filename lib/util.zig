const std = @import("std");

/// assumes a.len = b.len
pub fn revCmp(a: []const u8, b: []const u8) std.math.Order {
    var i = a.len;
    while (i > 0) {
        i -= 1;
        if (a[i] < b[i]) return .lt else if (a[i] > b[i]) return .gt;
    }

    return .eq;
}
