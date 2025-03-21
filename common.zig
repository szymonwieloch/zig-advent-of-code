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
pub fn parseFile(comptime Input: type, path: []const u8, alloc: std.mem.Allocator, parser: fn (std.io.AnyReader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader().any();
    return parser(in_stream, alloc);
}

/// Common procedure of parsing example input into a structure.
/// To be used only in tests.
pub fn parseExample(comptime Input: type, input: []const u8, parser: fn (std.io.AnyReader, std.mem.Allocator) anyerror!Input) anyerror!Input {
    var stream = std.io.fixedBufferStream(input);
    const reader = stream.reader();
    const anyReader = reader.any();
    return parser(anyReader, t.allocator);
}
