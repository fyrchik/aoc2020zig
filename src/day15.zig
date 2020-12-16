usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return run(r, 2020, &arena.allocator);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return run(r, 30000000, &arena.allocator);
}

// readNumbers reads comma-separated numbers from r.
// Caller owns returned slice.
fn readNumbers(r: anytype, a: *Allocator) ![]usize {
    var buf: [100]u8 = undefined;
    const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.EmptyInput;
    var numbers = std.ArrayList(usize).init(a);
    defer numbers.deinit();

    var iter = mem.split(line, ",");
    while (iter.next()) |val| {
        const n = try fmt.parseUnsigned(usize, val, 10);
        try numbers.append(n);
    }
    return numbers.toOwnedSlice();
}

// run runs game for a specified amount of turns given starting numbers
// and using provided cache. Cache must be big enough to hold all values
// up until last turn.
fn run(r: anytype, turns: usize, a: *Allocator) !usize {
    const start = try readNumbers(r, a);
    defer a.free(start);

    var cache = try a.alloc(usize, turns);
    defer a.free(cache);

    mem.set(usize, cache, 0);
    for (start[0 .. start.len - 1]) |n, i| {
        cache[n] = i + 1;
    }

    var i: usize = start.len;
    var last: usize = start[i - 1];
    while (i < turns) {
        const new_last = if (cache[last] == 0) 0 else i - cache[last];
        cache[last] = i;
        last = new_last;
        i += 1;
    }
    return last;
}

test "part 1" {
    var r = io.fixedBufferStream("0,3,6").reader();
    expectEqual(@as(usize, 436), try runPart1(r));

    r = io.fixedBufferStream("1,3,2").reader();
    expectEqual(@as(usize, 1), try runPart1(r));

    r = io.fixedBufferStream("2,1,3").reader();
    expectEqual(@as(usize, 10), try runPart1(r));

    r = io.fixedBufferStream("1,2,3").reader();
    expectEqual(@as(usize, 27), try runPart1(r));

    r = io.fixedBufferStream("2,3,1").reader();
    expectEqual(@as(usize, 78), try runPart1(r));

    r = io.fixedBufferStream("3,2,1").reader();
    expectEqual(@as(usize, 438), try runPart1(r));

    r = io.fixedBufferStream("3,1,2").reader();
    expectEqual(@as(usize, 1836), try runPart1(r));
}

test "part 2" {
    var r = io.fixedBufferStream("0,3,6").reader();
    expectEqual(@as(usize, 175594), try runPart2(r));

    r = io.fixedBufferStream("1,3,2").reader();
    expectEqual(@as(usize, 2578), try runPart2(r));

    r = io.fixedBufferStream("2,1,3").reader();
    expectEqual(@as(usize, 3544142), try runPart2(r));

    r = io.fixedBufferStream("1,2,3").reader();
    expectEqual(@as(usize, 261214), try runPart2(r));

    r = io.fixedBufferStream("2,3,1").reader();
    expectEqual(@as(usize, 6895259), try runPart2(r));

    r = io.fixedBufferStream("3,2,1").reader();
    expectEqual(@as(usize, 18), try runPart2(r));

    r = io.fixedBufferStream("3,1,2").reader();
    expectEqual(@as(usize, 362), try runPart2(r));
}
