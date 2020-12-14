usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buf: [10]u8 = undefined;
    const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidFormat;
    const start = try fmt.parseUnsigned(usize, line, 10);
    const ids = try parseIDs(r, &arena.allocator);

    var minWait: usize = math.maxInt(usize);
    var minID: usize = undefined;
    for (ids) |id| {
        const m = start - @mod(start, id.id);
        const waitFor = if (m < start) m + id.id - start else m - start;
        if (waitFor < minWait) {
            minID = id.id;
            minWait = waitFor;
        }
    }
    return minWait * minID;
}

pub fn runPart2(r: anytype) !u128 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buf: [10]u8 = undefined;
    _ = try r.readUntilDelimiterOrEof(&buf, '\n');
    var ids = try parseIDs(r, &arena.allocator);

    sort.sort(Id, ids, {}, idCmpMoreThan);
    var step: u128 = @as(u128, ids[0].id);

    const m = @mod(ids[0].pos, ids[0].id);
    var curr: u128 = if (m == 0) m else ids[0].id - m;
    for (ids[1..]) |id, i| {
        while (@mod(curr + id.pos, id.id) != 0) {
            curr += step;
        }
        step = lcm(u128, step, id.id);
    }
    return curr;
}

fn lcm(comptime T: type, a: T, b: T) T {
    return a * b / gcd(u128, a, b);
}

fn gcd(comptime T: type, a: T, b: T) T {
    if (b == 0) {
        return a;
    }
    return gcd(T, b, @mod(a, b));
}

fn idCmpMoreThan(context: void, a: Id, b: Id) bool {
    return a.id > b.id;
}

const Id = struct {
    id: usize,
    pos: usize,
};

// parseIDs returns list of bus ID's skipping unknown.
// Caller owns returned slice.
fn parseIDs(r: anytype, a: *Allocator) ![]Id {
    var lst = ArrayList(Id).init(a);
    var buf: [10]u8 = undefined;
    var i: usize = 0;
    while (true) {
        var line = (try r.readUntilDelimiterOrEof(&buf, ',')) orelse return lst.toOwnedSlice();
        i += 1;
        if (mem.eql(u8, "x", line)) {
            continue;
        }
        if (mem.endsWith(u8, line, "\n")) {
            line = line[0 .. line.len - 1];
        }
        const id = try fmt.parseUnsigned(usize, line, 10);
        try lst.append(Id{ .id = id, .pos = i - 1 });
    }
}

test "part 1" {
    const table = "939\n7,13,x,x,59,x,31,19";
    var r = io.fixedBufferStream(table).reader();
    expectEqual(@as(usize, 295), try runPart1(r));
}

test "part 2" {
    var table: []const u8 = "939\n7,13,x,x,59,x,31,19";
    var r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 1068781), try runPart2(r));

    table = "939\n1,x,x,x,x,x,x,3";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 2), try runPart2(r));

    table = "939\n17,x,13,19";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 3417), try runPart2(r));

    table = "939\n67,7,59,61";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 754018), try runPart2(r));

    table = "939\n67,x,7,59,61";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 779210), try runPart2(r));

    table = "939\n67,7,x,59,61";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 1261476), try runPart2(r));

    table = "939\n1789,37,47,1889";
    r = io.fixedBufferStream(table).reader();
    expectEqual(@as(u128, 1202161486), try runPart2(r));
}
