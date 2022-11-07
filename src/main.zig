const std = @import("std");

const editor = @import("editor.zig");
const raw = @import("rawMode.zig");

pub fn main() void {
    const orig = raw.enableRawMode() catch |err| {
        std.debug.print("Failed to enable raw mode: {}\n", .{err});
        return;
    };
    defer raw.disableRawMode(orig);

    editor.editorProgress() catch |err| {
        std.debug.print("Failed when running editor: {}\n", .{err});
    };
}
