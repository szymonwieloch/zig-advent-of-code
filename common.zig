const std = @import("std");

pub const Allocator = std.heap.GeneralPurposeAllocator(.{});

pub fn checkGpa(alloc: *Allocator) void {
    const deinit_status = alloc.deinit();
    if (deinit_status != .ok) {
        std.debug.print("Failed to deinitialize the allocator: {}\n", .{deinit_status});
    }
}
