const std = @import("std");

pub const ziloVerison = "0.0.1";

pub fn ArrayList2D(comptime T: type) type {
    return std.ArrayList(std.ArrayList(T));
}

const CommandKeyTag = enum {
    up, down, left, right,
    backspace,
    char,
    none,
};

pub const CommandKey = union(CommandKeyTag) {
    up: void,
    down: void,
    left: void,
    right: void,
    backspace: void,
    char: u8,
    none: void,
};

pub const EditorMode = enum {
    Normal,
    Insert,
};

pub const Config = struct {
    cx: u8,
    cy: u8,
    rx: u8,
    rowOff: u8,
    colOff: u8,
    row: u8,
    col: u8,
    text: ArrayList2D(u8),
    mode: EditorMode,
};

pub const EditorError = error {
    ReadKeyFail, DrawFail, OpenFileFail,
};
