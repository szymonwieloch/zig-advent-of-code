//! Solution tot the challenge: https://adventofcode.com/2024/day/12

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

const Field = u8;
const Matrix = common.Matrix(Field);
const Position = common.Position;
const PositionSet = std.AutoHashMap(Position, void);
const FencePosition = struct {
    pos: Position,
    horizontal: bool,
};
const FencePositionSet = std.AutoHashMap(FencePosition, void);

const directions = [_]common.Vector{
    common.Vector{ .x = 0, .y = -1 }, // up
    common.Vector{ .x = 1, .y = 0 }, // right
    common.Vector{ .x = 0, .y = 1 }, // down
    common.Vector{ .x = -1, .y = 0 }, // left
};

pub fn main() !void {
    var gpa = common.Allocator{};
    defer common.checkGpa(&gpa);
    const alloc = gpa.allocator();
    var input = try common.parseFile(Matrix, "12.txt", alloc, parseInput);
    defer input.deinit(alloc);
    var p1 = Part1Calculation{ .total_price = 0 };
    try splitIntoRegions(input, alloc, &p1);
    std.debug.print("Total price: {}\n", .{p1.total_price});
    var p2 = Part2Calculation{ .total_price = 0, .alloc = alloc };
    try splitIntoRegions(input, alloc, &p2);
    std.debug.print("Total price with a discount: {}\n", .{p2.total_price});
}

fn parseInput(reader: *std.io.Reader, alloc: std.mem.Allocator) !Matrix {
    var result = Matrix.empty;
    errdefer result.deinit(alloc);
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        var row = Matrix.Row.empty;
        errdefer row.deinit(alloc);
        try row.appendSlice(alloc, line);
        try result.appendRow(alloc, row);
    } else |err| {
        if (err != error.EndOfStream) return err;
    }
    return result;
}

const example_input =
    \\RRRRIICCFF
    \\RRRRIICCCF
    \\VVRRRCCFFF
    \\VVRCCCJFFF
    \\VVVVCJJCFE
    \\VVIVCCJJEE
    \\VVIIICJJEE
    \\MIIIIIJJEE
    \\MIIISIJEEE
    \\MMMISSJEEE
;

test "parse example input" {
    var input = try common.parseExample(Matrix, example_input, parseInput);
    defer input.deinit(t.allocator);
    try t.expectEqual(10, input.xSize());
    try t.expectEqual(10, input.ySize());
    try t.expectEqual('R', input.at(0, 0));
    try t.expectEqual('E', input.at(9, 9));
    try t.expectEqual('F', input.at(0, 9));
    try t.expectEqual('M', input.at(9, 0));
}

const Part1Calculation = struct {
    total_price: usize,
    fn onRegion(self: *Part1Calculation, region: PositionSet) !void {
        self.total_price += price(region);
    }
};

const Part2Calculation = struct {
    total_price: usize,
    alloc: std.mem.Allocator,
    fn onRegion(self: *Part2Calculation, region: PositionSet) !void {
        self.total_price += try price2(region, self.alloc);
    }
};

fn splitIntoRegions(matrix: Matrix, alloc: std.mem.Allocator, region_handler: anytype) !void {
    var visited = PositionSet.init(alloc);
    defer visited.deinit();
    for (0..@intCast(matrix.xSize())) |idx| {
        for (0..@intCast(matrix.ySize())) |idy| {
            const pos = Position{ .x = @intCast(idx), .y = @intCast(idy) };
            if (visited.contains(pos)) continue;
            var region = try findRegion(matrix, pos, alloc);
            defer region.deinit();
            try region_handler.onRegion(region);
            var key_it = region.keyIterator();
            while (key_it.next()) |key| {
                try visited.put(key.*, {});
            }
        }
    }
}

