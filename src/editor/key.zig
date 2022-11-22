const std = @import("std");
const utils = @import("../utils.zig");
const def = @import("def.zig");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
});

fn ctrlKey(key: u8) u8 {
    return key & 0x1f;
}

fn readKey() def.EditorError!def.CommandKey {
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

fn setCursorX(cfg: *def.Config, r: u8) void {
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

fn moveCursorLeft(cfg: *def.Config) void {
    if (cfg.cx != 0) { cfg.cx -= 1; }
    else if (cfg.colOff != 0) { cfg.colOff -= 1; }
    cfg.rx = cfg.cx + cfg.colOff;
}

fn moveCursorRight(cfg: *def.Config) void {
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

fn moveCursorUp(cfg: *def.Config) void {
    if (cfg.cy != 0) { cfg.cy -= 1; }
    else if (cfg.rowOff != 0) { cfg.rowOff -= 1; }

    const newDy = cfg.cy + cfg.rowOff;
    setCursorX(cfg, @intCast(u8, std.mem.min(u64, &[_]u64{
        cfg.rx,
        if (newDy < cfg.text.items.len) cfg.text.items[newDy].items.len else 0,
    })));
}

fn moveCursorDown(cfg: *def.Config) void {
    var dy = cfg.cy + cfg.rowOff;
    const row = std.mem.min(u64, &[_]u64{
        cfg.row, cfg.text.items.len - cfg.rowOff
    });
    if (cfg.cy + 1 < row) { cfg.cy += 1; }
    else if (cfg.cy + 1 == cfg.row and dy + 1 < cfg.text.items.len) {
        cfg.rowOff += 1;
    }

    const newDy = cfg.cy + cfg.rowOff;
    setCursorX(cfg, @intCast(u8, std.mem.min(u64, &[_]u64{
        cfg.rx,
        if (newDy < cfg.text.items.len) cfg.text.items[newDy].items.len else 0,
    })));
}

fn moveCursor(cfg: *def.Config, key: def.CommandKey) void {
    switch (key) {
        .left => moveCursorLeft(cfg),
        .down => moveCursorDown(cfg),
        .up => moveCursorUp(cfg),
        .right => moveCursorRight(cfg),
        .char => |ch| {
            switch (ch) {
                'h' => moveCursorLeft(cfg),
                'j' => moveCursorDown(cfg),
                'k' => moveCursorUp(cfg),
                'l' => moveCursorRight(cfg),
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub fn processKey(cfg: *def.Config) def.EditorError!u8 {
    const c = try readKey();
    switch (c) {
        .char => |ch| {
            switch (ch) {
                ctrlKey('q'), 'q' => return 1,
                'h', 'j', 'k', 'l' => moveCursor(cfg, c),
                else => {},
            }
        },
        .up, .down, .left, .right => moveCursor(cfg, c),
        else => {},
    }
    return 0;
}
