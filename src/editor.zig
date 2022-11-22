const std = @import("std");
const utils = @import("utils.zig");
const def = @import("editor/def.zig");
const draw = @import("editor/draw.zig");
const key = @import("editor/key.zig");

const C = @cImport({
    @cInclude("ctype.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("getWinsize.c");
});

fn getWindow() struct { row: u16, col: u16 } {
    var ws: C.winsize = undefined;

    if (C.getWinsize(&ws) == -1 or ws.ws_col == 0) {
        return .{ .row = 24, .col = 80 };
    } else {
        return .{ .row = ws.ws_row, .col = ws.ws_col };
    }
}

fn editorInit() def.Config {
    const win = getWindow();

    return def.Config {
        .cx = 0,
        .cy = 0,
        .rx = 0,
        .rowOff = 0,
        .colOff = 0,
        .row = @intCast(u8, win.row),
        .col = @intCast(u8, win.col),
        .text = def.ArrayList2D(u8).init(std.heap.page_allocator),
        .mode = def.EditorMode.Normal,
    };
}

fn editorClearText(cfg: *def.Config) void {
    for (cfg.text.items) |*row| {
        row.clearAndFree();
    }
    cfg.text.clearAndFree();
}

fn editorOpenFile(cfg: *def.Config, filename: []const u8) !void {
    struct { fn errFn(c: *def.Config, f: []const u8) !void {
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
    } }.errFn(cfg, filename) catch return def.EditorError.OpenFileFail;
}

fn editorExit(cfg: *def.Config) void {
    editorClearText(cfg);
    _ = C.write(C.STDIN_FILENO, "\x1b[?25l", 6);
    _ = C.write(C.STDIN_FILENO, "\x1b[H", 3);
}

pub fn editorProgress(args: [][:0]u8) def.EditorError!void {
    var config = editorInit();
    defer editorExit(&config);

    if (args.len > 1) {
        try editorOpenFile(&config, args[1]);
    }

    while (true) {
        try draw.refreshScreen(&config);

        if (try key.processKey(&config) == 1) {
            break;
        }
    }
}
