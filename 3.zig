//! Solution to this AOC problem: https://adventofcode.com/2024/day/3

const std = @import("std");
const common = @import("common.zig");
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    // var file = try std.fs.cwd().openFile("3.txt", .{});
    // defer file.close();
    // var buffer: [1024]u8 = undefined;
    // var reader = file.reader(&buffer);
    const mulSum = try common.parseFile(usize, "3.txt", alloc, sumMulsInStream);
    const mulSumWithDoDonts = try common.parseFile(usize, "3.txt", alloc, sumMulsInStreamWithDoDonts);
    std.debug.print("Result: {}\nWith do/don'ts: {}\n", .{ mulSum, mulSumWithDoDonts });
}

/// Returns sum of "mul" elements in the given stream
fn sumMulsInStream(in_stream: *std.io.Reader, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    var line_it = common.lineIterator(in_stream, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        result += sumMuls(line);
    } else |err| {
        if (err != std.io.Reader.StreamError.EndOfStream) {
            return err;
        }
    }
    return result;
}

/// Returns sum of "mul" elements in the given stream, but only those after "do" and not after "don't" words
fn sumMulsInStreamWithDoDonts(in_stream: *std.io.Reader, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    var enabled = true;
    var line_it = common.lineIterator(in_stream, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        const res = sumMulsWithDoDont(line, enabled);
        result += res[0];
        enabled = res[1];
    } else |err| {
        if (err != std.io.Reader.StreamError.EndOfStream) {
            return err;
        }
    }
    return result;
}

const MulsSum = std.meta.Tuple(&.{ usize, bool });

/// Returns sum of "mul" object in the given line and the latest do/don't status
fn sumMulsWithDoDont(line: []const u8, startsEnabled: bool) MulsSum {
    var result: usize = 0;
    var enabled = startsEnabled;
    for (0..line.len) |i| {
        const curr = line[i..];
        if (isDo(curr)) {
            enabled = true;
        } else if (isDont(curr)) {
            enabled = false;
        } else if (enabled) {
            if (evalMul(line[i..])) |num| {
                result += num;
            }
        }
    }
    return .{ result, enabled };
}

/// Returns sum of "mul" objects in the given line of input
fn sumMuls(line: []const u8) usize {
    var result: usize = 0;
    for (0..line.len) |i| {
        if (evalMul(line[i..])) |num| {
            result += num;
        }
    }
    return result;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

const prefix = "mul(";
const postfix = ')';
const comma = ',';
const do = "do()";
const dont = "don't()";

/// Evaluates "mul" object - returns value if it is present at the beginning of the string null otherwise
fn evalMul(val: []const u8) ?usize {
    var str = val[0..];
    if (!std.mem.startsWith(u8, str, prefix)) return null;
    str = str[prefix.len..];
    const num1 = consumeNumber(str) orelse return null;
    str = num1[1];
    str = consumeCharacter(str, comma) orelse return null;
    const num2 = consumeNumber(str) orelse return null;
    str = num2[1];
    _ = consumeCharacter(str, postfix) orelse return null;
    return num1[0] * num2[0];
}

fn isDo(val: []const u8) bool {
    return std.mem.startsWith(u8, val, do);
}

fn isDont(val: []const u8) bool {
    return std.mem.startsWith(u8, val, dont);
}

const ConsumedNumber = std.meta.Tuple(&.{ usize, []const u8 });

/// Reads a number and returns string after the number
fn consumeNumber(str: []const u8) ?ConsumedNumber {
    if (str.len == 0) {
        return null;
    }
    if (!isDigit(str[0])) {
        return null;
    }
    var str_num: []const u8 = str[0..1];
    if (str.len > 1 and isDigit(str[1])) {
        str_num = str[0..2];
        if (str.len > 2 and isDigit(str[2])) {
            str_num = str[0..3];
        }
    }

    const num = std.fmt.parseInt(usize, str_num, 10) catch return null;
    return ConsumedNumber{ num, str[str_num.len..] };
}

/// Gets one character from the string
fn consumeCharacter(str: []const u8, c: u8) ?[]const u8 {
    return if (str.len == 0 or str[0] != c) null else str[1..];
}

test isDigit {
    try t.expect(isDigit('0'));
    try t.expect(isDigit('9'));
    try t.expect(!isDigit('a'));
    try t.expect(!isDigit(' '));
}

test consumeCharacter {
    const res = consumeCharacter("a", 'a') orelse unreachable;
    try t.expectEqualStrings(res, "");
    try t.expect(null == consumeCharacter("a", 'b'));
    try t.expect(null == consumeCharacter("", 'a'));
}

test evalMul {
    try t.expect(2 == evalMul("mul(1,2)"));
    try t.expect(30135 == evalMul("mul(123,245)"));
    try t.expect(2 == evalMul("mul(1,2)abcd"));

    try t.expect(null == evalMul("mul(1,2,3)"));
    try t.expect(null == evalMul("mul(1234,5)"));
    try t.expect(null == evalMul("mu(1,2)"));
    try t.expect(null == evalMul("mul(1,2"));
    try t.expect(null == evalMul("mul(1.2)"));
}

test consumeNumber {
    const res = consumeNumber("123abc") orelse unreachable;
    try t.expect(res[0] == 123);
    try t.expect(std.mem.eql(u8, res[1], "abc"));

    const res2 = consumeNumber("12abc") orelse unreachable;
    try t.expect(res2[0] == 12);
    try t.expect(std.mem.eql(u8, res2[1], "abc"));

    const res3 = consumeNumber("9") orelse unreachable;
    try t.expect(res3[0] == 9);
    try t.expect(std.mem.eql(u8, res3[1], ""));

    const res4 = consumeNumber("1,2)") orelse unreachable;
    try t.expect(res4[0] == 1);
    try t.expect(std.mem.eql(u8, res4[1], ",2)"));

    try t.expect(null == consumeNumber("abc"));
    try t.expect(null == consumeNumber(""));
}

test sumMuls {
    try t.expect(sumMuls("mul(1,2)abcmul(1,2)?!!") == 4);
}

const example1 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";
test "check example from description" {
    const result = try common.parseExample(usize, example1, sumMulsInStream);
    try t.expect(result == 161);
}

const example2 = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
test "sum with do and don'ts" {
    const res = sumMulsWithDoDont(example2, true);
    try t.expectEqual(48, res[0]);
    try t.expect(res[1]);
}
