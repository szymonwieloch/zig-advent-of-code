//! Solution tot the challenge: https://adventofcode.com/2024/day/6

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var file = try std.fs.cwd().openFile("6.txt", .{});
    defer file.close();
    var map, const gpos = try parseInput(file.reader().any(), alloc);
    defer map.deinit();
    var positions = try simulateGuardian(map, gpos, alloc);
    defer positions.deinit();
    const block_pos = try tryPlacingObstacles(&map, positions, gpos, alloc);
    std.debug.print("Positions: {}\nPlaces to put an obstacle: {}\n", .{ positions.count(), block_pos });
}

const InputError = error{ InvalidCharacter, RowLengthMismatch, NoGuardian };

const Field = enum(u8) { empty, obstacle };

const Map = struct {
    map: std.ArrayList(std.ArrayList(Field)),
    xmax: isize,
    ymax: isize,

    fn appendRow(self: *Map, row: std.ArrayList(Field)) !void {
        if (self.map.items.len > 0) {
            if (row.items.len != self.ymax) return InputError.RowLengthMismatch;
        } else {
            self.ymax = @intCast(row.items.len);
        }
        try self.map.append(row);
        self.xmax = @intCast(self.map.items.len);
    }

    fn init(alloc: std.mem.Allocator) Map {
        return Map{
            .map = std.ArrayList(std.ArrayList(Field)).init(alloc),
            .xmax = 0,
            .ymax = 0,
        };
    }

    fn deinit(self: Map) void {
        for (self.map.items) |row| {
            row.deinit();
        }
        self.map.deinit();
    }

    fn at(self: Map, x: isize, y: isize) ?Field {
        if (x < 0 or x >= self.xmax) return null;
        if (y < 0 or y >= self.ymax) return null;
        return self.map.items[@intCast(x)].items[@intCast(y)];
    }

    fn isValid(self: Map, x: isize, y: isize) bool {
        return self.at(x, y) != null;
    }

    fn placeObstacle(self: *Map, x: isize, y: isize) void {
        assert(self.at(x, y) == .empty);
        self.map.items[@intCast(x)].items[@intCast(y)] = .obstacle;
    }

    fn removeObstacle(self: *Map, x: isize, y: isize) void {
        assert(self.at(x, y) == .obstacle);
        self.map.items[@intCast(x)].items[@intCast(y)] = .empty;
    }
};

const Position = struct {
    x: isize,
    y: isize,
};

const Direction = struct {
    x: isize,
    y: isize,
    fn rotate(self: Direction) Direction {
        if (std.meta.eql(self, up)) return right;
        if (std.meta.eql(self, right)) return down;
        if (std.meta.eql(self, down)) return left;
        if (std.meta.eql(self, left)) return up;
        @panic("invalid direction");
    }
};

const up = Direction{ .x = -1, .y = 0 };
const down = Direction{ .x = 1, .y = 0 };
const right = Direction{ .x = 0, .y = 1 };
const left = Direction{ .x = 0, .y = -1 };

const PositionAndDirection = struct { pos: Position, dir: Direction };

/// Parses the input stream
fn parseInput(reader: std.io.AnyReader, alloc: std.mem.Allocator) !std.meta.Tuple(&.{ Map, Position }) {
    var map = Map.init(alloc);
    var row = std.ArrayList(Field).init(alloc);
    var gpos: ?Position = null;
    defer row.deinit();
    while (true) {
        const byte = reader.readByte() catch |err| {
            if (err == error.EndOfStream) {
                if (row.items.len > 0) {
                    try map.appendRow(row);
                    row = std.ArrayList(Field).init(alloc);
                }
                break;
            } else return err;
        };
        switch (byte) {
            '.' => try row.append(.empty),
            '#' => try row.append(.obstacle),
            '\n' => {
                try map.appendRow(row);
                row = std.ArrayList(Field).init(alloc);
            },
            '^' => {
                gpos = Position{
                    .x = map.xmax,
                    .y = @intCast(row.items.len),
                };
                try row.append(.empty);
            },
            else => {
                std.debug.print("invalid character: {d}\n", .{byte});
                return InputError.InvalidCharacter;
            },
        }
    }
    const guard_pos = gpos orelse return InputError.NoGuardian;

    return .{ map, guard_pos };
}

