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
