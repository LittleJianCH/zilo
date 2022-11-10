const std = @import("std");
const utils = @import("utils.zig");

const editor = @import("editor.zig");
const raw = @import("rawMode.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var errMessageBuf = std.ArrayList(u8).init(allocator);
    defer {
        std.debug.print("{s}\n", .{errMessageBuf.items});
        errMessageBuf.clearAndFree();
    }

    const args = std.process.argsAlloc(allocator) catch |err| {
        utils.bufAppendWithFmt(400, &errMessageBuf,
            "Fail to get args: {}\n", .{err}
        ) catch return;
        return;
    };
    defer std.process.argsFree(allocator, args);

    const orig = raw.enableRawMode() catch |err| {
        utils.bufAppendWithFmt(400, &errMessageBuf,
            "Failed to enable raw mode: {}\n", .{err}
        ) catch return;
        return;
    };
    defer raw.disableRawMode(orig);

    editor.editorProgress(args) catch |err| {
        utils.bufAppendWithFmt(400, &errMessageBuf,
            "Failed when running editor: {}\n", .{err}
        ) catch return;
        return;
    };
}
