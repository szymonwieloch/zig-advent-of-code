const std = @import("std");
const t = std.testing;

pub const Allocator = std.heap.GeneralPurposeAllocator(.{});

pub fn checkGpa(alloc: *Allocator) void {
    const deinit_status = alloc.deinit();
    if (deinit_status != .ok) {
        std.debug.print("Failed to deinitialize the allocator: {}\n", .{deinit_status});
    }
}

/// An iterator over lines in a generic input stream.
const LineIterator = struct {
    line: std.Io.Writer.Allocating,
    reader: *std.Io.Reader,

    pub fn next(self: *LineIterator) ![]const u8 {
        self.line.clearRetainingCapacity();
        _ = self.reader.streamDelimiter(&self.line.writer, '\n') catch |err| {
            if (err != error.EndOfStream) return err;
            if (self.line.written().len > 0) return self.line.written() else return error.EndOfStream;
        };
        _ = self.reader.takeByte() catch |err| {
            if (err != error.EndOfStream) return err;
        };
        return self.line.written();
    }

    pub fn deinit(self: *LineIterator) void {
        self.line.deinit();
    }
};

/// Splits input into lines.
pub fn lineIterator(reader: *std.Io.Reader, alloc: std.mem.Allocator) LineIterator {
    return LineIterator{
        .line = std.io.Writer.Allocating.init(alloc),
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
    var buffer: [1024]u8 = undefined;
    var new_reader = reader.adaptToNewApi(&buffer);
    var line_it = lineIterator(&new_reader.new_interface, t.allocator);
    defer line_it.deinit();
    try t.expectEqualStrings("abc", try line_it.next());
    try t.expectEqualStrings("def", try line_it.next());
    try t.expectEqualStrings("ghi", try line_it.next());
    try t.expectError(error.EndOfStream, line_it.next());
}

/// Common procedure of parsing input file into a structure.
pub fn parseFile(comptime Input: type, path: []const u8, alloc: std.mem.Allocator, comptime parser: fn (*std.io.Reader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);
    return parser(&reader.interface, alloc);
}

/// Common procedure of parsing example input into a structure.
/// To be used only in tests.
pub fn parseExample(comptime Input: type, input: []const u8, comptime parser: fn (*std.io.Reader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var stream = std.io.fixedBufferStream(input);
    const reader = stream.reader();
    var buffer: [1024]u8 = undefined;
    var new_reader = reader.adaptToNewApi(&buffer);
    return parser(&new_reader.new_interface, t.allocator);
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

        pub const empty: Self = .{
            .data = std.ArrayList(Row).empty,
            .xmax = 0,
            .ymax = 0,
        };

        pub fn isValid(self: Self, x: isize, y: isize) bool {
            return x >= 0 and x < self.xmax and y >= 0 and y < self.ymax;
        }

        pub fn at(self: Self, x: isize, y: isize) ?T {
            return if (self.isValid(x, y)) self.data.items[@intCast(x)].items[@intCast(y)] else null;
        }

        pub fn atPos(self: Self, pos: Position) ?T {
            return self.at(pos.x, pos.y);
        }

        pub fn appendRow(self: *Self, alloc: std.mem.Allocator, row: Row) !void {
            if (self.data.items.len > 0) {
                if (row.items.len != self.ymax) return InputError.RowLengthMismatch;
            } else {
                self.ymax = @intCast(row.items.len);
            }
            try self.data.append(alloc, row);
            self.xmax = @intCast(self.data.items.len);
        }

        pub fn xSize(self: Self) isize {
            return self.xmax;
        }

        pub fn ySize(self: Self) isize {
            return self.ymax;
        }

        pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            for (self.data.items) |*row| {
                row.deinit(alloc);
            }
            self.data.deinit(alloc);
        }
    };
}

test Matrix {
    const M = Matrix(u8);
    var m = M.empty;
    defer m.deinit(t.allocator);
    var row1 = M.Row.empty;
    try row1.appendSlice(t.allocator, "abc");
    var row2 = M.Row.empty;
    try row2.appendSlice(t.allocator, "def");
    var row3 = M.Row.empty;
    try row3.appendSlice(t.allocator, "ghi");
    try m.appendRow(t.allocator, row1);
    try m.appendRow(t.allocator, row2);
    try m.appendRow(t.allocator, row3);
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
