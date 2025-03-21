//! Solution tot the challenge: https://adventofcode.com/2024/day/9

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    const input = try common.parseFile(Input, "9.txt", alloc, parseInput);
    defer input.deinit();
    pack(input.items);
    const result = checksum(input.items);
    std.debug.print("Checksum: {d}\n", .{result});
}
const File = u32;
const Input = std.ArrayList(?File);
const InputError = error{BadCharacter};

fn parseInput(reader: std.io.AnyReader, alloc: std.mem.Allocator) !Input {
    var result = Input.init(alloc);
    errdefer result.deinit();
    var file_idx: File = 0;
    var is_file = true;
    while (reader.readByte()) |ch| {
        if (ch == '\n') break;
        if (ch < '0' or ch > '9') {
            std.debug.print("bad char: {d}\n", .{ch});
            return InputError.BadCharacter;
        }
        const digit = ch - '0';
        const val: ?File = if (is_file) file_idx else null;
        for (0..digit) |_| {
            try result.append(val);
        }
        if (is_file) file_idx += 1;
        is_file = !is_file;
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
    return result;
}

const example_input = "2333133121414131402";

test "parse example input" {
    var input = try common.parseExample(Input, example_input, parseInput);
    defer input.deinit();
    const expected = [_]?File{ 0, 0, null, null, null, 1, 1, 1, null, null, null, 2, null, null, null, 3, 3, 3, null, 4, 4, null, 5, 5, 5, 5, null, 6, 6, 6, 6, null, 7, 7, 7, null, 8, 8, 8, 8, 9, 9 };
    try t.expectEqualSlices(?File, &expected, input.items);
}

fn nextEmpty(buf: []?File, start_idx: usize) ?usize {
    for (start_idx..buf.len) |idx| {
        if (buf[idx] == null) return idx;
    }
    return null;
}

fn nextFilled(buf: []?File, start_idx: usize) ?usize {
    var idx = start_idx;
    while (true) {
        if (buf[idx] != null) return idx;
        if (idx == 0) return null;
        idx -= 1;
    }
}

fn pack(buf: []?File) void {
    if (buf.len <= 1) return;
    var empty_idx: usize = 0;
    var filled_idx = buf.len - 1;
    while (empty_idx < filled_idx) {
        empty_idx = nextEmpty(buf, empty_idx) orelse return;
        filled_idx = nextFilled(buf, filled_idx) orelse return;
        if (empty_idx > filled_idx) break;
        buf[empty_idx] = buf[filled_idx];
        buf[filled_idx] = null;
        empty_idx += 1;
        filled_idx -= 1;
    }
}

const example_packed = [_]?File{ 0, 0, 9, 9, 8, 1, 1, 1, 8, 8, 8, 2, 7, 7, 7, 3, 3, 3, 6, 4, 4, 6, 5, 5, 5, 5, 6, 6, null, null, null, null, null, null, null, null, null, null, null, null, null, null };

test pack {
    var input = try common.parseExample(Input, example_input, parseInput);
    defer input.deinit();
    pack(input.items);

    try t.expectEqualSlices(?File, &example_packed, input.items);
}

fn checksum(buf: []const ?File) usize {
    var result: usize = 0;
    for (buf, 0..) |el, idx| {
        const el_val = el orelse continue;
        result += el_val * idx;
    }
    return result;
}

test checksum {
    try t.expectEqual(1928, checksum(&example_packed));
}
