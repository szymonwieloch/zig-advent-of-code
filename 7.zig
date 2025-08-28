//! Solution tot the challenge: https://adventofcode.com/2024/day/7

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var file = try std.fs.cwd().openFile("7.txt", .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);
    var eqs = try parseInput(&reader.interface, alloc);
    defer freeEquations(alloc, &eqs);
    const result1 = totalCalibrationResult(eqs);
    const result2 = try totalCalibrationResult2(eqs);
    std.debug.print("Result - part 1: {d}\nResult - part 2: {d}\n", .{ result1, result2 });
}

const InputError = error{FormatError};

const Int = u64;

const Equation = struct { test_value: Int, numbers: std.ArrayList(Int) };
const Equations = std.ArrayList(Equation);

/// Deinitializes Equations on a deep level
fn freeEquations(alloc: std.mem.Allocator, eqs: *Equations) void {
    for (eqs.items) |*eq| {
        eq.numbers.deinit(alloc);
    }
    eqs.deinit(alloc);
}

/// Parses input into a structure
fn parseInput(reader: *std.io.Reader, alloc: std.mem.Allocator) !Equations {
    var result = Equations.empty;
    errdefer freeEquations(alloc, &result);
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        if (line.len == 0) continue;
        var split_it = std.mem.splitSequence(u8, line, ": ");
        const part1 = split_it.next() orelse return InputError.FormatError;
        const test_value = try std.fmt.parseInt(Int, part1, 10);
        const part2 = split_it.next() orelse return InputError.FormatError;
        if (split_it.next() != null) return InputError.FormatError;

        var num_it = std.mem.splitScalar(u8, part2, ' ');
        var eq = Equation{ .test_value = test_value, .numbers = std.ArrayList(Int).empty };
        errdefer eq.numbers.deinit(alloc);
        while (num_it.next()) |num| {
            const parsed = try std.fmt.parseInt(Int, num, 10);
            try eq.numbers.append(alloc, parsed);
        }
        try result.append(alloc, eq);
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
    return result;
}

const example_input =
    \\190: 10 19
    \\3267: 81 40 27
    \\83: 17 5
    \\156: 15 6
    \\7290: 6 8 6 15
    \\161011: 16 10 13
    \\192: 17 8 14
    \\21037: 9 7 18 13
    \\292: 11 6 16 20
;

/// Parses exmple input from the task description
fn parseExampleInput() !Equations {
    var stream = std.io.fixedBufferStream(example_input);
    const reader = stream.reader();
    var buffer: [1024]u8 = undefined;
    var new_reader = reader.adaptToNewApi(&buffer);
    return try parseInput(&new_reader.new_interface, t.allocator);
}

test "parse example input" {
    var data = try parseExampleInput();
    defer freeEquations(t.allocator, &data);
    try t.expectEqual(9, data.items.len);
    try t.expectEqual(data.items[3].test_value, 156);
    try t.expectEqualSlices(Int, &[_]Int{ 81, 40, 27 }, data.items[1].numbers.items);
}

/// Checks if the given case can be solved by choosing the right operators
fn canBeSolved(test_value: Int, nums: []const Int) bool {
    assert(nums.len > 0);
    const attempts = std.math.pow(usize, 2, nums.len - 1);
    for (0..attempts) |attempt| {
        var curr = nums[0];
        for (nums[1..], 0..) |el, idx| {
            const shift: u6 = @intCast(idx);
            const shifted = @as(usize, 1) << shift;
            if ((attempt & shifted) != 0) {
                curr += el;
            } else {
                curr *= el;
            }
        }
        if (curr == test_value) return true;
    }
    return false;
}

test canBeSolved {
    try t.expect(canBeSolved(292, &[_]Int{ 11, 6, 16, 20 }));
    try t.expect(canBeSolved(190, &[_]Int{ 10, 19 }));
    try t.expect(canBeSolved(3267, &[_]Int{ 81, 40, 27 }));

    try t.expect(!canBeSolved(83, &[_]Int{ 17, 5 }));
    try t.expect(!canBeSolved(161011, &[_]Int{ 16, 10, 13 }));
}

/// Calculates solution to the part 1 of the challenge
fn totalCalibrationResult(eqs: Equations) Int {
    var result: Int = 0;
    for (eqs.items) |eq| {
        if (canBeSolved(eq.test_value, eq.numbers.items)) result += eq.test_value;
    }
    return result;
}

test "test example input" {
    var eqs = try parseExampleInput();
    defer freeEquations(t.allocator, &eqs);

    const result = totalCalibrationResult(eqs);
    try t.expectEqual(3749, result);
}

/// Returns a number that is a combination of digits of inputs
fn combineDigits(a: Int, b: Int) !Int {
    var buf: [100]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    stream.reset();
    try stream.writer().print("{d}{d}", .{ a, b });

    return std.fmt.parseInt(Int, stream.getWritten(), 10);
}

test combineDigits {
    try t.expectEqual(11, try combineDigits(1, 1));
    try t.expectEqual(123456, try combineDigits(123, 456));
    try t.expectEqual(400, try combineDigits(40, 0));
}

/// Gets the idx-th digit (counting from right) of num in the 3-base digit system
fn getDigit(num: usize, idx: usize) usize {
    var curr = num;
    for (0..idx) |_| {
        curr /= 3;
    }
    return curr % 3;
}

test getDigit {
    // 2210 = 54+18+3+0 = 75
    try t.expectEqual(0, getDigit(75, 0));
    try t.expectEqual(1, getDigit(75, 1));
    try t.expectEqual(2, getDigit(75, 2));
    try t.expectEqual(2, getDigit(75, 3));
}

/// Part 2 version of this function, uses 3 operators
fn canBeSolved2(test_value: Int, nums: []const Int) !bool {
    assert(nums.len > 0);
    const attempts = std.math.pow(usize, 3, nums.len - 1);
    for (0..attempts) |attempt| {
        var curr = nums[0];
        for (nums[1..], 0..) |el, idx| {
            switch (getDigit(attempt, idx)) {
                0 => curr += el,
                1 => curr *= el,
                2 => curr = try combineDigits(curr, el),
                else => unreachable,
            }
        }
        if (curr == test_value) return true;
    }
    return false;
}

test canBeSolved2 {
    try t.expect(try canBeSolved2(292, &[_]Int{ 11, 6, 16, 20 }));
    try t.expect(try canBeSolved2(190, &[_]Int{ 10, 19 }));
    try t.expect(try canBeSolved2(3267, &[_]Int{ 81, 40, 27 }));
    try t.expect(try canBeSolved2(156, &[_]Int{ 15, 6 }));
    try t.expect(try canBeSolved2(7290, &[_]Int{ 6, 8, 6, 15 }));
    try t.expect(try canBeSolved2(192, &[_]Int{ 17, 8, 14 }));

    try t.expect(!try canBeSolved2(83, &[_]Int{ 17, 5 }));
    try t.expect(!try canBeSolved2(161011, &[_]Int{ 16, 10, 13 }));
}

/// Part 2 version of this function, calculates the final result
fn totalCalibrationResult2(eqs: Equations) !Int {
    var result: Int = 0;
    for (eqs.items) |eq| {
        if (try canBeSolved2(eq.test_value, eq.numbers.items)) result += eq.test_value;
    }
    return result;
}

test "test example input - part 2" {
    var eqs = try parseExampleInput();
    defer freeEquations(t.allocator, &eqs);

    const result = try totalCalibrationResult2(eqs);
    try t.expectEqual(11387, result);
}
