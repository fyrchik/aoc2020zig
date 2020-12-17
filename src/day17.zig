usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    return run(r, 3);
}

pub fn runPart2(r: anytype) !usize {
    return run(r, 4);
}

pub fn run(r: anytype, comptime n: comptime_int) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const initial = try parseInput(r, &arena.allocator);
    const step_count = 6;

    var p = try Pocket(n).init(initial, initial.len + step_count * 2 + 4, &arena.allocator);
    var i: usize = 0;
    while (i < step_count) {
        p.step();
        i += 1;
    }
    return p.countActive();
}

fn SliceU2(comptime n: u3) type {
    comptime assert(n >= 0);
    return switch (n) {
        0 => u2,
        1, 2, 3, 4 => []SliceU2(n - 1),
        else => unreachable,
    };
}

fn initSlice(comptime n: u3, max_size: usize, a: *Allocator) !SliceU2(n) {
    comptime assert(n >= 1);

    var s = try a.alloc(SliceU2(n - 1), max_size);
    errdefer a.free(s);

    if (n == 1) {
        mem.set(u2, s, 0);
        return s;
    }
    for (s) |*sub| {
        sub.* = try initSlice(n - 1, max_size, a);
        errdefer a.free(sub.*);
    }
    return s;
}

fn get(comptime n: u3, s: SliceU2(n), coord: [n]usize) *u2 {
    comptime assert(n >= 1);

    if (n == 1) {
        return &s[coord[0]];
    }
    return get(n - 1, s[coord[0]], coord[1..].*);
}

fn Pocket(comptime n: comptime_int) type {
    comptime assert(n == 3 or n == 4);
    return struct {
        const Self = @This();
        const ns = comptime getSteps(n);

        max_size: usize,
        state: SliceU2(n),
        current_bit: u1,
        tmp: usize = undefined,

        // max_size must be big enough to include state every needed step.
        fn init(initial: []const []const bool, max_size: usize, a: *Allocator) !Self {
            assert(initial.len == 0 or initial.len == initial[0].len);

            var state = try initSlice(n, max_size, a);
            const mid = max_size / 2 + 1;
            const start = mid - initial.len / 2;
            var coord: [n]usize = [_]usize{0} ** n;
            for (coord[0 .. n - 2]) |*c| {
                c.* = mid;
            }
            for (initial) |s, i| {
                coord[coord.len - 2] = start + i;
                for (s) |v, j| {
                    coord[coord.len - 1] = start + j;
                    const cell = get(n, state, coord);
                    cell.* = @as(u2, @boolToInt(v));
                }
            }

            return Self{
                .max_size = max_size,
                .state = state,
                .current_bit = 0,
            };
        }

        fn increaseIfActive(s: *Self, coord: [n]usize, v: *u2) void {
            s.tmp += @boolToInt(s.isActive(v.*));
        }

        fn countActive(s: *Self) usize {
            var coord: [n]usize = undefined;
            s.tmp = 0;
            s.forEach(0, &coord, increaseIfActive);
            return s.tmp;
        }

        fn forEach(s: *Self, comptime c: u3, coord: *[n]usize, f: fn (*Self, [n]usize, *u2) void) void {
            if (c == n) {
                const v = get(n, s.state, coord.*);
                f(s, coord.*, v);
                return;
            }
            const sl = s.state[c];
            for (sl) |v, i| {
                if (i == 0 or i == sl.len - 1) {
                    continue;
                }
                coord[c] = i;
                s.forEach(c + 1, coord, f);
            }
        }

        fn cn(s: *Self, coord: [n]usize, v: *u2) void {
            const next_bit = 1 - s.current_bit;
            const nc = s.countNeighbours(coord);
            const set_next = @as(u2, 1) << next_bit;
            const is_active = s.isActive(get(n, s.state, coord).*);
            if (is_active and (nc != 2 and nc != 3) or !is_active and nc != 3) {
                v.* &= ~set_next;
            } else {
                v.* |= set_next;
            }
        }

        // max_size is assumed to be big, so boundary checks are not performed.
        fn step(s: *Self) void {
            var coord: [n]usize = undefined;
            s.forEach(0, &coord, cn);
            s.current_bit = 1 - s.current_bit;
        }

        fn isActive(s: Self, v: u2) bool {
            return 0 != (v & (@as(u2, 1) << s.current_bit));
        }

        fn countNeighbours(s: Self, coords: [n]usize) usize {
            var cnt: usize = 0;
            var new_coords = coords;
            for (ns) |v| {
                for (new_coords) |*c, i| {
                    c.* = @intCast(usize, @intCast(isize, coords[i]) + v[i]);
                }
                const curr = get(n, s.state, new_coords);
                cnt += @boolToInt(s.isActive(curr.*));
            }
            return cnt;
        }
    };
}

// Caller owns returned slice.
fn parseLine(s: []const u8, a: *Allocator) ![]bool {
    var line = try a.alloc(bool, s.len);
    errdefer a.free(line);

    for (s) |c, i| {
        switch (c) {
            '.' => line[i] = false,
            '#' => line[i] = true,
            else => return error.InvalidInput,
        }
    }
    return line;
}

fn parseInput(r: anytype, a: *Allocator) ![][]bool {
    var initial = ArrayList([]bool).init(a);
    defer initial.deinit();

    var buf: [100]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return initial.toOwnedSlice();
        const p = try parseLine(line, a);
        try initial.append(p);
    }
    return initial.toOwnedSlice();
}

fn neighboursCount(comptime n: comptime_int) comptime_int {
    assert(n > 0);

    comptime var pow = 1;
    comptime var i = 0;
    while (i < n) {
        pow *= 3;
        i += 1;
    }
    return pow - 1;
}

fn getSteps(comptime n: comptime_int) [neighboursCount(n)][n]i2 {
    @setEvalBranchQuota(2000);
    if (n == 1) {
        return [2][1]i2{ [1]i2{-1}, [1]i2{1} };
    }

    const nc = comptime neighboursCount(n);
    comptime var ns = [_][n]i2{[_]i2{0} ** n} ** nc;
    comptime var cnt = 0;
    inline for ([_]i2{ -1, 0, 1 }) |i| {
        const steps: [neighboursCount(n - 1)][n - 1]i2 = comptime getSteps(n - 1);
        inline for (steps) |s| {
            ns[cnt][0] = i;
            inline for (s) |v, j| {
                ns[cnt][j + 1] = v;
            }
            cnt += 1;
        }
        // Don't forget about step with single non-zero coordinate!
        if (i != 0) {
            ns[cnt][0] = i;
            cnt += 1;
        }
    }
    return ns;
}

test "part 1" {
    const input = ".#.\n..#\n###";
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 112), try runPart1(r));
}

test "part 2" {
    const input = ".#.\n..#\n###";
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 848), try runPart2(r));
}
