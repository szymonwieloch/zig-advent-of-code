//! Solution tot the challenge: https://adventofcode.com/2024/day/10

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;
const Height = u8;
const Matrix = common.Matrix(Height);

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    const input = try common.parseFile(Matrix, "10.txt", alloc, parseInput);
    defer input.deinit();
    const tailheads_sum = try findTrails(input, alloc);
    std.debug.print("Sum of all trails: {}\n", .{tailheads_sum});
    const rating = findRating(input);
    std.debug.print("Rating: {}\n", .{rating});
}

/// Parses and validates a single character from the input file.
fn parseChar(c: u8) !Height {
    if (c > '9' or c < '0') {
        return common.InputError.InvalidCharacter;
    }
    return c - '0';
}

/// Parses input file, returns a 2D matrix representing the map.
fn parseInput(reader: std.io.AnyReader, alloc: std.mem.Allocator) !Matrix {
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    var result = Matrix.init(alloc);
    errdefer result.deinit();
    while (line_it.next()) |line| {
        var row = Matrix.Row.init(alloc);
        errdefer row.deinit();
        for (line) |c| {
            const value = try parseChar(c);
            try row.append(value);
        }
        try result.appendRow(row);
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
        // do nothing
    }
    return result;
}

const example_input =
    \\89010123
    \\78121874
    \\87430965
    \\96549874
    \\45678903
    \\32019012
    \\01329801
    \\10456732
;

test "parse example input" {
    var m = try common.parseExample(Matrix, example_input, parseInput);
    defer m.deinit();
    try t.expectEqual(8, m.at(0, 0));
    try t.expectEqual(3, m.at(0, 7));
    try t.expectEqual(1, m.at(7, 0));
    try t.expectEqual(2, m.at(7, 7));
    try t.expectEqual(8, m.xSize());
    try t.expectEqual(8, m.ySize());
}

const Direction = struct {
    x: isize,
    y: isize,
};
const directions = [_]Direction{
    Direction{ .x = -1, .y = 0 },
    Direction{ .x = 0, .y = -1 },
    Direction{ .x = 0, .y = 1 },
    Direction{ .x = 1, .y = 0 },
};

/// Recursive part of the trailheads calculation.
fn findTrailsRec(m: Matrix, x: isize, y: isize, curr: Height, positions: *PositionSet) !void {
    if (curr == 9) {
        try positions.put(Position{ .x = x, .y = y }, void{});
        return;
    }
    const next = curr + 1;
    for (directions) |dir| {
        const nx = x + dir.x;
        const ny = y + dir.y;
        if (m.at(nx, ny) == next) {
            try findTrailsRec(m, nx, ny, next, positions);
        }
    }
}

const Position = struct {
    x: isize,
    y: isize,
};

const PositionSet = std.AutoHashMap(Position, void);

/// Returns sum of trailheads - solution to the part 1 problem.
fn findTrails(m: Matrix, alloc: std.mem.Allocator) !usize {
    var total: usize = 0;
    for (0..@intCast(m.xSize())) |x| {
        for (0..@intCast(m.ySize())) |y| {
            if (m.at(@intCast(x), @intCast(y)) == 0) {
                var positions = PositionSet.init(alloc);
                defer positions.deinit();
                try findTrailsRec(m, @intCast(x), @intCast(y), 0, &positions);
                const count = positions.count();
                // if (count > 0) {
                //     std.debug.print("Found {} trails starting at ({}, {})\n", .{ count, x, y });
                // }
                total += count;
            }
        }
    }
    return total;
}

test "data from the example" {
    const m = try common.parseExample(Matrix, example_input, parseInput);
    defer m.deinit();
    try t.expectEqual(36, try findTrails(m, t.allocator));
}

/// Returns sum of all railings - solution to the part 2 problem.
fn findRating(m: Matrix) usize {
    var total: usize = 0;
    for (0..@intCast(m.xSize())) |x| {
        for (0..@intCast(m.ySize())) |y| {
            if (m.at(@intCast(x), @intCast(y)) == 0) {
                total += findRatingRec(m, @intCast(x), @intCast(y), 0);
            }
        }
    }
    return total;
}

/// Recursive part of the rating calculation.
fn findRatingRec(m: Matrix, x: isize, y: isize, curr: Height) usize {
    if (curr == 9) {
        return 1;
    }
    var count: usize = 0;
    const next = curr + 1;
    for (directions) |dir| {
        const nx = x + dir.x;
        const ny = y + dir.y;
        if (m.at(nx, ny) == next) {
            count += findRatingRec(m, nx, ny, next);
        }
    }
    return count;
}

test "rating from the example" {
    const m = try common.parseExample(Matrix, example_input, parseInput);
    defer m.deinit();
    try t.expectEqual(81, findRating(m));
}
