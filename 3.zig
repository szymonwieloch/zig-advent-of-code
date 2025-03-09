//! Solution to this AOC problem: https://adventofcode.com/2024/day/3

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
    var file = try std.fs.cwd().openFile("3.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader().any();
    const mulSum = try sumMulsInStream(in_stream, alloc);
    try file.seekTo(0);
    const mulSumWithDoDonts = try sumMulsInStreamWithDoDonts(in_stream, alloc);
    std.debug.print("Result: {}\nWith do/don'ts: {}\n", .{ mulSum, mulSumWithDoDonts });
}

fn sumMulsInStream(in_stream: std.io.AnyReader, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    while (try in_stream.readUntilDelimiterOrEofAlloc(alloc, '\n', 110240)) |line| {
        defer alloc.free(line);
        result += sumMuls(line);
    }
    return result;
}

fn sumMulsInStreamWithDoDonts(in_stream: std.io.AnyReader, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    var enabled = true;
    while (try in_stream.readUntilDelimiterOrEofAlloc(alloc, '\n', 110240)) |line| {
        defer alloc.free(line);
        const res = sumMulsWithDoDont(line, enabled);
        result += res[0];
        enabled = res[1];
    }
    return result;
}

const MulsSum = std.meta.Tuple(&.{ usize, bool });

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

fn consumeCharacter(str: []const u8, c: u8) ?[]const u8 {
    return if (str.len == 0 or str[0] != c) null else str[1..];
}

const t = std.testing;

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
    var stream = std.io.fixedBufferStream(example1);
    const reader = stream.reader();
    const anyReader = reader.any();
    try t.expect(try sumMulsInStream(anyReader, t.allocator) == 161);
}

const example2 = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
test "sum with do and don'ts" {
    const res = sumMulsWithDoDont(example2, true);
    try t.expectEqual(48, res[0]);
    try t.expect(res[1]);
}
