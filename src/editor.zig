const std = @import("std");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("getWinsize.c");
});

const ziloVerison = "0.0.1";

fn ArrayList2D(comptime T: type) type {
    return std.ArrayList(std.ArrayList(T));
}

const CommandKeyTag = enum {
    up, down, left, right,
    backspace,
    char,
    none,
};

const CommandKey = union(CommandKeyTag) {
    up: void,
    down: void,
    left: void,
    right: void,
    backspace: void,
    char: u8,
    none: void,
};

const Config = struct {
    cx: u8,
    cy: u8,
    rx: u8,
    rowOff: u8,
    colOff: u8,
    row: u8,
    col: u8,
    text: ArrayList2D(u8),
};

pub const EditorError = error {
    ReadKeyFail, DrawFail, OpenFileFail,
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

        try editorDraw(c, &buf);

        var cmdBuf: [32]u8 = undefined;
        var cmd = try std.fmt.bufPrint(&cmdBuf, "\x1b[{};{}H", .{c.cy + 1, c.cx + 1});
        try buf.appendSlice(cmd);

        try buf.appendSlice("\x1b[?25h");

        _ = C.write(1, buf.items.ptr, buf.items.len);
    } }.errFn(cfg) catch return EditorError.DrawFail;
}

fn editorDraw(cfg: *const Config, buf: *std.ArrayList(u8)) !void {
    var i: usize = 0;
    for (cfg.text.items[cfg.rowOff..]) |row| {
        i += 1;
        if (i == cfg.row) break;

        if (row.items.len > cfg.col + cfg.colOff) {
            try buf.appendSlice(row.items[cfg.colOff..(cfg.colOff + cfg.col)]);
        } else if (row.items.len > cfg.colOff) {
            try buf.appendSlice(row.items[cfg.colOff..]);
        }
        try buf.appendSlice("\r\n");
    }

    var welcomeFlag = (cfg.text.items.len == 0);
    while (i < cfg.row) : (i += 1) {
        if (i == cfg.row / 3 and welcomeFlag) {
            var welcomeBuf: [80]u8 = undefined;
            var welcome = try std.fmt.bufPrint(&welcomeBuf,
                "Welcome to Zilo {s}!", .{ ziloVerison }
            );
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

fn editorReadKey() EditorError!CommandKey {
    var nread: isize = 0;
    var c: u8 = 0;
    while (nread != 1) {
        nread = C.read(C.STDIN_FILENO, &c, 1);
        if (nread == -1 and C.__error().* == C.EAGAIN) {
            return error.ReadKeyFail;
        }
    }

    if (c == '\x1b') {
        var seq: [3]u8 = undefined;
        if (C.read(C.STDIN_FILENO, &seq[0], 1) != 1) return .none;
        if (C.read(C.STDIN_FILENO, &seq[1], 1) != 1) return .none;

        if (seq[0] == '[') {
            switch (seq[1]) {
                'A' => return .up,
                'B' => return .down,
                'C' => return .right,
                'D' => return .left,
                else => return .none,
            }
        }

        return .none;
    } else {
        return .{ .char = c };
    }
}

fn editorSetCursorX(cfg: *Config, r: u8) void {
    if (r >= cfg.colOff + cfg.col) {
        cfg.cx = cfg.col - 1;
        cfg.colOff = r - cfg.cx;
    } else if (r < cfg.colOff) {
        cfg.cx = 0;
        cfg.colOff = r - cfg.cx;
    } else {
        cfg.cx = r - cfg.colOff;
    }
}

fn editorMoveCursorLeft(cfg: *Config) void {
    if (cfg.cx != 0) { cfg.cx -= 1; }
    else if (cfg.colOff != 0) { cfg.colOff -= 1; }
    cfg.rx = cfg.cx + cfg.colOff;
}

fn editorMoveCursorRight(cfg: *Config) void {
    const dx = cfg.cx + cfg.colOff;
    const dy = cfg.cy + cfg.rowOff;
    const lineLen =
        if (dy < cfg.text.items.len) cfg.text.items[dy].items.len else 0;

    if (cfg.cx + 1 < std.mem.min(u64, &[_]u64{ cfg.col, lineLen })) {
        cfg.cx += 1;
    } else if (cfg.cx + 1 == cfg.col and
               dx + 1 < lineLen) {
        cfg.colOff += 1;
    }
    cfg.rx = cfg.cx + cfg.colOff;
}

fn editorMoveCursorUp(cfg: *Config) void {
    if (cfg.cy != 0) { cfg.cy -= 1; }
    else if (cfg.rowOff != 0) { cfg.rowOff -= 1; }

    const newDy = cfg.cy + cfg.rowOff;
    editorSetCursorX(cfg, @intCast(u8, std.mem.min(u64, &[_]u64{
        cfg.rx,
        if (newDy < cfg.text.items.len) cfg.text.items[newDy].items.len else 0,
    })));
}

fn editorMoveCursorDown(cfg: *Config) void {
    var dy = cfg.cy + cfg.rowOff;
    const row = std.mem.min(u64, &[_]u64{
        cfg.row, cfg.text.items.len - cfg.rowOff
    });
    if (cfg.cy + 1 < row) { cfg.cy += 1; }
    else if (cfg.cy + 1 == cfg.row and dy + 1 < cfg.text.items.len) {
        cfg.rowOff += 1;
    }

    const newDy = cfg.cy + cfg.rowOff;
    editorSetCursorX(cfg, @intCast(u8, std.mem.min(u64, &[_]u64{
        cfg.rx,
        if (newDy < cfg.text.items.len) cfg.text.items[newDy].items.len else 0,
    })));
}

fn editorMoveCursor(cfg: *Config, key: CommandKey) void {
    switch (key) {
        .left => editorMoveCursorLeft(cfg),
        .down => editorMoveCursorDown(cfg),
        .up => editorMoveCursorUp(cfg),
        .right => editorMoveCursorRight(cfg),
        .char => |ch| {
            switch (ch) {
                'h' => editorMoveCursorLeft(cfg),
                'j' => editorMoveCursorDown(cfg),
                'k' => editorMoveCursorUp(cfg),
                'l' => editorMoveCursorRight(cfg),
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

fn editorInit() Config {
    const win = getWindow();

    return Config {
        .cx = 0,
        .cy = 0,
        .rx = 0,
        .rowOff = 0,
        .colOff = 0,
        .row = @intCast(u8, win.row),
        .col = @intCast(u8, win.col),
        .text = ArrayList2D(u8).init(std.heap.page_allocator),
    };
}

fn editorClearText(cfg: *Config) void {
    for (cfg.text.items) |*row| {
        row.clearAndFree();
    }
    cfg.text.clearAndFree();
}

fn editorOpenFile(cfg: *Config, filename: []const u8) !void {
    struct { fn errFn(c: *Config, f: []const u8) !void {
        // Maybe we should ask the user if they want to save the file first
        editorClearText(c);

        var file = try std.fs.cwd().openFile(f, .{});
        defer file.close();

        const bufferSize = 40960;
        const allocator = std.heap.page_allocator;
        const fileBuf = try file.readToEndAlloc(allocator, bufferSize);
        defer allocator.free(fileBuf);

        var iter = std.mem.split(u8, fileBuf, "\n");
        while (iter.next()) |line| {
            var row = std.ArrayList(u8).init(allocator);

            try row.appendSlice(line);
            try c.text.append(row);
        }
    } }.errFn(cfg, filename) catch return EditorError.OpenFileFail;
}

fn editorExit(cfg: *Config) void {
    editorClearText(cfg);
    _ = C.write(C.STDIN_FILENO, "\x1b[?25l", 6);
    _ = C.write(C.STDIN_FILENO, "\x1b[H", 3);
}

pub fn editorProgress(args: [][:0]u8) EditorError!void {
    var config = editorInit();
    defer editorExit(&config);

    if (args.len > 1) {
        try editorOpenFile(&config, args[1]);
    }

    while (true) {
        try editorRefreshScreen(&config);

        const c = try editorReadKey();
        switch (c) {
            .char => |ch| {
                switch (ch) {
                    ctrlKey('q'), 'q' => return,
                    'h', 'j', 'k', 'l' => editorMoveCursor(&config, c),
                    else => {},
                }
            },
            .up, .down, .left, .right => editorMoveCursor(&config, c),
            else => {},
        }
    }
}
