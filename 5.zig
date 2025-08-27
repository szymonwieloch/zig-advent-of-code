//! Solution to the challenge: https://adventofcode.com/2024/day/5

const std = @import("std");
const common = @import("common.zig");

/// Typedef of the integer input - allows a quick change
const Int = u32;

/// Parsed rule
const Rule = struct {
    first: Int,
    second: Int,
};

/// Collection used to keep a list of pages
const Pages = std.ArrayList(Int);

/// Collection used to keep set of rules
const Rules = std.AutoHashMap(Rule, void);

/// Parsed input
const Input = struct {
    rules: Rules,
    pages: std.ArrayList(Pages),
    fn deinit(self: *Input, alloc: std.mem.Allocator) void {
        self.rules.deinit();
        for (self.pages.items) |*pages| {
            pages.deinit(alloc);
        }
        self.pages.deinit(alloc);
    }

    fn init(alloc: std.mem.Allocator) Input {
        const rules = Rules.init(alloc);
        const pages = std.ArrayList(Pages).empty;
        return Input{ .rules = rules, .pages = pages };
    }
};

const Mode = enum { rules, pages };

const InputError = error{FormatError};

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var file = try std.fs.cwd().openFile("5.txt", .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);

    var input = try parseInput(&reader.interface, alloc);
    defer input.deinit(alloc);
    const part1 = try calcPart1(input);
    const part2 = try calcPart2(input, alloc);
    std.debug.print("Part 1: {}\nPart2: {}\n", .{ part1, part2 });
}

/// Parses the input stream
fn parseInput(reader: *std.io.Reader, alloc: std.mem.Allocator) !Input {
    var result = Input.init(alloc);
    errdefer result.deinit(alloc);
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    var mode = Mode.rules;
    //var end = false;
    while (line_it.next()) |line| {
        if (line.len == 0) {
            if (mode != Mode.rules) {
                return InputError.FormatError;
            }
            mode = Mode.pages;
            continue;
        }
        if (mode == Mode.rules) {
            const rule = try parseRule(line);
            try result.rules.put(rule, void{});
        } else {
            var pages = try parsePages(line, alloc);
            errdefer pages.deinit(alloc);
            try result.pages.append(alloc, pages);
        }
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
    }
    return result;
}

/// Parses a single rule
fn parseRule(line: []const u8) !Rule {
    var rule: Rule = undefined;
    var it = std.mem.splitSequence(u8, line, "|");
    var part = it.next() orelse return InputError.FormatError;
    rule.first = try std.fmt.parseInt(Int, part, 10);
    part = it.next() orelse return InputError.FormatError;
    rule.second = try std.fmt.parseInt(Int, part, 10);
    if (it.next() != null) {
        return InputError.FormatError;
    }
    return rule;
}

/// Parses a list of pages
fn parsePages(line: []const u8, alloc: std.mem.Allocator) !Pages {
    var pages = std.ArrayList(Int).empty;
    errdefer pages.deinit(alloc);
    var it = std.mem.splitSequence(u8, line, ",");
    while (it.next()) |part| {
        const page = try std.fmt.parseInt(Int, part, 10);
        try pages.append(alloc, page);
    }
    return pages;
}

/// Checks if the list of pages is ordered according to the provided rules
fn isOrdered(pages: []const Int, rules: Rules) bool {
    for (pages, 0..) |page1, idx| {
        for (pages[idx + 1 ..]) |page2| {
            const revRule = Rule{ .first = page2, .second = page1 };
            if (rules.contains(revRule)) {
                return false;
            }
        }
    }
    return true;
}

/// Gets the middle value from the provided list of pages
fn midValue(items: []const Int) ?Int {
    if (items.len % 2 == 0) {
        return null;
    }
    return items[items.len / 2];
}

/// Find the last element - the one after which there are no other pages
fn findLast(pages: []const Int, rules: Rules) ?usize {
    for (pages, 0..) |page, idx| {
        var key_it = rules.keyIterator();
        while (key_it.next()) |rule| {
            if (rule.first == page) break;
        } else return idx;
    }
    return null;
}

/// Chooses a subset of rules relevant to the provided list of pages
fn relevantRules(pages: []const Int, rules: Rules, alloc: std.mem.Allocator) !Rules {
    var p = std.AutoArrayHashMap(Int, void).init(alloc);
    defer p.deinit();
    for (pages) |page| {
        try p.put(page, void{});
    }
    var result = Rules.init(alloc);
    errdefer result.deinit();
    var key_it = rules.keyIterator();
    while (key_it.next()) |rule| {
        if (p.contains(rule.first) and p.contains(rule.second)) {
            try result.put(rule.*, void{});
        }
    }
    return result;
}

/// Sorts pages according to relevant rules
fn sortPages(pages: []const Int, rules: Rules, alloc: std.mem.Allocator) !Pages {
    var r = try rules.clone();
    defer r.deinit();
    var result = try Pages.initCapacity(alloc, pages.len);
    try result.appendSlice(alloc, pages);
    errdefer result.deinit(alloc);
    var i = result.items;
    while (i.len > 1) {
        const last_idx = findLast(i, r) orelse {
            var key_it = rules.keyIterator();
            while (key_it.next()) |rule| {
                std.debug.print("rule {}->{}\n", .{ rule.first, rule.second });
            }
            std.debug.print("i={any}\n", .{i});
            return InputError.FormatError;
        };
        //swap
        const last_val = i[last_idx];
        i[last_idx] = i[i.len - 1];
        i[i.len - 1] = last_val;
        i = i[0 .. i.len - 1];

        // remove all rules that end with last_val
        var rules_it = rules.keyIterator();
        while (rules_it.next()) |rule| {
            if (rule.second == last_val) _ = r.remove(rule.*);
        }
    }
    return result;
}

