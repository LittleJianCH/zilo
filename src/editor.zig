const std = @import("std");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("getWinsize.c");
});

const ziloVerison = "0.0.1";

const Config = struct {
    cx: u8,
    cy: u8,
    row: u16,
    col: u16,
};

pub const EditorError = error {
    ReadKeyFail, DrawFail,
};

fn ctrlKey(key: u8) u8 {
    return key & 0x1f;
}

fn getWindow() struct { row: u16, col: u16 } {
    var ws: C.winsize = undefined;

    if (C.getWinsize(&ws) == -1 or ws.ws_col == 0) {
        return .{ .row = 24, .col = 80 };
    } else {
        return .{ .row = ws.ws_row, .col = ws.ws_col };
    }
}

fn editorRefreshScreen(cfg: *const Config) EditorError!void {
    struct { fn errFn(c: *const Config) !void {
        var buf = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buf.clearAndFree();

        try buf.appendSlice("\x1b[?25l");
        try buf.appendSlice("\x1b[2J");
        try buf.appendSlice("\x1b[H");

        try editorDrawRows(c, &buf);

        var cmdBuf: [32]u8 = undefined;
        var cmd = try std.fmt.bufPrint(&cmdBuf, "\x1b[{};{}H", .{c.cy + 1, c.cx + 1});
        try buf.appendSlice(cmd);

        try buf.appendSlice("\x1b[?25h");

        _ = C.write(1, buf.items.ptr, buf.items.len);
    } }.errFn(cfg) catch return EditorError.DrawFail;
}

fn editorDrawRows(cfg: *const Config, buf: *std.ArrayList(u8)) !void {
    var i: usize = 0;
    while (i < cfg.row) : (i += 1) {
        if (i == cfg.row / 3) {
            var welcomeBuf: [80]u8 = undefined;
            var welcome = try std.fmt.bufPrint(&welcomeBuf, "Welcome to Zilo {s}!", .{ ziloVerison });
            if (welcome.len > cfg.col) {
                welcome = welcome[0..cfg.col];
            }

            var padding = (cfg.col - welcome.len) / 2;
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

        if (i + 1 < cfg.row) {
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

fn editorMoveCursor(cfg: * Config, key: u8) void {
    switch (key) {
        'h' => if (cfg.cx != 0) { cfg.cx -= 1; },
        'j' => if (cfg.cy != cfg.row - 1) { cfg.cy += 1; },
        'k' => if (cfg.cy != 0) { cfg.cy -= 1; },
        'l' => if (cfg.cx != cfg.col - 1) { cfg.cx += 1; },
        else => unreachable,
    }
}

fn initEditor() Config {
    const win = getWindow();

    return Config {
        .cx = 0,
        .cy = 0,
        .row = win.row,
        .col = win.col,
    };
}

fn editorExit() void {
    _ = C.write(C.STDIN_FILENO, "\x1b[?25l", 6);
    _ = C.write(C.STDIN_FILENO, "\x1b[H", 3);
}

pub fn editorProgress() EditorError!void {
    var config = initEditor();

    while (true) {
        try editorRefreshScreen(&config);

        const c = try editorReadKey();
        switch (c) {
            ctrlKey('q') => {
                editorExit();
                return;
            },
            'h', 'j', 'k', 'l' => editorMoveCursor(&config, c),
            else => {},
        }
    }
}
