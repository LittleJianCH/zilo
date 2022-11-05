const std = @import("std");
const raw = @import("rawMode.zig");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
});

pub fn main() void {
    var orig = raw.enableRawMode() catch |err| switch (err) {
        error.NotATerminal => {
            std.debug.print("Failed to enable raw mode: {}\n", .{err});
            return;
        }
    };
    defer raw.disableRawMode(orig);

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
