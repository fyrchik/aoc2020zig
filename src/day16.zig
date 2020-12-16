usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const ts = try parseInput(r, &arena.allocator);
    var sum: usize = 0;
    for (ts.tickets) |t| {
        sum += validateTicket(ts.policy, t);
    }
    return sum;
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const ts = try parseInput(r, &arena.allocator);
    var valid_tickets = ArrayList([]usize).init(&arena.allocator);
    defer valid_tickets.deinit();

    for (ts.tickets) |t| {
        if (0 == validateTicket(ts.policy, t)) {
            try valid_tickets.append(t);
        }
    }

    const valid = valid_tickets.toOwnedSlice();
    var can_be = try arena.allocator.alloc([]bool, ts.policy.len);
    for (ts.policy) |f, i| {
        can_be[i] = try arena.allocator.alloc(bool, ts.policy.len);
        mem.set(bool, can_be[i], true);

        for (valid) |t| {
            markValid(can_be[i], f, t);
        }
    }

    const field_numbers = try calcFieldNumbers(can_be, &arena.allocator);
    var prod: usize = 1;
    for (ts.policy) |v, i| {
        if (v.is_departure) {
            prod *= ts.my[field_numbers[i]];
        }
    }
    return prod;
}

fn markValid(can_be: []bool, policy: Field, ticket: []usize) void {
    assert(can_be.len == ticket.len);

    for (ticket) |v, j| {
        can_be[j] = can_be[j] and policy.isValid(v);
    }
}

// Caller owns returned slice.
fn calcFieldNumbers(m: [][]bool, a: *Allocator) ![]usize {
    var field_numbers = try a.alloc(usize, m.len);
    mem.set(usize, field_numbers, m.len);

    var taken = try a.alloc(bool, m.len);
    defer a.free(taken);
    mem.set(bool, taken, false);

    if (!calcAux(m, field_numbers, taken, 0)) {
        return error.Impossible;
    }
    return field_numbers;
}

fn calcAux(m: [][]bool, field_numbers: []usize, taken: []bool, count: usize) bool {
    if (count == m.len) {
        return true;
    }

    // Find and set line which has a single possibility.
    var min: usize = m.len;
    var min_index: usize = m.len;
    for (m) |vec, i| {
        if (field_numbers[i] != m.len) {
            continue;
        }

        var cnt: usize = 0;
        for (vec) |v, j| {
            cnt += @boolToInt(v and !taken[j]);
        }
        if (cnt < min) {
            min = cnt;
            min_index = i;
        }
    }

    for (m[min_index]) |v, j| {
        if (!v or taken[j]) {
            continue;
        }
        taken[j] = true;
        field_numbers[min_index] = j;
        if (calcAux(m, field_numbers, taken, count + 1)) {
            return true;
        }
        field_numbers[min_index] = m.len;
        taken[j] = false;
    }
    return false;
}

const Range = struct {
    min: usize,
    max: usize,
};

const Field = struct {
    const Self = @This();

    r1: Range,
    r2: Range,
    is_departure: bool,

    fn isValid(s: Self, v: usize) bool {
        return ((s.r1.min <= v and v <= s.r1.max) or (s.r2.min <= v and v <= s.r2.max));
    }
};

const Tickets = struct {
    policy: []Field,
    my: []usize,
    tickets: [][]usize,
};

// validates ticket and returns sum of invalid fields.
fn validateTicket(p: []Field, t: []usize) usize {
    assert(p.len == t.len);

    var sum: usize = 0;
    loop: for (t) |v, i| {
        for (p) |f| {
            if (f.isValid(v)) {
                continue :loop;
            }
        }
        sum += v;
    }
    return sum;
}

fn parseInput(r: anytype, a: *Allocator) !Tickets {
    var policy = ArrayList(Field).init(a);
    defer policy.deinit();

    var buf: [100]u8 = undefined;
    var field_no: usize = 0;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
        if (line.len == 0) {
            break;
        }

        const start = mem.indexOf(u8, line, ": ") orelse return error.InvalidInput;
        var iter = mem.split(line[start + 2 ..], " ");
        const s1 = iter.next() orelse return error.InvalidInput;
        _ = iter.next();
        const s2 = iter.next() orelse return error.InvalidInput;
        try policy.append(Field{
            .r1 = try parseRange(s1),
            .r2 = try parseRange(s2),
            .is_departure = mem.startsWith(u8, line, "departure"),
        });

        field_no += 1;
    }

    _ = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
    const my_line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
    const my = try parseTicket(my_line, a);
    _ = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
    _ = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;

    var ts = ArrayList([]usize).init(a);
    defer ts.deinit();

    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        const t = try parseTicket(line, a);
        try ts.append(t);
    }

    return Tickets{
        .policy = policy.toOwnedSlice(),
        .my = my,
        .tickets = ts.toOwnedSlice(),
    };
}

// Caller owns returned slice.
fn parseTicket(s: []const u8, a: *Allocator) ![]usize {
    var fs = ArrayList(usize).init(a);
    defer fs.deinit();

    var iter = mem.split(s, ",");
    while (iter.next()) |sn| {
        const n = try fmt.parseUnsigned(usize, sn, 10);
        try fs.append(n);
    }
    return fs.toOwnedSlice();
}

fn parseRange(s: []const u8) !Range {
    const ind = mem.indexOf(u8, s, "-") orelse return error.InvalidRange;
    const a = try fmt.parseUnsigned(usize, s[0..ind], 10);
    const b = try fmt.parseUnsigned(usize, s[ind + 1 ..], 10);
    return Range{
        .min = a,
        .max = b,
    };
}

test "part 1 and 2" {
    const input =
        \\class: 1-3 or 5-7
        \\row: 6-11 or 33-44
        \\seat: 13-40 or 45-50
        \\
        \\your ticket:
        \\7,1,14
        \\
        \\nearby tickets:
        \\7,3,47
        \\40,4,50
        \\55,2,20
        \\38,6,12
    ;

    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 71), try runPart1(r));
}

test "part 2" {
    const input =
        \\departure class: 0-1 or 4-19
        \\row: 0-5 or 8-19
        \\departure seat: 0-13 or 16-19
        \\
        \\your ticket:
        \\11,12,13
        \\
        \\nearby tickets:
        \\3,9,18
        \\15,1,5
        \\5,14,9
    ;

    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 12 * 13), try runPart2(r));
}
