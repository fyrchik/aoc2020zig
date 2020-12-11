usingnamespace @import("util.zig");

const Seat = enum {
    Empty,
    Occupied,
    Floor,
};

pub fn runPart1(r: anytype) !usize {
    return run(r, seatNextState);
}

pub fn runPart2(r: anytype) !usize {
    return run(r, seatNextState2);
}

fn run(r: anytype, f: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const a = &arena.allocator;
    var prev = try readTable(r, a);
    var curr = try a.alloc([]Seat, prev.len);
    for (curr) |*row, i| {
        row.* = try a.alloc(Seat, prev[i].len);
    }

    while (step(prev, curr, f)) {
        var t = prev;
        prev = curr;
        curr = t;
    }

    return countOccupied(curr);
}

// Helper debug function which returns current state of all seats as a string.
// Caller owns returned slice;
fn seatsToString(ss: [][]Seat, a: *Allocator) ![]const u8 {
    var str = ArrayList(u8).init(a);
    defer str.deinit();

    for (ss) |row| {
        for (row) |s| {
            switch (s) {
                .Empty => try str.append('L'),
                .Occupied => try str.append('#'),
                .Floor => try str.append('.'),
            }
        }
        try str.append('\n');
    }

    return str.toOwnedSlice();
}

fn countOccupied(ss: [][]Seat) usize {
    var count: usize = 0;
    for (ss) |row| {
        for (row) |s| {
            if (s == .Occupied) {
                count += 1;
            }
        }
    }
    return count;
}

// Performs a single step arrival and returns true if any seat has changed.
fn step(prev: [][]Seat, curr: [][]Seat, f: anytype) bool {
    var changed: bool = false;
    for (curr) |row, rn| {
        for (row) |s, sn| {
            const next = f(prev, rn, sn);
            changed = changed or (s != next);
            row[sn] = next;
        }
    }
    return changed;
}

inline fn seatNextState(ss: [][]Seat, row_no: usize, seat_no: usize) Seat {
    const s = ss[row_no][seat_no];
    if (s == .Floor) {
        return .Floor;
    }

    var count_empty: usize = 0;
    var count_occupied: usize = 0;
    if (row_no > 0) {
        count_occupied += addRow(ss, row_no - 1, seat_no, true);
    }
    count_occupied += addRow(ss, row_no, seat_no, false);
    if ((ss.len > 2) and (row_no < ss.len - 1)) {
        count_occupied += addRow(ss, row_no + 1, seat_no, true);
    }

    if (count_occupied >= 4) {
        return .Empty;
    }
    if (count_occupied == 0) {
        return .Occupied;
    }
    return s;
}

const Direction = struct {
    x: isize,
    y: isize,
};

fn seatNextState2(ss: [][]Seat, row_no: usize, seat_no: usize) Seat {
    if (ss[row_no][seat_no] == .Floor) {
        return .Floor;
    }

    const dir = [_]Direction{
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = 0 },
        .{ .x = -1, .y = 1 },
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = -1 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
    };
    var count_occupied: usize = 0;
    for (dir) |d| {
        var rn: isize = @intCast(isize, row_no);
        var sn: isize = @intCast(isize, seat_no);
        while (0 <= rn + d.x and rn + d.x < ss.len and 0 <= sn + d.y and sn + d.y < ss[@intCast(usize, rn + d.x)].len) {
            rn += d.x;
            sn += d.y;

            const s = ss[@intCast(usize, rn)][@intCast(usize, sn)];
            if (s != .Floor) {
                count_occupied += addSingle(s);
                break;
            }
        }
    }

    if (count_occupied >= 5) {
        return .Empty;
    }
    if (count_occupied == 0) {
        return .Occupied;
    }
    return ss[row_no][seat_no];
}

inline fn addRow(ss: [][]Seat, row_no: usize, seat_no: usize, count_middle: bool) usize {
    var count_occupied: usize = 0;
    const r = ss[row_no];
    if (seat_no > 0) {
        count_occupied += addSingle(r[seat_no - 1]);
    }
    if (count_middle) {
        count_occupied += addSingle(r[seat_no]);
    }
    if (seat_no < r.len - 1) {
        count_occupied += addSingle(r[seat_no + 1]);
    }
    return count_occupied;
}

inline fn addSingle(s: Seat) usize {
    return if (s == .Occupied) 1 else 0;
}

// Reads seat locations from r.
// Caller owns returned slice.
fn readTable(r: anytype, a: *Allocator) ![][]Seat {
    var lst = ArrayList([]Seat).init(a);
    defer lst.deinit();

    var buf: [100]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return lst.toOwnedSlice();
        var seats = try a.alloc(Seat, line.len);
        errdefer a.free(seats);

        lineToArray(line, seats);
        try lst.append(seats);
    }
}

// Transforms s into array of seats.
fn lineToArray(s: []const u8, seats: []Seat) void {
    for (s) |c, i| {
        switch (c) {
            'L' => seats[i] = .Empty,
            '.' => seats[i] = .Floor,
            // Initially there are no occupied seats.
            else => unreachable,
        }
    }
}

test "part 1 and 2" {
    const buf =
        \\L.LL.LL.LL
        \\LLLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLLL
        \\L.LLLLLL.L
        \\L.LLLLL.LL
    ;
    var r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 37), try runPart1(r));

    r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 26), try runPart2(r));
}
