usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return parseAndFlip(r, 0, &arena.allocator);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return parseAndFlip(r, 100, &arena.allocator);
}

const Direction = enum {
    East,
    SouthEast,
    SouthWest,
    West,
    NorthWest,
    NorthEast,
};

const TileMap = AutoHashMap([2]isize, bool);

fn parseAndFlip(r: anytype, days: usize, a: *Allocator) !usize {
    var buf: [100]u8 = undefined;
    var m = AutoHashMap([2]isize, bool).init(a);
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        const dirs = try parseLine(line, a);
        const xy = getCoordinate(0, 0, dirs);
        var res = try m.getOrPut(xy);
        res.entry.value = if (res.found_existing) !res.entry.value else true;
    }

    var day: usize = 0;
    while (day < days) {
        var next = AutoHashMap([2]isize, bool).init(a);
        var iter = m.iterator();
        while (iter.next()) |kv| {
            const neighbours = getNeighbours(kv.key);
            const count = countBlack(neighbours, m);
            if (getNextColor(kv.value, count)) {
                try next.put(kv.key, true);
            }
            for (neighbours) |xy| {
                const tile = m.get(xy);
                if (tile != null and next.get(xy) == null) // visited during normal iteration;
                    continue;
                const cnt = countBlack(getNeighbours(xy), m);
                if (getNextColor(false, cnt)) {
                    try next.put(xy, true);
                }
            }
        }
        m = next;
        day += 1;

        var it = m.iterator();
        var cnt: usize = 0;
        while (it.next()) |kv| {
            if (kv.value) {
                cnt += 1;
            }
        }
        print("day {}, count {}\n", .{ day, cnt });
    }

    var iter = m.iterator();
    var count: usize = 0;
    while (iter.next()) |kv| {
        if (kv.value) {
            count += 1;
        }
    }
    return count;
}

fn getNextColor(is_black: bool, cnt: usize) bool {
    if (is_black) {
        return cnt == 1 or cnt == 2;
    }
    return cnt == 2;
}

fn getNeighbours(xy: [2]isize) [6][2]isize {
    return [6][2]isize{
        [2]isize{ xy[0] - 2, xy[1] },
        [2]isize{ xy[0] + 2, xy[1] },
        [2]isize{ xy[0] + 1, xy[1] + 3 },
        [2]isize{ xy[0] + 1, xy[1] - 3 },
        [2]isize{ xy[0] - 1, xy[1] + 3 },
        [2]isize{ xy[0] - 1, xy[1] - 3 },
    };
}

fn countBlack(neighbours: [6][2]isize, m: TileMap) usize {
    var count: usize = 0;
    for (neighbours) |xy| {
        const res = m.get(xy);
        if (res != null and res.?) {
            count += 1;
        }
    }
    return count;
}

fn getCoordinate(start_x: isize, start_y: isize, dirs: []const Direction) [2]isize {
    var x = start_x;
    var y = start_y;
    for (dirs) |d| {
        switch (d) {
            .East => x += 2,
            .SouthEast => {
                x += 1;
                y -= 3;
            },
            .SouthWest => {
                x -= 1;
                y -= 3;
            },
            .West => x -= 2,
            .NorthWest => {
                x -= 1;
                y += 3;
            },
            .NorthEast => {
                x += 1;
                y += 3;
            },
        }
    }
    return [2]isize{ x, y };
}

fn parseLine(s: []const u8, a: *Allocator) ![]Direction {
    var dirs = ArrayList(Direction).init(a);
    var i: usize = 0;
    while (i < s.len) {
        try dirs.append(switch (s[i]) {
            'e' => .East,
            's' => blk: {
                i += 1;
                break :blk @as(Direction, switch (s[i]) {
                    'w' => .SouthWest,
                    'e' => .SouthEast,
                    else => unreachable,
                });
            },
            'w' => .West,
            'n' => blk: {
                i += 1;
                break :blk @as(Direction, switch (s[i]) {
                    'w' => .NorthWest,
                    'e' => .NorthEast,
                    else => unreachable,
                });
            },
            else => unreachable,
        });
        i += 1;
    }
    return dirs.toOwnedSlice();
}

test "part 1" {
    const input =
        \\sesenwnenenewseeswwswswwnenewsewsw
        \\neeenesenwnwwswnenewnwwsewnenwseswesw
        \\seswneswswsenwwnwse
        \\nwnwneseeswswnenewneswwnewseswneseene
        \\swweswneswnenwsewnwneneseenw
        \\eesenwseswswnenwswnwnwsewwnwsene
        \\sewnenenenesenwsewnenwwwse
        \\wenwwweseeeweswwwnwwe
        \\wsweesenenewnwwnwsenewsenwwsesesenwne
        \\neeswseenwwswnwswswnw
        \\nenwswwsewswnenenewsenwsenwnesesenew
        \\enewnwewneswsewnwswenweswnenwsenwsw
        \\sweneswneswneneenwnewenewwneswswnese
        \\swwesenesewenwneswnwwneseswwne
        \\enesenwswwswneneswsenwnewswseenwsese
        \\wnwnesenesenenwwnenwsewesewsesesew
        \\nenewswnwewswnenesenwnesewesw
        \\eneswnwswnwsenenwnwnwwseeswneewsenese
        \\neswnwewnwnwseenwseesewsenwsweewe
        \\wseweeenwnesenwwwswnew
    ;

    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 10), try runPart1(r));

    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 2208), try runPart2(r));
}
