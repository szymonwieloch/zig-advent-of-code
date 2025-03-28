const std = @import("std");
const t = std.testing;

pub const Allocator = std.heap.GeneralPurposeAllocator(.{});

pub fn checkGpa(alloc: *Allocator) void {
    const deinit_status = alloc.deinit();
    if (deinit_status != .ok) {
        std.debug.print("Failed to deinitialize the allocator: {}\n", .{deinit_status});
    }
}

const LineIterator = struct {
    line: std.ArrayList(u8),
    reader: std.io.AnyReader,

    pub fn next(self: *LineIterator) ![]const u8 {
        self.line.clearRetainingCapacity();
        self.reader.streamUntilDelimiter(self.line.writer(), '\n', null) catch |err| {
            if (err != error.EndOfStream) return err;
            if (self.line.items.len > 0) return self.line.items else return error.EndOfStream;
        };
        return self.line.items;
    }

    pub fn deinit(self: *LineIterator) void {
        self.line.deinit();
    }
};

/// Splits input into lines.
pub fn lineIterator(reader: std.io.AnyReader, alloc: std.mem.Allocator) LineIterator {
    return LineIterator{
        .line = std.ArrayList(u8).init(alloc),
        .reader = reader,
    };
}

test lineIterator {
    const str =
        \\abc
        \\def
        \\ghi
    ;
    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();
    const anyReader = reader.any();
    var line_it = lineIterator(anyReader, t.allocator);
    defer line_it.deinit();
    try t.expectEqualStrings("abc", try line_it.next());
    try t.expectEqualStrings("def", try line_it.next());
    try t.expectEqualStrings("ghi", try line_it.next());
    try t.expectError(error.EndOfStream, line_it.next());
}

/// Common procedure of parsing input file into a structure.
pub fn parseFile(comptime Input: type, path: []const u8, alloc: std.mem.Allocator, comptime parser: fn (std.io.AnyReader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader().any();
    return parser(in_stream, alloc);
}

/// Common procedure of parsing example input into a structure.
/// To be used only in tests.
pub fn parseExample(comptime Input: type, input: []const u8, comptime parser: fn (std.io.AnyReader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var stream = std.io.fixedBufferStream(input);
    const reader = stream.reader();
    const anyReader = reader.any();
    return parser(anyReader, t.allocator);
}

pub const InputError = error{ RowLengthMismatch, InvalidCharacter };

pub const Position = struct {
    x: isize,
    y: isize,
    pub fn move(self: Position, vec: Vector) Position {
        return Position{ .x = self.x + vec.x, .y = self.y + vec.y };
    }
};

pub const Vector = struct {
    x: isize,
    y: isize,
};

/// Creates a 2D matrix of type T.
pub fn Matrix(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Row = std.ArrayList(T);

        data: std.ArrayList(Row),
        xmax: isize,
        ymax: isize,

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self{ .data = std.ArrayList(Row).init(alloc), .xmax = 0, .ymax = 0 };
        }

        pub fn isValid(self: Self, x: isize, y: isize) bool {
            return x >= 0 and x < self.xmax and y >= 0 and y < self.ymax;
        }

        pub fn at(self: Self, x: isize, y: isize) ?T {
            return if (self.isValid(x, y)) self.data.items[@intCast(x)].items[@intCast(y)] else null;
        }

        pub fn atPos(self: Self, pos: Position) ?T {
            return self.at(pos.x, pos.y);
        }

        pub fn appendRow(self: *Self, row: Row) !void {
            if (self.data.items.len > 0) {
                if (row.items.len != self.ymax) return InputError.RowLengthMismatch;
            } else {
                self.ymax = @intCast(row.items.len);
            }
            try self.data.append(row);
            self.xmax = @intCast(self.data.items.len);
        }

        pub fn xSize(self: Self) isize {
            return self.xmax;
        }

        pub fn ySize(self: Self) isize {
            return self.ymax;
        }

        pub fn deinit(self: Self) void {
            for (self.data.items) |row| {
                row.deinit();
            }
            self.data.deinit();
        }
    };
}

test Matrix {
    const M = Matrix(u8);
    var m = M.init(t.allocator);
    defer m.deinit();
    var row1 = M.Row.init(t.allocator);
    try row1.appendSlice("abc");
    var row2 = M.Row.init(t.allocator);
    try row2.appendSlice("def");
    var row3 = M.Row.init(t.allocator);
    try row3.appendSlice("ghi");
    try m.appendRow(row1);
    try m.appendRow(row2);
    try m.appendRow(row3);
    try t.expectEqual('a', m.at(0, 0));
    try t.expectEqual('b', m.at(0, 1));
    try t.expectEqual('c', m.at(0, 2));
    try t.expectEqual('d', m.at(1, 0));
    try t.expectEqual('e', m.at(1, 1));
    try t.expectEqual('f', m.at(1, 2));
    try t.expectEqual('g', m.at(2, 0));
    try t.expectEqual('h', m.at(2, 1));
    try t.expectEqual('i', m.at(2, 2));
    try t.expectEqual(null, m.at(3, 0));
    try t.expectEqual(null, m.at(0, 3));
    try t.expectEqual(false, m.isValid(-1, 0));
    try t.expectEqual(false, m.isValid(0, -1));
    try t.expectEqual(false, m.isValid(3, 0));
    try t.expectEqual(false, m.isValid(0, 3));
    try t.expectEqual(3, m.xSize());
    try t.expectEqual(3, m.ySize());
}
