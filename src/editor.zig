const std = @import("std");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("getWinsize.c");
});

const ziloVerison = "0.0.1";

const Window = struct {
    row: u16,
    col: u16,
};

pub const EditorError = error {
    ReadKeyFail, DrawFail,
};

fn ctrlKey(key: u8) u8 {
    return key & 0x1f;
}

fn getWindow() Window {
    var ws: C.winsize = undefined;

    if (C.getWinsize(&ws) == -1 or ws.ws_col == 0) {
        return .{ .row = 24, .col = 80 };
    } else {
        return .{ .row = ws.ws_row, .col = ws.ws_col };
    }
}

fn editorRefreshScreen(win: Window) EditorError!void {
    struct { fn errFn(w: Window) !void {
        var buf = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buf.clearAndFree();

        try buf.appendSlice("\x1b[2J");
        try buf.appendSlice("\x1b[H");

        try editorDrawRows(w, &buf);

        try buf.appendSlice("\x1b[H");

        _ = C.write(1, buf.items.ptr, buf.items.len);
    } }.errFn(win) catch return EditorError.DrawFail;
}

fn editorDrawRows(win: Window, buf: *std.ArrayList(u8)) !void {
    var i: usize = 0;
    while (i < win.row) : (i += 1) {
        if (i == win.row / 3) {
            var welcomeBuf: [80]u8 = undefined;
            var welcome = try std.fmt.bufPrint(welcomeBuf[0..], "Welcome to Zilo {s}!", .{ ziloVerison });

            if (welcome.len > win.col) {
                welcome = welcome[0..win.col];
            }

            var padding = (win.col - welcome.len) / 2;

            if (padding != 0) {
                try buf.appendSlice("~");
                padding -= 1;
            }

            while (padding > 0) : (padding -= 1) {
                try buf.appendSlice(" ");
            }

            try buf.appendSlice(welcome);
        } else {
            try buf.appendSlice("~");
        }

        if (i + 1 < win.row) {
            try buf.appendSlice("\r\n");
        }
    }
}

fn editorReadKey() EditorError!u8 {
    var nread: isize = 0;
    var c: u8 = 0;
    while (nread != 1) {
        nread = C.read(C.STDIN_FILENO, &c, 1);
        if (nread == -1 and C.__error().* == C.EAGAIN) {
            return error.ReadKeyFail;
        }
    }
    return c;
}

pub fn editorProgress() EditorError!void {
    const win = getWindow();

    while (true) {
        try editorRefreshScreen(win);

        const c = try editorReadKey();
        if (c == ctrlKey('q')) break;
    }
}
