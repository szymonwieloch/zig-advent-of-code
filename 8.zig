//! Solution tot the challenge: https://adventofcode.com/2024/day/7

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var file = try std.fs.cwd().openFile("8.txt", .{});
    defer file.close();
    var input, const dim = try parseInput(file.reader().any(), alloc);
    defer freeInput(&input);

    const result1 = try allAntinodes(input, dim, alloc);
    const result2 = try allAntinodesWithResonantHarmonics(input, dim, alloc);
    std.debug.print("Antinodes: {d}\nAntinodes with resonant harmonics: {d}\n", .{ result1, result2 });
}

const Coordinate = isize;

/// Works as both position on the map and a vector
const Position = struct {
    x: Coordinate,
    y: Coordinate,

    fn sub(self: Position, other: Position) Position {
        return Position{ .x = self.x - other.x, .y = self.y - other.y };
    }

    fn add(self: Position, other: Position) Position {
        return Position{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

// Dimensions of the map
const Dimensions = struct {
    xmax: Coordinate,
    ymax: Coordinate,

    fn fits(self: Dimensions, pos: Position) bool {
        return pos.x >= 0 and pos.x < self.xmax and pos.y >= 0 and pos.y < self.ymax;
    }
};

const Input = std.AutoHashMap(u8, std.ArrayList(Position));

fn freeInput(in: *Input) void {
    var val_it = in.valueIterator();
    while (val_it.next()) |list| {
        list.deinit();
    }
    in.deinit();
}

const ParsingError = error{DimensionMismatch};

fn parseInput(reader: std.io.AnyReader, alloc: std.mem.Allocator) !std.meta.Tuple(&.{ Input, Dimensions }) {
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    var result = Input.init(alloc);
    errdefer freeInput(&result);
    var xmax: isize = 0;
    var ymax: isize = 0;
    var x: isize = 0;
    while (line_it.next()) |line| {
        assert(line.len > 0);
        if (xmax == 0) {
            xmax = @intCast(line.len);
        } else if (line.len != xmax) return ParsingError.DimensionMismatch;
        ymax += 1;
        for (line, 0..) |ch, y| {
            if (ch == '.') continue;
            const entry = try result.getOrPutValue(ch, std.ArrayList(Position).init(alloc));
            try entry.value_ptr.*.append(Position{ .x = @intCast(x), .y = @intCast(y) });
        }
        x += 1;
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
    return .{ result, Dimensions{ .xmax = xmax, .ymax = ymax } };
}

const example_input =
    \\............
    \\........0...
    \\.....0......
    \\.......0....
    \\....0.......
    \\......A.....
    \\............
    \\............
    \\........A...
    \\.........A..
    \\............
    \\............
;

fn parseExampleInput() !std.meta.Tuple(&.{ Input, Dimensions }) {
    var stream = std.io.fixedBufferStream(example_input);
    const reader = stream.reader();
    const anyReader = reader.any();
    return parseInput(anyReader, t.allocator);
}

test "parse example input" {
    var input, const dim = try parseExampleInput();
    defer freeInput(&input);
    try t.expectEqual(2, input.count());
    try t.expectEqual(12, dim.xmax);
    try t.expectEqual(12, dim.ymax);
    try t.expectEqual(input.get('A').?.items.len, 3);
    try t.expectEqual(input.get('A').?.items[2], Position{ .x = 9, .y = 9 });
}

fn antinodes(a: Position, b: Position) std.meta.Tuple(&.{ Position, Position }) {
    const diff = a.sub(b);
    return .{ a.add(diff), b.sub(diff) };
}

test antinodes {
    const a = Position{ .x = 3, .y = 3 };
    const b = Position{ .x = 4, .y = 7 };
    const i, const j = antinodes(a, b);
    try t.expectEqual(Position{ .x = 5, .y = 11 }, j);
    try t.expectEqual(Position{ .x = 2, .y = -1 }, i);
}

/// For the given letter returns the number of all antinodes
fn allAntinodesOfTheSameType(input: []const Position, dim: Dimensions, antinodesPos: *std.AutoHashMap(Position, void)) !void {
    for (input, 1..) |a, idx| {
        for (input[idx..]) |b| {
            const i, const j = antinodes(a, b);
            if (dim.fits(i)) try antinodesPos.put(i, void{});
            if (dim.fits(j)) try antinodesPos.put(j, void{});
        }
    }
}

/// Returns all antinodes using the definition from part 1
fn allAntinodes(input: Input, dim: Dimensions, alloc: std.mem.Allocator) !usize {
    var positions = std.AutoHashMap(Position, void).init(alloc);
    defer positions.deinit();

    var val_it = input.valueIterator();
    while (val_it.next()) |val| {
        try allAntinodesOfTheSameType(val.*.items, dim, &positions);
    }
    return positions.count();
}

test "check example input" {
    var input, const dim = try parseExampleInput();
    defer freeInput(&input);
    const count = try allAntinodes(input, dim, t.allocator);
    try t.expectEqual(14, count);
}

fn allAntinodesOfTheSameTypeWithResonantHarmonics(input: []const Position, dim: Dimensions, antinodesPos: *std.AutoHashMap(Position, void)) !void {
    for (input, 1..) |a, idx| {
        for (input[idx..]) |b| {
            const diff = a.sub(b);
            var curr = a;
            while (dim.fits(curr)) {
                try antinodesPos.put(curr, void{});
                curr = curr.add(diff);
            }
            curr = a;
            while (dim.fits(curr)) {
                try antinodesPos.put(curr, void{});
                curr = curr.sub(diff);
            }
        }
    }
}

/// Part 2 result
fn allAntinodesWithResonantHarmonics(input: Input, dim: Dimensions, alloc: std.mem.Allocator) !usize {
    var positions = std.AutoHashMap(Position, void).init(alloc);
    defer positions.deinit();

    var val_it = input.valueIterator();
    while (val_it.next()) |val| {
        try allAntinodesOfTheSameTypeWithResonantHarmonics(val.items, dim, &positions);
    }
    return positions.count();
}

test "check example input - part 2" {
    var input, const dim = try parseExampleInput();
    defer freeInput(&input);
    const count = try allAntinodesWithResonantHarmonics(input, dim, t.allocator);
    try t.expectEqual(34, count);
}