/// Finds a region in the matrix starting from the given position.
fn findRegion(matrix: Matrix, pos: Position, alloc: std.mem.Allocator) !PositionSet {
    var region = PositionSet.init(alloc);
    errdefer region.deinit();
    try region.put(pos, {});
    const ch = matrix.atPos(pos) orelse unreachable;
    var queue = std.ArrayList(Position).empty;
    defer queue.deinit(alloc);
    try queue.append(alloc, pos);
    while (queue.items.len > 0) {
        const curr_pos = queue.pop() orelse unreachable;
        for (directions) |dir| {
            const new_pos = curr_pos.move(dir);
            if (matrix.atPos(new_pos) == ch and !region.contains(new_pos)) {
                try region.put(new_pos, {});
                try queue.append(alloc, new_pos);
            }
        }
    }
    return region;
}

/// Calculates the price of a region.
fn price(region: PositionSet) usize {
    var perimeter: usize = 0;
    var key_it = region.keyIterator();
    while (key_it.next()) |pos| {
        for (directions) |dir| {
            const neighbor = pos.move(dir);
            if (!region.contains(neighbor)) {
                perimeter += 1;
            }
        }
    }
    return perimeter * region.count();
}

/// Calculates the price of a region using its fences - part 2.
fn price2(region: PositionSet, alloc: std.mem.Allocator) !usize {
    var fences = try regionFences(region, alloc);
    defer fences.deinit();
    return sides(fences) * region.count();
}

fn regionFences(region: PositionSet, alloc: std.mem.Allocator) !FencePositionSet {
    var fences = FencePositionSet.init(alloc);
    errdefer fences.deinit();
    var key_it = region.keyIterator();
    while (key_it.next()) |pos| {
        for (directions) |dir| {
            const neighbor = pos.move(dir);
            if (region.contains(neighbor)) continue;
            try fences.put(fenceBetween(pos.*, neighbor), {});
        }
    }
    return fences;
}

fn fenceBetween(pos1: Position, pos2: Position) FencePosition {
    if (pos1.x == pos2.x) {
        assert(common.abs(isize, pos1.y - pos2.y) == 1);
        const pos = if (pos1.y < pos2.y) pos1 else pos2;
        return FencePosition{ .pos = pos, .horizontal = false };
    } else if (pos1.y == pos2.y) {
        assert(common.abs(isize, pos1.x - pos2.x) == 1);
        const pos = if (pos1.x < pos2.x) pos1 else pos2;
        return FencePosition{ .pos = pos, .horizontal = true };
    } else {
        unreachable;
    }
}

fn sides(fences: FencePositionSet) usize {
    _ = fences;
    const result: usize = 0;
    // var key_it = fences.keyIterator();
    // while (key_it.next()) |fence| {
    //     const pos = fence.pos;
    //     const horizontal = fence.horizontal;
    //     const adj1 = if (horizontal) FencePosition{ .pos = Position{ .x = pos.x - 1, .y = pos.y }, .horizontal = true }
    //                  else FencePosition{ .pos = Position{ .x = pos.x, .y = pos.y - 1 }, .horizontal = false };
    //     const adj2 = if (horizontal) FencePosition{ .pos = Position{ .x = pos.x + 1, .y = pos.y }, .horizontal = true }
    //                  else FencePosition{ .pos = Position{ .x = pos.x, .y = pos.y + 1 }, .horizontal = false };
    //     if (!fences.contains(adj1)) result += 1;
    //     if (!fences.contains(adj2)) result += 1;
    // }
    return result;
}

test "find region and check its price" {
    var input = try common.parseExample(Matrix, example_input, parseInput);
    defer input.deinit(t.allocator);
    var reg1 = try findRegion(input, .{ .x = 9, .y = 1 }, t.allocator);
    defer reg1.deinit();
    try t.expectEqual(5, reg1.count());
    try t.expectEqual(60, price(reg1));
    var reg2 = try findRegion(input, .{ .x = 0, .y = 0 }, t.allocator);
    defer reg2.deinit();
    try t.expectEqual(12, reg2.count());
    try t.expectEqual(216, price(reg2));
}

test "calculate total cost of the example map" {
    var input = try common.parseExample(Matrix, example_input, parseInput);
    defer input.deinit(t.allocator);
    var p1: Part1Calculation = Part1Calculation{ .total_price = 0 };
    try splitIntoRegions(input, t.allocator, &p1);
    try t.expectEqual(1930, p1.total_price);
}
