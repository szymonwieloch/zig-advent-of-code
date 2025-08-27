//! Solution tot the challenge: https://adventofcode.com/2024/day/4

const std = @import("std");
const common = @import("common.zig");
const t = std.testing;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var m = try loadFile(alloc);
    defer m.deinit(alloc);
    const xmas = findXmasWords(&m);
    const x_mas = findMasXes(&m);
    std.debug.print("XMAS: {}\nX-MAS: {}\n", .{ xmas, x_mas });
}

const Matrix = common.Matrix(u8);
const ParsingError = error{InvalidInput};

/// Loads the input data file
fn loadFile(alloc: std.mem.Allocator) !Matrix {
    var file = try std.fs.cwd().openFile("4.txt", .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);
    return try parseInput(&reader.interface, alloc);
}

/// Parses input data stream
fn parseInput(file: *std.io.Reader, alloc: std.mem.Allocator) !Matrix {
    var result = Matrix.empty;
    errdefer result.deinit(alloc);

    var line_it = common.lineIterator(file, alloc);
    defer line_it.deinit();

    while (line_it.next()) |line| {
        var row = Matrix.Row.empty;
        errdefer row.deinit(alloc);
        try row.appendSlice(alloc, line);
        try result.appendRow(alloc, row);
    } else |err| {
        if (err != std.io.Reader.StreamError.EndOfStream) {
            return err;
        }
    }
    return result;
}

const word = "XMAS";

/// Direction is a unit length, 2-dimensional vector that indicatets a possible direction of the given move.
const Direction = struct {
    x: isize,
    y: isize,

    pub fn isPerpendicular(self: Direction, other: Direction) bool {
        return self.x * other.x + self.y * other.y == 0;
    }
};

/// All possible directions
const directions = [_]Direction{
    Direction{ .x = -1, .y = -1 },
    Direction{ .x = -1, .y = 0 },
    Direction{ .x = -1, .y = 1 },
    Direction{ .x = 0, .y = -1 },
    Direction{ .x = 0, .y = 1 },
    Direction{ .x = 1, .y = -1 },
    Direction{ .x = 1, .y = 0 },
    Direction{ .x = 1, .y = 1 },
};

/// All directions at an angle (X shape)
const x_directions = [_]Direction{
    Direction{ .x = -1, .y = -1 },
    Direction{ .x = 1, .y = -1 },
    Direction{ .x = 1, .y = 1 },
    Direction{ .x = -1, .y = 1 },
};

/// Finds all "XMAS" words
fn findXmasWords(m: *const Matrix) usize {
    var count: usize = 0;
    for (0..@intCast(m.xmax)) |x| {
        for (0..@intCast(m.ymax)) |y| {
            if (m.at(@intCast(x), @intCast(y)) == word[0]) {
                for (directions) |dir| {
                    if (wordMatches(m, @intCast(x), @intCast(y), dir)) count += 1;
                }
            }
        }
    }
    return count;
}

/// Checks if the word "XMAS" is present at the given position, at the provided direction
fn wordMatches(m: *const Matrix, x: isize, y: isize, dir: Direction) bool {
    var curx = x;
    var cury = y;
    for (0..word.len) |i| {
        const ch = m.at(curx, cury);
        if (ch == null or ch != word[i]) {
            return false;
        }
        curx += dir.x;
        cury += dir.y;
    }
    return true;
}

/// Finds all "X" shaped "MAS" words
fn findMasXes(m: *const Matrix) usize {
    var count: usize = 0;
    for (0..@intCast(m.xmax)) |x| {
        for (0..@intCast(m.ymax)) |y| {
            if (isX(m, @intCast(x), @intCast(y))) {
                count += 1;
            }
        }
    }
    return count;
}

/// Checks if "X" is present at the given position
fn isX(m: *const Matrix, x: isize, y: isize) bool {
    var buffer: [8]Direction = undefined;
    var masDirs = std.ArrayList(Direction).initBuffer(&buffer);

    //var masDirs = std.BoundedArray(Direction, 8).init(0) catch unreachable;
    for (x_directions) |dir| {
        if (isMas(m, x, y, dir)) {
            for (masDirs.items) |d| {
                if (dir.isPerpendicular(d)) {
                    return true;
                }
            }
            masDirs.appendBounded(dir) catch unreachable;
        }
    }
    return false;
}

