//! Solution tot the challenge: https://adventofcode.com/2024/day/9

const std = @import("std");
const common = @import("common.zig");
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var input = try common.parseFile(Input, "9.txt", alloc, parseInput);
    defer input.deinit(alloc);
    pack(input.items);
    const result1 = checksum(input.items);
    std.debug.print("Checksum (part 1): {d}\n", .{result1});
    var input2 = try common.parseFile(Input2, "9.txt", alloc, parseInput2);
    defer input2.deinit();
    packBlocks(&input2);
    var long_result = try longVersion(input2.files.items, alloc);
    defer long_result.deinit(alloc);
    const result2 = checksum(long_result.items);
    std.debug.print("Checksum (part 2): {d}\n", .{result2});
}
const File = u32;
const IndexedFile = struct { pos: usize, file: File, len: u8 };

const IndexedSpace = struct { pos: usize, len: u8 };

/// Input format for part 1
const Input = std.ArrayList(?File);

/// Input format for part 2
const Input2 = struct {
    files: std.ArrayList(IndexedFile),
    spaces: std.ArrayList(IndexedSpace),
    alloc: std.mem.Allocator,

    fn init(alloc: std.mem.Allocator) Input2 {
        return Input2{ .files = std.ArrayList(IndexedFile).empty, .spaces = std.ArrayList(IndexedSpace).empty, .alloc = alloc };
    }

    fn deinit(self: *Input2) void {
        self.files.deinit(self.alloc);
        self.spaces.deinit(self.alloc);
    }
};

