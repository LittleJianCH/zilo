const std = @import("std");
const raw = @import("rawMode.zig");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
});

pub fn main() void {
    if (raw.enableRawMode()) |orig| {
        defer raw.disableRawMode(orig);
    } else |err| {
        std.debug.print("Failed to enable raw mode: {}\n", .{err});
        return;
    }

    while (true) {
        var c: u8 = 0;
        _ = C.read(C.STDIN_FILENO, &c, 1);
        if (C.iscntrl(c) != 0) {
            std.debug.print("{}\r\n", .{c});
        } else {
            std.debug.print("{}: {c}\r\n", .{ c, c });
        }

        if (c == 'q') break;
    }
}