/// Checks if the word "MAS: is present at the given position and direction
fn isMas(m: *const Matrix, x: isize, y: isize, dir: Direction) bool {
    const mPosX = x + dir.x;
    const mPosY = y + dir.y;
    const aPosX = x;
    const aPosY = y;
    const sPosX = x - dir.x;
    const sPosY = y - dir.y;
    return m.at(mPosX, mPosY) == 'M' and m.at(aPosX, aPosY) == 'A' and m.at(sPosX, sPosY) == 'S';
}

/// Matrix provided in the task description
const exampleInput =
    \\MMMSXXMASM
    \\MSAMXMSMSA
    \\AMXSXMAAMM
    \\MSAMASMSMX
    \\XMASAMXAMM
    \\XXAMMXXAMA
    \\SMSMSASXSS
    \\SAXAMASAAA
    \\MAMMMXMMMM
    \\MXMXAXMASX
;

/// For testing purposes parses the example matrix
fn exampleMatrix() !Matrix {
    var stream = std.io.fixedBufferStream(exampleInput);
    const reader = stream.reader();
    var buffer: [1024]u8 = undefined;
    var new_reader = reader.adaptToNewApi(&buffer);
    return try parseInput(&new_reader.new_interface, t.allocator);
}

test parseInput {
    var m = try exampleMatrix();
    defer m.deinit(t.allocator);
    try t.expectEqual(10, m.xmax);
    try t.expectEqual(10, m.ymax);
    try t.expect(m.at(-1, 0) == null);
    try t.expect(m.at(0, -1) == null);
    try t.expect(m.at(0, 0) == 'M');
    try t.expect(m.at(0, 10) == null);
    try t.expect(m.at(0, 9) == 'M');
    try t.expect(m.at(9, 9) == 'X');
}

test "data from the example" {
    var m = try exampleMatrix();
    defer m.deinit(t.allocator);
    try t.expectEqual(18, findXmasWords(&m));
}

test "data from the example, part 2" {
    var m = try exampleMatrix();
    defer m.deinit(t.allocator);
    try t.expectEqual(9, findMasXes(&m));
}

test isMas {
    var m = try exampleMatrix();
    defer m.deinit(t.allocator);
    try t.expect(isMas(&m, 1, 2, Direction{ .x = 0, .y = 1 }));
}

test isX {
    var m = try exampleMatrix();
    defer m.deinit(t.allocator);
    try t.expect(!isX(&m, 4, 2));
}

test "isPerpendicular" {
    const d1 = Direction{ .x = 1, .y = 0 };
    try t.expect(d1.isPerpendicular(Direction{ .x = 0, .y = 1 }));
    const d2 = Direction{ .x = 1, .y = 0 };
    try t.expect(d2.isPerpendicular(Direction{ .x = 0, .y = -1 }));
    const d3 = Direction{ .x = 1, .y = 0 };
    try t.expect(!d3.isPerpendicular(Direction{ .x = 1, .y = 0 }));
    const d4 = Direction{ .x = 1, .y = 0 };
    try t.expect(!d4.isPerpendicular(Direction{ .x = -1, .y = 0 }));

    const d5 = Direction{ .x = 1, .y = 1 };
    try t.expect(d5.isPerpendicular(Direction{ .x = -1, .y = 1 }));
    const d6 = Direction{ .x = 1, .y = 1 };
    try t.expect(d6.isPerpendicular(Direction{ .x = 1, .y = -1 }));
    const d7 = Direction{ .x = 1, .y = 1 };
    try t.expect(!d7.isPerpendicular(Direction{ .x = 1, .y = 1 }));
    const d8 = Direction{ .x = 1, .y = 1 };
    try t.expect(!d8.isPerpendicular(Direction{ .x = -1, .y = -1 }));
}
