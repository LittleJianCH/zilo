const std = @import("std");

pub fn bufAppendWithFmt(
    comptime size: usize,
    array: *std.ArrayList(u8),
    comptime fmtStr: []const u8,
    args: anytype) !void
{
    var buf: [size]u8 = undefined;
    var str = try std.fmt.bufPrint(&buf, fmtStr, args);
    try array.appendSlice(str);
}