const example_input =
    \\....#.....
    \\.........#
    \\..........
    \\..#.......
    \\.......#..
    \\..........
    \\.#..^.....
    \\........#.
    \\#.........
    \\......#...
;

const t = std.testing;

fn parseExampleMap() !std.meta.Tuple(&.{ Map, Position }) {
    var stream = std.io.fixedBufferStream(example_input);
    const reader = stream.reader();
    const anyReader = reader.any();
    return parseInput(anyReader, t.allocator);
}

test parseInput {
    var map, const gpos = try parseExampleMap();
    defer map.deinit();
    try t.expectEqual(10, map.xmax);
    try t.expectEqual(10, map.ymax);
    try t.expectEqual(.empty, map.at(1, 3));
    try t.expectEqual(.obstacle, map.at(3, 2));
    try t.expectEqual(null, map.at(4, 10));
    try t.expectEqual(Position{ .x = 6, .y = 4 }, gpos);
}

/// Returns the number of visited fields
fn simulateGuardian(map: Map, gpos: Position, alloc: std.mem.Allocator) !std.AutoHashMap(Position, void) {
    var visited_pos = std.AutoHashMap(Position, void).init(alloc);
    errdefer visited_pos.deinit();
    var dir = up;
    var curr_pos = gpos;
    while (true) {
        try visited_pos.put(curr_pos, void{});
        curr_pos, dir = nextMove(map, curr_pos, dir) orelse break;
    }
    return visited_pos;
}

test "check example input from part 1" {
    var map, const gpos = try parseExampleMap();
    defer map.deinit();
    var positions = try simulateGuardian(map, gpos, t.allocator);
    defer positions.deinit();
    try t.expectEqual(41, positions.count());
}

/// Makes one move on the map
fn nextMove(map: Map, gpos: Position, dir: Direction) ?std.meta.Tuple(&.{ Position, Direction }) {
    const new_pos = Position{
        .x = gpos.x + dir.x,
        .y = gpos.y + dir.y,
    };
    const field = map.at(new_pos.x, new_pos.y) orelse return null;
    return switch (field) {
        .empty => .{ new_pos, dir },
        .obstacle => .{ gpos, dir.rotate() },
    };
}

/// Checks all possible positions to see if we can place an obstacle
fn tryPlacingObstacles(map: *Map, positions: std.AutoHashMap(Position, void), gpos: Position, alloc: std.mem.Allocator) !usize {
    var result: usize = 0;
    var pos_it = positions.keyIterator();
    while (pos_it.next()) |pos| {
        if (std.meta.eql(pos.*, gpos)) continue;
        map.placeObstacle(pos.x, pos.y);
        if (try guardianIsStuck(map.*, gpos, alloc)) result += 1;
        map.removeObstacle(pos.x, pos.y);
    }
    return result;
}

fn guardianIsStuck(map: Map, gpos: Position, alloc: std.mem.Allocator) !bool {
    var reached = std.AutoHashMap(PositionAndDirection, void).init(alloc);
    defer reached.deinit();
    var dir = up;
    var curr_pos = gpos;
    while (true) {
        const pd = PositionAndDirection{ .pos = curr_pos, .dir = dir };
        if (reached.contains(pd)) return true;
        try reached.putNoClobber(pd, void{});
        curr_pos, dir = nextMove(map, curr_pos, dir) orelse return false;
    }
    unreachable;
}

test "place obstacles" {
    var map, const gpos = try parseExampleMap();
    defer map.deinit();
    var positions = try simulateGuardian(map, gpos, t.allocator);
    defer positions.deinit();
    const valid_pos = try tryPlacingObstacles(&map, positions, gpos, t.allocator);
    try t.expectEqual(6, valid_pos);
}