/// Parses input in away that is specific to part 1
fn parseInput(reader: *std.io.Reader, alloc: std.mem.Allocator) !Input {
    var result = Input.empty;
    errdefer result.deinit(alloc);
    var file_idx: File = 0;
    var is_file = true;
    while (reader.takeByte()) |ch| {
        if (ch == '\n') break;
        if (ch < '0' or ch > '9') {
            std.debug.print("bad char: {d}\n", .{ch});
            return common.InputError.InvalidCharacter;
        }
        const digit = ch - '0';
        const val: ?File = if (is_file) file_idx else null;
        for (0..digit) |_| {
            try result.append(alloc, val);
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
    defer input.deinit(t.allocator);
    const expected = [_]?File{ 0, 0, null, null, null, 1, 1, 1, null, null, null, 2, null, null, null, 3, 3, 3, null, 4, 4, null, 5, 5, 5, 5, null, 6, 6, 6, 6, null, 7, 7, 7, null, 8, 8, 8, 8, 9, 9 };
    try t.expectEqualSlices(?File, &expected, input.items);
}

/// Looks for the next empty slot in the buffer.
/// Returns null if there are no empty slots.
fn nextEmpty(buf: []?File, start_idx: usize) ?usize {
    for (start_idx..buf.len) |idx| {
        if (buf[idx] == null) return idx;
    }
    return null;
}

/// Looks for the next filled slot in the buffer (from right to left)
/// Returns null if there are no filled slots.
fn nextFilled(buf: []?File, start_idx: usize) ?usize {
    var idx = start_idx;
    while (true) {
        if (buf[idx] != null) return idx;
        if (idx == 0) return null;
        idx -= 1;
    }
}

/// Packs the buffer by moving all filled slots to the left.
/// Empty slots are left at the end of the buffer.
/// This matches the definition of part 1.
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
    defer input.deinit(t.allocator);
    pack(input.items);

    try t.expectEqualSlices(?File, &example_packed, input.items);
}

/// Calculates checksum for the buffer.
/// The checksum is the sum of all filled slots multiplied by their index.
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

/// Parses input in a way that is specific to part 2
fn parseInput2(reader: *std.io.Reader, alloc: std.mem.Allocator) !Input2 {
    var result = Input2.init(alloc);
    errdefer result.deinit();
    var file_idx: File = 0;
    var is_file = true;
    var pos: usize = 0;
    while (reader.takeByte()) |ch| {
        if (ch == '\n') break;
        if (ch < '0' or ch > '9') {
            std.debug.print("bad char: {d}\n", .{ch});
            return common.InputError.InvalidCharacter;
        }
        const digit = ch - '0';
        if (is_file) {
            try result.files.append(alloc, IndexedFile{ .pos = pos, .file = file_idx, .len = digit });
        } else if (digit > 0) {
            try result.spaces.append(alloc, IndexedSpace{ .pos = pos, .len = digit });
        }
        pos += digit;
        if (is_file) file_idx += 1;
        is_file = !is_file;
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
    return result;
}

test parseInput2 {
    var input = try common.parseExample(Input2, example_input, parseInput2);
    defer input.deinit();
    const expected_files = [_]IndexedFile{ .{ .pos = 0, .file = 0, .len = 2 }, .{ .pos = 5, .file = 1, .len = 3 }, .{ .pos = 11, .file = 2, .len = 1 }, .{ .pos = 15, .file = 3, .len = 3 }, .{ .pos = 19, .file = 4, .len = 2 }, .{ .pos = 22, .file = 5, .len = 4 }, .{ .pos = 27, .file = 6, .len = 4 }, .{ .pos = 32, .file = 7, .len = 3 }, .{ .pos = 36, .file = 8, .len = 4 }, .{ .pos = 40, .file = 9, .len = 2 } };
    try t.expectEqualSlices(IndexedFile, &expected_files, input.files.items);
    const expected_spaces = [_]IndexedSpace{ .{ .pos = 2, .len = 3 }, .{ .pos = 8, .len = 3 }, .{ .pos = 12, .len = 3 }, .{ .pos = 18, .len = 1 }, .{ .pos = 21, .len = 1 }, .{ .pos = 26, .len = 1 }, .{ .pos = 31, .len = 1 }, .{ .pos = 35, .len = 1 } };
    try t.expectEqualSlices(IndexedSpace, &expected_spaces, input.spaces.items);
}

fn sortIndexedFile(_: void, a: IndexedFile, b: IndexedFile) bool {
    return a.pos < b.pos;
}

/// Packs the files and spaces in the buffer using the rules of part 2.
fn packBlocks(input: *Input2) void {
    var idx = input.files.items.len - 1;
    while (true) {
        const file = &input.files.items[idx];
        for (input.spaces.items) |*space| {
            if (space.pos >= file.pos) break;
            if (space.len >= file.len) {
                file.pos = space.pos;
                space.len -= file.len;
                space.pos += file.len;

                break;
            }
        }
        if (idx == 0) break else idx -= 1;
    }
    std.mem.sort(IndexedFile, input.files.items, {}, sortIndexedFile);
}

test packBlocks {
    var input = try common.parseExample(Input2, example_input, parseInput2);
    defer input.deinit();
    packBlocks(&input);
    const expected_files = [_]IndexedFile{
        .{ .pos = 0, .file = 0, .len = 2 },
        .{ .pos = 2, .file = 9, .len = 2 },
        .{ .pos = 4, .file = 2, .len = 1 },
        .{ .pos = 5, .file = 1, .len = 3 },
        .{ .pos = 8, .file = 7, .len = 3 },
        .{ .pos = 12, .file = 4, .len = 2 },
        .{ .pos = 15, .file = 3, .len = 3 },
        .{ .pos = 22, .file = 5, .len = 4 },
        .{ .pos = 27, .file = 6, .len = 4 },
        .{ .pos = 36, .file = 8, .len = 4 },
    };
    try t.expectEqualSlices(IndexedFile, &expected_files, input.files.items);
}

/// Repacks data into a buffer with individual slots for each file.
/// This is needed for checksum calculation.
fn longVersion(val: []const IndexedFile, alloc: std.mem.Allocator) !std.ArrayList(?File) {
    if (val.len == 0) return std.ArrayList(?File).empty;
    const result_len = val[val.len - 1].pos + val[val.len - 1].len;
    var result = try std.ArrayList(?File).initCapacity(alloc, result_len);
    errdefer result.deinit(alloc);
    for (0..result_len) |_| {
        try result.append(alloc, null);
    }

    for (val) |file| {
        for (file.pos..(file.pos + file.len)) |idx| {
            result.items[idx] = file.file;
        }
    }
    return result;
}

test longVersion {
    var input = try common.parseExample(Input2, example_input, parseInput2);
    defer input.deinit();
    packBlocks(&input);
    var long_result = try longVersion(input.files.items, input.alloc);
    defer long_result.deinit(t.allocator);
    const expected = [_]?File{ 0, 0, 9, 9, 2, 1, 1, 1, 7, 7, 7, null, 4, 4, null, 3, 3, 3, null, null, null, null, 5, 5, 5, 5, null, 6, 6, 6, 6, null, null, null, null, null, 8, 8, 8, 8 };
    try t.expectEqualSlices(?File, &expected, long_result.items);
}
