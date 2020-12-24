pub const std = @import("std");
pub const mem = std.mem;
pub const hash = std.hash;
pub const io = std.io;
pub const fmt = std.fmt;
pub const math = std.math;
pub const sort = std.sort;
pub const unicode = std.unicode;
pub const print = std.debug.print;
pub const assert = std.debug.assert;
pub const testing = std.testing;
pub const expect = testing.expect;
pub const expectError = testing.expectError;
pub const expectEqual = testing.expectEqual;
pub const expectEqualStrings = testing.expectEqualStrings;

pub const Allocator = mem.Allocator;
pub const ArrayList = std.ArrayList;
pub const TailQueue = std.TailQueue;
pub const StringHashMap = std.StringHashMap;
pub const AutoHashMap = std.AutoHashMap;

// Allocates 2-dimensional slice.
// Caller owns returned slice.
pub fn alloc2(comptime T: type, a: *Allocator, x_len: usize, y_len: usize) ![][]T {
    var slice = try a.alloc([]T, x_len);
    errdefer a.free(slice);
    for (slice) |*s| {
        s.* = try a.alloc(T, y_len);
        errdefer a.free(s.*);
    }
    return slice;
}

pub fn free2(comptime T: type, a: *Allocator, slice: [][]T) void {
    for (slice) |elem| {
        a.free(elem);
    }
    a.free(slice);
}