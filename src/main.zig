const std = @import("std");

const editor = @import("editor.zig");
const raw = @import("rawMode.zig");

pub fn main() void {
    const allocator = std.heap.page_allocator;
    const args = std.process.argsAlloc(allocator) catch |err| {
        std.debug.panic("Fail to get args: {}", .{err});
        return;
    };
    defer std.process.argsFree(allocator, args);

    const orig = raw.enableRawMode() catch |err| {
        std.debug.print("Failed to enable raw mode: {}\n", .{err});
        return;
    };
    defer raw.disableRawMode(orig);

    editor.editorProgress(args) catch |err| {
        std.debug.print("Failed when running editor: {}\n", .{err});
    };
}
