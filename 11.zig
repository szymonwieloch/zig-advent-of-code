//! Solution tot the challenge: https://adventofcode.com/2024/day/11

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var input = try common.parseFile(Day, "11.txt", alloc, parseInput);
    defer input.deinit(alloc);
    var day25 = try blinkNTimes(input.items, 25, alloc);
    defer day25.deinit(alloc);
    std.debug.print("Rocks after 25 days: {d}\n", .{day25.items.len});
    var counted = try countRocks(input.items, alloc);
    defer counted.deinit();
    var day75_counted = try blinkNTimesCounted(counted, 75, alloc);
    defer day75_counted.deinit();
    const count_75 = count(day75_counted);
    std.debug.print("Rocks after 75 days: {d}\n", .{count_75});
}

/// Integer type used in this solution.
const Int = u64;
/// Represent stone of one day.
const Day = std.ArrayList(Int);
/// Represents the number of stones of a day but grouped by their value.
/// This is used to speed up the calculation of the next day.
/// The key is the value of the stone and the value is the number of stones
/// with that value.
const CountedDay = std.AutoHashMap(Int, usize);

/// Parses the input file.
fn parseInput(reader: *std.io.Reader, alloc: std.mem.Allocator) !Day {
    var result = Day.empty;
    errdefer result.deinit(alloc);
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    const line = try line_it.next();
    var part_it = std.mem.splitScalar(u8, line, ' ');
    while (part_it.next()) |part| {
        const num = try std.fmt.parseInt(Int, part, 10);
        try result.append(alloc, num);
    }
    return result;
}

const example_input = "125 17\n";

test "parseInput" {
    var day = try common.parseExample(Day, example_input, parseInput);
    defer day.deinit(t.allocator);
    try t.expectEqualSlices(Int, &[_]Int{ 125, 17 }, day.items);
}

/// Emulates one blink using a naive approach.
fn blinkOnce(prev: []const Int, alloc: std.mem.Allocator) !Day {
    var result = Day.empty;
    errdefer result.deinit(alloc);
    for (prev) |rock| {
        if (rock == 0) {
            try result.append(alloc, 1);
            continue;
        }
        const nums = split(rock);
        if (nums) |pair| {
            const a, const b = pair;
            try result.append(alloc, a);
            try result.append(alloc, b);
            continue;
        }
        try result.append(alloc, rock * 2024);
    }
    return result;
}

test blinkOnce {
    var next = try blinkOnce(&[_]Int{ 0, 1, 10, 99, 999 }, t.allocator);
    defer next.deinit(t.allocator);
    try t.expectEqualSlices(Int, &[_]Int{ 1, 2024, 1, 0, 9, 9, 2021976 }, next.items);
}

/// Emulates n blinks using a naive approach.
fn blinkNTimes(input: []const Int, n: usize, alloc: std.mem.Allocator) !Day {
    var curr = Day.empty;
    errdefer curr.deinit(alloc);
    try curr.appendSlice(alloc, input);
    for (0..n) |_| {
        const next = try blinkOnce(curr.items, alloc);
        curr.deinit(alloc);
        curr = next;
    }
    return curr;
}

test "handle example input" {
    var input = try common.parseExample(Day, example_input, parseInput);
    defer input.deinit(t.allocator);
    var day6 = try blinkNTimes(input.items, 6, t.allocator);
    try t.expectEqual(22, day6.items.len);
    defer day6.deinit(t.allocator);
    var day25 = try blinkNTimes(input.items, 25, t.allocator);
    try t.expectEqual(55312, day25.items.len);
    defer day25.deinit(t.allocator);
}

/// Splits the input number into two numbers.
/// If the input number has an odd number of digits, it returns null.
fn split(num: Int) ?std.meta.Tuple(&.{ Int, Int }) {
    var buffer: [100]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    stream.writer().print("{}", .{num}) catch unreachable;
    if (stream.pos % 2 == 1) return null;
    const half = stream.pos / 2;
    const a = std.fmt.parseInt(Int, stream.buffer[0..half], 10) catch unreachable;
    const b = std.fmt.parseInt(Int, stream.buffer[half..stream.pos], 10) catch unreachable;
    return .{ a, b };
}

test "split" {
    const a, const b = split(1234) orelse unreachable;
    try t.expectEqual(12, a);
    try t.expectEqual(34, b);
    try t.expectEqual(null, split(123));
    const c, const d = split(1000) orelse unreachable;
    try t.expectEqual(10, c);
    try t.expectEqual(0, d);
}

/// Transforms a regular Day into a CountedDay.
fn countRocks(day: []const Int, alloc: std.mem.Allocator) !CountedDay {
    var result = CountedDay.init(alloc);
    for (day) |rock| {
        (try result.getOrPutValue(rock, 0)).value_ptr.* += 1;
    }
    return result;
}

/// Same as blinkOnce but using a CountedDay.
/// This is used to speed up the calculation of the next day.
fn blinkOnceCounted(day: CountedDay, alloc: std.mem.Allocator) !CountedDay {
    var result = CountedDay.init(alloc);
    var pair_it = day.iterator();
    while (pair_it.next()) |pair| {
        const rock = pair.key_ptr.*;
        const cnt = pair.value_ptr.*;
        if (rock == 0) {
            const entry = try result.getOrPutValue(1, 0);
            entry.value_ptr.* += cnt;
            continue;
        }
        const nums = split(rock);
        if (nums) |split_pair| {
            const a, const b = split_pair;
            (try result.getOrPutValue(a, 0)).value_ptr.* += cnt;
            (try result.getOrPutValue(b, 0)).value_ptr.* += cnt;
            continue;
        }
        (try result.getOrPutValue(rock * 2024, 0)).value_ptr.* += cnt;
    }
    return result;
}

/// Same as blinkNTimes but using a CountedDay.
/// This is used to speed up the calculation of the next day.
fn blinkNTimesCounted(input: CountedDay, n: usize, alloc: std.mem.Allocator) !CountedDay {
    var curr = try input.clone();
    errdefer curr.deinit();
    for (0..n) |_| {
        const next = try blinkOnceCounted(curr, alloc);
        curr.deinit();
        curr = next;
    }
    return curr;
}

/// Returns the number of rocks in the given CountedDay.
fn count(day: CountedDay) usize {
    var result: usize = 0;
    var pair_it = day.iterator();
    while (pair_it.next()) |pair| {
        const cnt = pair.value_ptr.*;
        result += cnt;
    }
    return result;
}
