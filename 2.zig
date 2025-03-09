//! Solution to this AOC problem: https://adventofcode.com/2024/day/1

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status != .ok) {
            std.debug.print("Failed to deinitialize the allocator: {}\n", .{deinit_status});
        }
    }
    var file = try std.fs.cwd().openFile("2.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader().any();
    const safe = try totalSafe(in_stream, alloc);
    std.debug.print("Safe: {}\n", .{safe});
}

///Parse input file
fn totalSafe(in_stream: std.io.AnyReader, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    while (try in_stream.readUntilDelimiterOrEofAlloc(alloc, '\n', 1024)) |line| {
        defer alloc.free(line);
        const nums = try parseLine(line, alloc);
        defer nums.deinit();
        if (isSafe(nums.items)) {
            result += 1;
        }
    }
    return result;
}

fn parseLine(line: []const u8, alloc: std.mem.Allocator) !std.ArrayList(i32) {
    var list = std.ArrayList(i32).init(alloc);
    errdefer list.deinit();

    var it = std.mem.splitAny(u8, line, " \n");
    while (it.next()) |word| {
        const stripped = std.mem.trim(u8, word, " \n");
        if (stripped.len == 0) continue;
        const num = try std.fmt.parseInt(i32, stripped, 10);
        try list.append(num);
    }
    return list;
}

fn isDiffSafe(diff: i32) bool {
    return switch (diff) {
        -3...-1 => true,
        1...3 => true,
        else => false,
    };
}

fn sameDirection(diff1: i32, diff2: i32) bool {
    const sign1 = diff1 < 0;
    const sign2 = diff2 < 0;
    return sign1 == sign2;
}

fn isSafe(levels: []const i32) bool {
    if (levels.len < 2) return true;
    const firstDiff = levels[1] - levels[0];
    if (!isDiffSafe(firstDiff)) return false;
    for (1..levels.len - 1) |idx| {
        const diff = levels[idx + 1] - levels[idx];
        if (!isDiffSafe(diff)) return false;
        if (!sameDirection(firstDiff, diff)) return false;
    }
    return true;
}

const t = std.testing;

test "parse valid line" {
    const line = "1 2 3 4 5 6 7 8 9 10\n";
    const list = try parseLine(line, t.allocator);
    defer list.deinit();
    try t.expect(list.items.len == 10);
    for (list.items, 1..) |item, i| {
        try t.expect(item == i);
    }
}

test sameDirection {
    try t.expect(sameDirection(1, 2));
    try t.expect(sameDirection(-1, -2));
    try t.expect(!sameDirection(1, -2));
    try t.expect(!sameDirection(-1, 2));
}

test isDiffSafe {
    try t.expect(isDiffSafe(1));
    try t.expect(isDiffSafe(2));
    try t.expect(isDiffSafe(3));
    try t.expect(isDiffSafe(-1));
    try t.expect(isDiffSafe(-2));
    try t.expect(isDiffSafe(-3));
    try t.expect(!isDiffSafe(0));
    try t.expect(!isDiffSafe(4));
    try t.expect(!isDiffSafe(-4));
}

test isSafe {
    try t.expect(isSafe(&[_]i32{}));
    try t.expect(isSafe(&[_]i32{ 1, 2, 3, 4, 5 }));
    try t.expect(isSafe(&[_]i32{ -1, -2, -3, -4, -5, -6 }));
    try t.expect(isSafe(&[_]i32{ 1, 2, 5, 7 }));
    try t.expect(isSafe(&[_]i32{ 1, -2, -3, -6, -8 }));

    try t.expect(!isSafe(&[_]i32{ 1, -2, -3, -3, -6, -8 })); // non-descending
    try t.expect(!isSafe(&[_]i32{ 1, 2, 3, 3, 6, 8 })); // non-ascending
    try t.expect(!isSafe(&[_]i32{ 1, 2, 3, 2, 6, 8, 9 })); // non-ascending
    try t.expect(!isSafe(&[_]i32{ 1, 2, 3, 7, 8 })); // diff too big
}

test "totalSafe" {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;
    var stream = std.io.fixedBufferStream(input);
    const reader = stream.reader();
    const anyReader = reader.any();
    const result = try totalSafe(anyReader, t.allocator);
    try t.expect(result == 2);
}
