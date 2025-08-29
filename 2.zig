//! Solution to this AOC problem: https://adventofcode.com/2024/day/1

const std = @import("std");
const common = @import("common.zig");
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    const safe1, const safe2 = try common.parseFile(std.meta.Tuple(&.{ usize, usize }), "2.txt", alloc, totalSafe);
    std.debug.print("Safe: {}\nSafe after removing: {}\n", .{ safe1, safe2 });
}

///Parse input file
fn totalSafe(in_stream: *std.io.Reader, alloc: std.mem.Allocator) !std.meta.Tuple(&.{ usize, usize }) {
    var safe1: usize = 0;
    var safe2: usize = 0;
    var line_it = common.lineIterator(in_stream, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        var nums = try parseLine(line, alloc);
        defer nums.deinit(alloc);
        if (isSafe(nums.items)) {
            safe1 += 1;
        }
        if (try isSafeAfterRemoving(nums.items, alloc)) {
            safe2 += 1;
        }
    } else |err| {
        if (err != std.io.Reader.StreamError.EndOfStream) {
            return err;
        }
    }
    return .{ safe1, safe2 };
}

/// Parses a single line of input
fn parseLine(line: []const u8, alloc: std.mem.Allocator) !std.ArrayList(i32) {
    var list = std.ArrayList(i32).empty;
    errdefer list.deinit(alloc);

    var it = std.mem.splitAny(u8, line, " \n");
    while (it.next()) |word| {
        const stripped = std.mem.trim(u8, word, " \n");
        if (stripped.len == 0) continue;
        const num = try std.fmt.parseInt(i32, stripped, 10);
        try list.append(alloc, num);
    }
    return list;
}

/// Checks if the given diff is safe according to the task definition  >=1 abs(diff) <=3
fn isDiffSafe(diff: i32) bool {
    return switch (diff) {
        -3...-1 => true,
        1...3 => true,
        else => false,
    };
}

/// Check if two adjacent diffs signs are equal
fn sameDirection(diff1: i32, diff2: i32) bool {
    const sign1 = diff1 < 0;
    const sign2 = diff2 < 0;
    return sign1 == sign2;
}

/// Checks if the given list of levels is safe
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

/// Checks if the given list of levels is safe after removing an
fn isSafeAfterRemoving(levels: []const i32, alloc: std.mem.Allocator) !bool {
    if (isSafe(levels)) return true;
    var newLevels = std.ArrayList(i32).empty;
    defer newLevels.deinit(alloc);
    for (0..levels.len) |rmIdx| {
        newLevels.clearRetainingCapacity();
        for (levels, 0..) |level, idx| {
            if (idx == rmIdx) continue;
            try newLevels.append(alloc, level);
        }
        if (isSafe(newLevels.items)) return true;
    }
    return false;
}

test "parse valid line" {
    const line = "1 2 3 4 5 6 7 8 9 10\n";
    var list = try parseLine(line, t.allocator);
    defer list.deinit(t.allocator);
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

test isSafeAfterRemoving {
    try t.expect(!(try isSafeAfterRemoving(&[_]i32{ 1, 2, 7, 8, 9 }, t.allocator)));
    try t.expect(!(try isSafeAfterRemoving(&[_]i32{ 9, 7, 6, 2, 1 }, t.allocator)));
    try t.expect(try isSafeAfterRemoving(&[_]i32{ 1, 3, 2, 4, 5 }, t.allocator));
    try t.expect(try isSafeAfterRemoving(&[_]i32{ 8, 6, 4, 4, 1 }, t.allocator));
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
    const result, const after_removing = try common.parseExample(std.meta.Tuple(&.{ usize, usize }), input, totalSafe);
    try t.expectEqual(result, 2);
    try t.expectEqual(after_removing, 4);
}
