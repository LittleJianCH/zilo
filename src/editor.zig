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

const Config = struct {
    cx: u8,
    cy: u8,
    cur: u8, // the first line on the screen
    row: u16,
    col: u16,
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
    for (cfg.text.items[cfg.cur..]) |row| {
        i += 1;
        if (i == cfg.row) break;

        try buf.appendSlice(row.items);
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
        'j' => {
            const ry = cfg.cy + cfg.cur;
            const row = std.mem.min(u64, &[_]u64{
                cfg.row, cfg.text.items.len - cfg.cur
            });
            if (cfg.cy != row - 1) { cfg.cy += 1; }
            else if (cfg.cy == cfg.row - 1 and ry != cfg.text.items.len - 1) {
                cfg.cur += 1;
            }
        },
        'k' => {
            if (cfg.cy != 0) { cfg.cy -= 1; }
            else if (cfg.cur != 0) { cfg.cur -= 1; }
        },
        'l' => if (cfg.cx != cfg.col - 1) { cfg.cx += 1; },
        else => unreachable,
    }
}

fn editorInit() Config {
    const win = getWindow();

    return Config {
        .cx = 0,
        .cy = 0,
        .cur = 0,
        .row = win.row,
        .col = win.col,
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

pub fn editorProgress() EditorError!void {
    var config = editorInit();
    defer editorExit(&config);

    try editorOpenFile(&config, "src/editor.zig");

    while (true) {
        try editorRefreshScreen(&config);

        const c = try editorReadKey();
        switch (c) {
            ctrlKey('q') => return,
            'h', 'j', 'k', 'l' => editorMoveCursor(&config, c),
            else => {},
        }
    }
}
