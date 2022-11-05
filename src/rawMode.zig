const C = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

pub const RawModeError = error {
    NotATerminal,
};

pub fn enableRawMode() RawModeError!C.termios {
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

pub fn disableRawMode(orig: C.termios) void {
    _ = C.tcsetattr(C.STDIN_FILENO, C.TCSAFLUSH, &orig);
}
