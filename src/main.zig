const std = @import("std");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const RawModeError = error {
    NotATerminal,
};

fn enableRawMode() RawModeError!C.termios {
    var orig: C.termios = undefined;

    if (C.tcgetattr(C.STDIN_FILENO, &orig) == -1) {
        return error.NotATerminal;
    }

    var raw = orig;
    raw.c_cflag |= C.CS8;
    raw.c_iflag &= ~@as(c_ulong, C.ICRNL | C.IXON);
    raw.c_lflag &= ~@as(c_ulong, C.ECHO | C.ICANON | C.IEXTEN | C.ISIG);
    raw.c_oflag &= ~@as(c_ulong, C.OPOST);
    raw.c_cc[C.VMIN] = 0;
    raw.c_cc[C.VTIME] = 1;

    _ = C.tcsetattr(C.STDIN_FILENO, C.TCSAFLUSH, &raw);

    return orig;
}

fn disableRawMode(orig: C.termios) void {
    _ = C.tcsetattr(C.STDIN_FILENO, C.TCSAFLUSH, &orig);
}

pub fn main() void {
    if (enableRawMode()) |orig| {
        defer disableRawMode(orig);
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
