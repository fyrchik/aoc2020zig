usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    return run(r, doStep);
}

pub fn runPart2(r: anytype) !usize {
    return run(r, doStepWithWaypoint);
}

fn run(r: anytype, comptime f: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const ss = try readSteps(r, &arena.allocator);
    var st = State{
        .direction = .East,
        .wx = 10,
        .wy = 1,
    };
    for (ss) |s| {
        f(&st, s);
    }
    return st.abs();
}

const State = struct {
    const Self = @This();

    direction: Direction,
    x: isize = 0,
    y: isize = 0,

    wx: isize = 0,
    wy: isize = 0,

    fn abs(s: Self) usize {
        const mx = math.absInt(s.x) catch unreachable;
        const my = math.absInt(s.y) catch unreachable;
        return @intCast(usize, mx + my);
    }
};

// Direction represents all possible directions.
// Exact values are used to perform arithmetic with turns.
const Direction = enum {
    North = 0,
    East = 1,
    South = 2,
    West = 3,
};

const Step = union(enum) {
    Move: struct {
        d: Direction,
        n: isize,
    },
    Left: isize,
    Right: isize,
    Forward: isize,
};

inline fn doStep(st: *State, s: Step) void {
    switch (s) {
        .Left, .Right => {
            var amount: u4 = 0;
            if (s == .Left) {
                amount = 4 - @intCast(u4, @mod(@divTrunc(s.Left, 90), 4));
            } else {
                amount = @intCast(u4, @mod(@divTrunc(s.Right, 90), 4));
            }
            const dir = @as(u4, @enumToInt(st.direction));
            const newDir = @intCast(u2, @mod(dir + amount, 4));
            st.direction = @intToEnum(Direction, newDir);
        },
        .Forward => switch (st.direction) {
            .North => st.y += s.Forward,
            .East => st.x += s.Forward,
            .South => st.y -= s.Forward,
            .West => st.x -= s.Forward,
        },
        .Move => switch (s.Move.d) {
            .North => st.y += s.Move.n,
            .East => st.x += s.Move.n,
            .South => st.y -= s.Move.n,
            .West => st.x -= s.Move.n,
        },
    }
}

inline fn doStepWithWaypoint(st: *State, s: Step) void {
    switch (s) {
        .Left, .Right => {
            var amount: u4 = 0;
            if (s == .Left) {
                amount = 4 - @intCast(u4, @mod(@divTrunc(s.Left, 90), 4));
            } else {
                amount = @intCast(u4, @mod(@divTrunc(s.Right, 90), 4));
            }
            const ox = st.wx;
            const oy = st.wy;
            switch (amount) {
                0 => {},
                1 => {
                    st.wx = oy;
                    st.wy = -ox;
                },
                2 => {
                    st.wx = -ox;
                    st.wy = -oy;
                },
                3 => {
                    st.wx = -oy;
                    st.wy = ox;
                },
                else => unreachable,
            }
        },
        .Forward => {
            st.x += st.wx * s.Forward;
            st.y += st.wy * s.Forward;
        },
        .Move => switch (s.Move.d) {
            .North => st.wy += s.Move.n,
            .East => st.wx += s.Move.n,
            .South => st.wy -= s.Move.n,
            .West => st.wx -= s.Move.n,
        },
    }
}

// readSteps reads sequence of operations from r.
// Caller owns returned slice.
fn readSteps(r: anytype, a: *Allocator) ![]Step {
    var ss = ArrayList(Step).init(a);
    var buf: [10]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return ss.toOwnedSlice();
        const step = try parseStep(line);
        try ss.append(step);
    }
}

fn parseStep(s: []const u8) !Step {
    const num = try fmt.parseUnsigned(isize, s[1..], 10);
    return switch (s[0]) {
        'N' => Step{ .Move = .{ .d = .North, .n = num } },
        'S' => Step{ .Move = .{ .d = .South, .n = num } },
        'E' => Step{ .Move = .{ .d = .East, .n = num } },
        'W' => Step{ .Move = .{ .d = .West, .n = num } },
        'F' => Step{ .Forward = num },
        'L' => Step{ .Left = num },
        'R' => Step{ .Right = num },
        else => error.InvalidFormat,
    };
}

test "part 1 and 2" {
    const path = "F10\nN3\nF7\nR90\nF11";
    var r = io.fixedBufferStream(path).reader();
    expectEqual(@as(usize, 25), try runPart1(r));

    r = io.fixedBufferStream(path).reader();
    expectEqual(@as(usize, 286), try runPart2(r));
}
