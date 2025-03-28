//! Solution tot the challenge: https://adventofcode.com/2024/day/12

const std = @import("std");
const common = @import("common.zig");
const assert = std.debug.assert;
const t = std.testing;

const Field = u8;
const Matrix = common.Matrix(Field);
const Position = common.Position;
const PositionSet = std.AutoHashMap(Position, void);

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
    const input = try common.parseFile(Matrix, "12.txt", alloc, parseInput);
    defer input.deinit();
    const total_price = try splitIntoRegions(input, alloc);
    std.debug.print("Total price: {d}\n", .{total_price});
}

fn parseInput(reader: std.io.AnyReader, alloc: std.mem.Allocator) !Matrix {
    var result = Matrix.init(alloc);
    errdefer result.deinit();
    var line_it = common.lineIterator(reader, alloc);
    defer line_it.deinit();
    while (line_it.next()) |line| {
        var row = Matrix.Row.init(alloc);
        errdefer row.deinit();
        try row.appendSlice(line);
        try result.appendRow(row);
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
    defer input.deinit();
    try t.expectEqual(10, input.xSize());
    try t.expectEqual(10, input.ySize());
    try t.expectEqual('R', input.at(0, 0));
    try t.expectEqual('E', input.at(9, 9));
    try t.expectEqual('F', input.at(0, 9));
    try t.expectEqual('M', input.at(9, 0));
}

fn splitIntoRegions(matrix: Matrix, alloc: std.mem.Allocator) !usize {
    var visited = PositionSet.init(alloc);
    defer visited.deinit();
    var total_price: usize = 0;
    for (0..@intCast(matrix.xSize())) |idx| {
        for (0..@intCast(matrix.ySize())) |idy| {
            const pos = Position{ .x = @intCast(idx), .y = @intCast(idy) };
            if (visited.contains(pos)) continue;
            var region = try findRegion(matrix, pos, alloc);
            defer region.deinit();
            total_price += price(region);
            var key_it = region.keyIterator();
            while (key_it.next()) |key| {
                try visited.put(key.*, {});
            }
        }
    }
    return total_price;
}

/// Finds a region in the matrix starting from the given position.
fn findRegion(matrix: Matrix, pos: Position, alloc: std.mem.Allocator) !PositionSet {
    var region = PositionSet.init(alloc);
    errdefer region.deinit();
    try region.put(pos, {});
    const ch = matrix.atPos(pos) orelse unreachable;
    var queue = std.ArrayList(Position).init(alloc);
    defer queue.deinit();
    try queue.append(pos);
    while (queue.items.len > 0) {
        const curr_pos = queue.pop() orelse unreachable;
        for (directions) |dir| {
            const new_pos = curr_pos.move(dir);
            if (matrix.atPos(new_pos) == ch and !region.contains(new_pos)) {
                try region.put(new_pos, {});
                try queue.append(new_pos);
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

test "find region and check its price" {
    var input = try common.parseExample(Matrix, example_input, parseInput);
    defer input.deinit();
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
    defer input.deinit();
    const total_price = try splitIntoRegions(input, t.allocator);
    try t.expectEqual(1930, total_price);
}
