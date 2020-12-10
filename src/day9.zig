usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    return try findFirstInvalid(r, 25);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const invalid_number: usize = 1721308972; // number from the first part
    return findSpanWithSum(r, invalid_number, &arena.allocator);
}

fn findSpanWithSum(r: anytype, n: usize, a: *mem.Allocator) !usize {
    var span = std.ArrayList(usize).init(a);
    defer span.deinit();

    var sum: usize = 0;
    var buf: [10]u8 = undefined;
    while (sum != n) {
        while (sum < n) {
            const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.NotFound;
            const num = try fmt.parseUnsigned(usize, line, 10);
            try span.append(num);
            sum += num;
        }
        while (sum > n) {
            const num = span.orderedRemove(0);
            sum -= num;
        }
    }

    const slice = span.toOwnedSlice();
    defer a.free(slice);
    return sumOfMinAndMax(slice);
}

fn sumOfMinAndMax(slice: []usize) usize {
    var min: usize = std.math.maxInt(usize);
    var max: usize = 0;
    for (slice) |n| {
        if (n < min) {
            min = n;
        }
        if (n > max) {
            max = n;
        }
    }
    return min + max;
}

fn findFirstInvalid(r: anytype, comptime window_size: usize) !usize {
    var window: [window_size]usize = undefined;
    var window_index: usize = 0;

    try fillPreamble(r, &window);

    var buf: [10]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.NotFound;
        const num = try fmt.parseUnsigned(usize, line, 10);
        if (!isSumOf2(num, &window)) {
            return num;
        }
        window[window_index] = num;
        window_index = (window_index + 1) % window_size;
    }
}

fn fillPreamble(r: anytype, nums: []usize) !void {
    var buf: [20]u8 = undefined;
    for (nums) |_, i| {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.UnexpectedEndOfStream;
        const num = try fmt.parseUnsigned(usize, line, 10);
        nums[i] = num;
    }
}

fn isSumOf2(n: usize, nums: []usize) bool {
    for (nums[0 .. nums.len - 1]) |a, i| {
        for (nums[i + 1 ..]) |b| {
            if (n == a + b) {
                return true;
            }
        }
    }
    return false;
}

test "find first invalid" {
    const buf =
        \\35
        \\20
        \\15
        \\25
        \\47
        \\40
        \\62
        \\55
        \\65
        \\95
        \\102
        \\117
        \\150
        \\182
        \\127
        \\219
        \\299
        \\277
        \\309
        \\576
    ;

    const r = io.fixedBufferStream(buf).reader();
    const n = try findFirstInvalid(r, 5);
    expectEqual(@as(usize, 127), n);

    const r1 = io.fixedBufferStream(buf).reader();
    const sum = try findSpanWithSum(r1, n, testing.allocator);
    expectEqual(@as(usize, 62), sum);
}
