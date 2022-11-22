const std = @import("std");
const def = @import("def.zig");
const utils = @import("../utils.zig");

const C = @cImport({
    @cInclude("unistd.h");
});

pub fn refreshScreen(cfg: *const def.Config) def.EditorError!void {
    struct { fn errFn(c: *const def.Config) !void {
        var buf = std.ArrayList(u8).init(std.heap.page_allocator);
        defer buf.clearAndFree();

        try buf.appendSlice("\x1b[?25l");
        try buf.appendSlice("\x1b[2J");
        try buf.appendSlice("\x1b[H");

        try draw(c, &buf);

        try utils.bufAppendWithFmt(32, &buf, "\x1b[{};{}H", .{c.cy + 1, c.cx + 1});

        try buf.appendSlice("\x1b[?25h");

        _ = C.write(1, buf.items.ptr, buf.items.len);
    } }.errFn(cfg) catch return def.EditorError.DrawFail;
}

fn draw(cfg: *const def.Config, buf: *std.ArrayList(u8)) !void {
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
                "Welcome to Zilo {s}!", .{ def.ziloVerison }
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