/// Does calculation for the part 1 of this challenge
fn calcPart1(input: Input) !Int {
    var result: Int = 0;
    for (input.pages.items) |pages| {
        if (isOrdered(pages.items, input.rules)) {
            const mid = midValue(pages.items) orelse return InputError.FormatError;
            result += mid;
        }
    }
    return result;
}

/// Does calculations for the part 2 of this challenge
fn calcPart2(input: Input, alloc: std.mem.Allocator) !Int {
    var result: Int = 0;
    for (input.pages.items) |pages| {
        if (isOrdered(pages.items, input.rules)) continue;
        var rel_rules = try relevantRules(pages.items, input.rules, alloc);
        defer rel_rules.deinit();
        var ordered = try sortPages(pages.items, rel_rules, alloc);
        defer ordered.deinit(alloc);
        const mid = midValue(ordered.items) orelse return InputError.FormatError;
        result += mid;
    }
    return result;
}

const t = std.testing;

test "parseRule" {
    const rule = try parseRule("47|53");
    try t.expectEqual(rule.first, 47);
    try t.expectEqual(rule.second, 53);
}

test parsePages {
    var pages = try parsePages("75,47,61,53,29", t.allocator);
    defer pages.deinit(t.allocator);
    try t.expectEqual(pages.items.len, 5);
    try t.expectEqual(pages.items[0], 75);
    try t.expectEqual(pages.items[1], 47);
    try t.expectEqual(pages.items[2], 61);
    try t.expectEqual(pages.items[3], 53);
    try t.expectEqual(pages.items[4], 29);
}

test isOrdered {
    var rules = Rules.init(t.allocator);
    defer rules.deinit();
    try rules.put(Rule{ .first = 97, .second = 13 }, void{});
    try rules.put(Rule{ .first = 97, .second = 61 }, void{});
    try rules.put(Rule{ .first = 97, .second = 47 }, void{});
    try rules.put(Rule{ .first = 75, .second = 29 }, void{});
    try rules.put(Rule{ .first = 61, .second = 13 }, void{});

    try t.expect(isOrdered(&[_]Int{ 75, 47, 61, 53, 29 }, rules));
    try t.expect(isOrdered(&[_]Int{ 97, 61, 53, 29, 13 }, rules));
    try t.expect(!isOrdered(&[_]Int{ 13, 97, 61, 53, 29 }, rules));
}

const example =
    \\47|53
    \\97|13
    \\97|61
    \\97|47
    \\75|29
    \\61|13
    \\75|53
    \\29|13
    \\97|29
    \\53|29
    \\61|53
    \\97|53
    \\61|29
    \\47|13
    \\75|47
    \\97|75
    \\47|61
    \\75|61
    \\47|29
    \\75|13
    \\53|13
    \\
    \\75,47,61,53,29
    \\97,61,53,29,13
    \\75,29,13
    \\75,97,47,61,53
    \\61,13,29
    \\97,13,75,29,47
;

fn parseExampleInput() !Input {
    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();
    var buffer: [1024]u8 = undefined;
    var new_reader = reader.adaptToNewApi(&buffer);
    return parseInput(&new_reader.new_interface, t.allocator);
}

test parseInput {
    var input = try parseExampleInput();
    defer input.deinit(t.allocator);
    try t.expectEqual(input.rules.count(), 21);
    try t.expectEqual(input.pages.items.len, 6);
    try t.expectEqual(input.pages.items[0].items.len, 5);
    try t.expectEqual(input.pages.items[1].items.len, 5);
    try t.expectEqual(input.pages.items[2].items.len, 3);
    try t.expectEqual(input.pages.items[3].items.len, 5);
    try t.expectEqual(input.pages.items[4].items.len, 3);
    try t.expectEqual(input.pages.items[5].items.len, 5);
}

test "example input - part 1" {
    var input = try parseExampleInput();
    defer input.deinit(t.allocator);
    try t.expectEqual(143, calcPart1(input));
}

test sortPages {
    var input = try parseExampleInput();
    defer input.deinit(t.allocator);
    const Case = struct { input: []const Int, want: []const Int };
    const cases = [_]Case{
        .{ .input = &[_]Int{ 61, 13, 29 }, .want = &[_]Int{ 61, 29, 13 } },
        .{ .input = &[_]Int{ 97, 13, 75, 29, 47 }, .want = &[_]Int{ 97, 75, 47, 29, 13 } },
        .{ .input = &[_]Int{ 75, 97, 47, 61, 53 }, .want = &[_]Int{ 97, 75, 47, 61, 53 } },
    };
    for (cases) |case| {
        var rules = try relevantRules(case.input, input.rules, t.allocator);
        defer rules.deinit();
        var sorted = try sortPages(case.input, rules, t.allocator);
        defer sorted.deinit(t.allocator);
        try t.expectEqualSlices(Int, case.want, sorted.items);
    }
}

test "example input - part 2" {
    var input = try parseExampleInput();
    defer input.deinit(t.allocator);
    try t.expectEqual(123, try calcPart2(input, t.allocator));
}
