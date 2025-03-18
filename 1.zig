//! Solution to this AOC problem: https://adventofcode.com/2024/day/1

const std = @import("std");
const common = @import("common.zig");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const talloc = std.testing.allocator;

/// A struct representing a single line of the input file.
const LineEntry = struct {
    first: i32,
    second: i32,
};

/// A struct representing the two lists read from the input file.
const Lists = struct {
    list1: std.ArrayList(i32),
    list2: std.ArrayList(i32),
};

const LineParsingError = error{ TooManyNumbers, NotEnoughNumbers };

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var file = try std.fs.cwd().openFile("1.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader().any();
    var lists = try readInput(alloc, in_stream);
    defer lists.list1.deinit();
    defer lists.list2.deinit();
    std.mem.sort(i32, lists.list1.items, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, lists.list2.items, {}, comptime std.sort.asc(i32));
    const dist = listsDistance(lists.list1.items, lists.list2.items);
    const similarity = try similarityScore(lists.list1.items, lists.list2.items, alloc);
    std.debug.print("Distance: {}\nSimilarity: {}\n", .{ dist, similarity });
}

/// Reads two lists from the input file.
fn readInput(alloc: std.mem.Allocator, in_stream: std.io.AnyReader) !Lists {
    var buf: [1024]u8 = undefined;
    var list1 = std.ArrayList(i32).init(alloc);
    errdefer list1.deinit();
    var list2 = std.ArrayList(i32).init(alloc);
    errdefer list2.deinit();
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const entry = try parseLine(line);
        try list1.append(entry.first);
        try list2.append(entry.second);
    }
    return Lists{ .list1 = list1, .list2 = list2 };
}

/// Parsers a single line of the input file.
fn parseLine(line: []const u8) !LineEntry {
    var first: ?i32 = null;
    var second: ?i32 = null;
    var it = std.mem.splitAny(u8, line, " \n");
    while (it.next()) |word| {
        const stripped = std.mem.trim(u8, word, " \n");
        if (stripped.len == 0) continue;

        const num = try std.fmt.parseInt(i32, stripped, 10);
        if (first == null) {
            first = num;
        } else if (second == null) {
            second = num;
        } else {
            return LineParsingError.TooManyNumbers;
        }
    }
    if (first) |f| {
        if (second) |s| {
            return LineEntry{ .first = f, .second = s };
        }
    }
    return LineParsingError.NotEnoughNumbers;
}

/// assumes inputs are sorted and have the same length
fn listsDistance(list1: []const i32, list2: []const i32) i32 {
    var result: i32 = 0;
    for (list1, list2) |x, y| {
        result += distance(x, y);
    }
    return result;
}

/// Returns the absolute distance between two numbers.
fn distance(x: i32, y: i32) i32 {
    const result = x - y;
    return if (result > 0) result else -result;
}

fn similarityScore(list1: []const i32, list2: []const i32, alloc: std.mem.Allocator) !i32 {
    var counts = std.AutoHashMap(i32, i32).init(alloc);
    defer counts.deinit();
    for (list2) |y| {
        (try counts.getOrPutValue(y, 0)).value_ptr.* += 1;
    }
    var result: i32 = 0;
    for (list1) |x| {
        result += x * (counts.get(x) orelse 0);
    }
    return result;
}

test "parse correct line" {
    const line = "1 2\n";
    const entry = try parseLine(line);
    try expect(entry.first == 1);
    try expect(entry.second == 2);
}

test "parse line with too many numbers" {
    const line = "1 2 3\n";
    try expectError(LineParsingError.TooManyNumbers, parseLine(line));
}

test "parse line with not enough numbers" {
    const line = "1\n";
    try expectError(LineParsingError.NotEnoughNumbers, parseLine(line));
}

test "parse empty line" {
    const line = "\n";
    try expectError(LineParsingError.NotEnoughNumbers, parseLine(line));
}

test "parse line with invalid characters" {
    const line = "1 a\n";
    try expectError(std.fmt.ParseIntError.InvalidCharacter, parseLine(line));
}

test "parse input file" {
    const input = "1 2\n3 4\n";
    var stream = std.io.fixedBufferStream(input);
    const reader = stream.reader();
    const anyReader = reader.any();
    const lists = try readInput(talloc, anyReader);
    try expect(lists.list1.items.len == 2);
    try expect(lists.list2.items.len == 2);
    try expect(lists.list1.items[0] == 1);
    try expect(lists.list1.items[1] == 3);
    try expect(lists.list2.items[0] == 2);
    try expect(lists.list2.items[1] == 4);
    lists.list1.deinit();
    lists.list2.deinit();
}

test distance {
    try expect(distance(1, 2) == 1);
    try expect(distance(2, 1) == 1);
    try expect(distance(0, 0) == 0);
    try expect(distance(1, 1) == 0);
}

test listsDistance {
    const list1 = [_]i32{ 1, 2, 3 };
    const list2 = [_]i32{ -3, 3, 0 };
    try expect(listsDistance(&list1, &list2) == 8);
}

test similarityScore {
    const list1 = [_]i32{ 1, 2, 3 };
    const list2 = [_]i32{ 3, 3, 1 };
    try expect(try similarityScore(&list1, &list2, talloc) == 7);
}
