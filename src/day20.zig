usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const tile_map = try parseInput(r, &arena.allocator);
    var used = TileMap.init(&arena.allocator);
    const field = try tryCombine(tile_map, &used, &arena.allocator);
    const last = field.len - 1;
    const top_left = field[0][0];
    const top_right = field[0][last];
    const bottom_left = field[last][0];
    const bottom_right = field[last][last];
    return top_left * top_right * bottom_left * bottom_right;
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const tile_map = try parseInput(r, &arena.allocator);
    var used = TileMap.init(&arena.allocator);
    const field = try tryCombine(tile_map, &used, &arena.allocator);
    var image = try getImage(field, used, &arena.allocator);
    var total: usize = 0;
    for (image) |row, i| {
        for (row) |v, j| {
            total += @boolToInt(v);
        }
    }

    var i: usize = 0;
    while (i < 8) {
        const sym = @intCast(u3, i);
        const new_image = try applySymmetry(image, sym, &arena.allocator);
        defer arena.allocator.free(new_image);

        const cnt = countPatterns(new_image, sym);
        if (cnt != 0) {
            return total - cnt * 15; // 15 is the size of the monster.
        }
        i += 1;
    }
    return error.NoMonstersFound;
}

fn applySymmetry(image: []const []const bool, sym: u3, a: *Allocator) ![][]bool {
    var new_image = try alloc2(bool, a, image.len, image.len);
    errdefer free2(bool, a, new_image);

    for (image) |row, x| {
        for (row) |c, y| {
            var real_x: usize = undefined;
            var real_y: usize = undefined;
            transformCoordinates(usize, sym, image.len, x, y, &real_x, &real_y);
            new_image[real_x][real_y] = c;
        }
    }
    return new_image;
}

fn countPatterns(image: []const []const bool, sym: u3) usize {
    var cnt: usize = 0;
    var x: usize = 0;
    while (x < image.len) {
        var y: usize = 0;
        while (y < image.len) {
            const res = checkPattern(image, sym, x, y);
            cnt += @boolToInt(res);
            y += 1;
        }
        x += 1;
    }
    return cnt;
}

fn checkPattern(image: []const []const bool, sym: u3, x: usize, y: usize) bool {
    // Pattern:
    //                  #
    //#    ##    ##    ###
    // #  #  #  #  #  #
    const indices = [_][2]usize{
        [2]usize{ 0, 18 },
        [2]usize{ 1, 0 },
        [2]usize{ 1, 5 },
        [2]usize{ 1, 6 },
        [2]usize{ 1, 11 },
        [2]usize{ 1, 12 },
        [2]usize{ 1, 17 },
        [2]usize{ 1, 18 },
        [2]usize{ 1, 19 },
        [2]usize{ 2, 1 },
        [2]usize{ 2, 4 },
        [2]usize{ 2, 7 },
        [2]usize{ 2, 10 },
        [2]usize{ 2, 13 },
        [2]usize{ 2, 16 },
    };

    var real_x: usize = x;
    var real_y: usize = y;
    for (indices) |pair, i| {
        if (real_x + pair[0] >= image.len or real_y + pair[1] >= image.len or !image[real_x + pair[0]][real_y + pair[1]]) {
            return false;
        }
    }
    return true;
}

fn getImage(field: [][]usize, tile_map: TileMap, a: *Allocator) ![][]bool {
    const cropped_size = tile_size - 2;
    const image_size = field.len * cropped_size;
    var image = try alloc2(bool, a, image_size, image_size);
    errdefer free2(bool, a, image);

    for (field) |row, i| {
        for (row) |id, j| {
            const t = tile_map.get(id).?;
            fillImageTile(image, i * cropped_size, j * cropped_size, t);
        }
    }
    return image;
}

fn fillImageTile(image: [][]bool, x: usize, y: usize, t: Tile) void {
    var ix = x;
    while (ix < x + tile_size - 2) {
        var iy = y;
        while (iy < y + tile_size - 2) {
            const tx = @intCast(T, ix - x + 1);
            const ty = @intCast(T, iy - y + 1);
            image[ix][iy] = getBit(t, tx, ty);
            iy += 1;
        }
        ix += 1;
    }
}

const T = u10;
const tile_size = @typeInfo(T).Int.bits;
const shift = tile_size - 1;
const Tile = struct {
    id: usize,
    // [left, top, right, bottom].
    num: [4]T,
    // We don't rotate row-by-row representation as it isn't needed during calculation.
    // Instead we store initial rows and type of symmetry.
    all: [tile_size]T,
    symmetry: u3 = 0,
};

fn srqt(n: usize) !usize {
    var i: usize = 0;
    while (true) {
        const p = i * i;
        if (p == n)
            return i;
        if (p > n) {
            return error.NotASquare;
        }
        i += 1;
    }
}

const TileMap = AutoHashMap(usize, Tile);

fn tryCombine(tile_map: TileMap, used: *TileMap, a: *Allocator) ![][]usize {
    var rotations = try a.alloc([8]Tile, tile_map.count());
    defer a.free(rotations);

    var iter = tile_map.iterator();
    var index: usize = 0;
    while (iter.next()) |kv| {
        rotations[index] = getRotations(kv.value);
        index += 1;
    }

    const field_size = try srqt(tile_map.count());
    var field = try alloc2(usize, a, field_size, field_size);
    errdefer free2(usize, a, field);

    // Iterate row by row.
    var result = try iterateField(field, 0, 0, rotations, used);
    if (!result)
        return error.NoArrangementPossible;

    //print("used {}, tile_map {}\n", .{ used.count(), tile_map.count() });
    assert(used.count() == tile_map.count());
    return field;
}

fn iterateField(field: [][]usize, x: usize, y: usize, tiles: [][8]Tile, used: *TileMap) anyerror!bool {
    //print("enter {} {} {}\n", .{ x, y, used.count() });
    // For each unused, try to attach it next.
    for (tiles) |ts| {
        const id = ts[0].id;
        if (used.get(id) != null)
            continue;

        // Try each rotation.
        for (ts) |t| {
            if (!tryAttach(field, x, y, t, used.*))
                continue;
            field[x][y] = id;
            try used.put(id, t);

            // Iterate row by row.
            var next_x: usize = x + 1;
            var next_y: usize = y + 1;
            if (next_x >= field.len and next_y >= field.len)
                return true;

            if (next_y < field.len) {
                next_x = x;
            } else {
                next_y = 0;
            }

            if (try iterateField(field, next_x, next_y, tiles, used))
                return true;

            _ = used.remove(id);
        }
    }
    return false;
}

// tryAttach tries to put t into (x,y) cell.
// Because of iteration order only top and left tile needs to be checked for match.
fn tryAttach(field: [][]usize, x: usize, y: usize, t: Tile, used: TileMap) bool {
    if (x != 0) {
        // Check top side.
        const top_index = field[x - 1][y];
        const top = used.get(top_index).?;
        if (t.num[1] != top.num[3])
            return false;
    }
    if (y != 0) {
        // Check left side.
        const left_index = field[x][y - 1];
        const left = used.get(left_index).?;
        if (t.num[0] != left.num[2])
            return false;
    }
    return true;
}

// canAttach tries to attach b to a and returns list of sides it can be attached to.
// It doesn't take rotations into account.
fn canAttach(a: Tile, b: Tile) [4]bool {
    var result: [4]bool = undefined;
    inline for (result) |_, i| {
        result[i] = a.num[i] == b.num[i];
    }
    return result;
}

fn transformCoordinates(comptime C: type, sym: u3, size: C, x: C, y: C, xx: *C, yy: *C) void {
    const fx = size - x - 1;
    const fy = size - y - 1;
    switch (sym) {
        0 => {
            xx.* = x;
            yy.* = y;
        },
        1 => {
            xx.* = fy;
            yy.* = x;
        },
        2 => {
            xx.* = fx;
            yy.* = fy;
        },
        3 => {
            xx.* = y;
            yy.* = fx;
        },
        4 => {
            xx.* = fx;
            yy.* = y;
        },
        5 => {
            xx.* = x;
            yy.* = fy;
        },
        6 => {
            xx.* = y;
            yy.* = x;
        },
        7 => {
            xx.* = fy;
            yy.* = fx;
        },
    }
}

fn getBit(t: Tile, x: T, y: T) bool {
    assert(x < tile_size and y < tile_size);

    const fx = tile_size - x - 1;
    const fy = tile_size - y - 1;
    var real_x: T = undefined;
    var real_y: T = undefined;
    transformCoordinates(T, complement(t.symmetry), tile_size, x, y, &real_x, &real_y);
    return 0 != t.all[real_x] & (@as(T, 1) << @intCast(u4, tile_size - real_y - 1));
}

fn complement(sym: u3) u3 {
    return switch (sym) {
        0 => 0,
        1 => 3,
        2 => 2,
        3 => 1,
        4 => 4,
        5 => 5,
        6 => 6,
        7 => 7,
    };
}

// getRotations returns all possible symmetries of t including identity.
fn getRotations(t: Tile) [8]Tile {
    const num = t.num;
    const rev = [4]T{
        @bitReverse(T, num[0]),
        @bitReverse(T, num[1]),
        @bitReverse(T, num[2]),
        @bitReverse(T, num[3]),
    };

    var a: [8]Tile = undefined;
    // Identity.
    a[0] = t;
    // Rotations left for 90, 180, 270.
    a[1] = Tile{ .num = [4]T{ rev[1], num[2], rev[3], num[0] }, .id = t.id, .all = t.all, .symmetry = 1 };
    a[2] = Tile{ .num = [4]T{ rev[2], rev[3], rev[0], rev[1] }, .id = t.id, .all = t.all, .symmetry = 2 };
    a[3] = Tile{ .num = [4]T{ num[3], rev[0], num[1], rev[2] }, .id = t.id, .all = t.all, .symmetry = 3 };
    // Flip top-down.
    a[4] = Tile{ .num = [4]T{ rev[0], num[3], rev[2], num[1] }, .id = t.id, .all = t.all, .symmetry = 4 };
    // Flip right-left.
    a[5] = Tile{ .num = [4]T{ num[2], rev[1], num[0], rev[3] }, .id = t.id, .all = t.all, .symmetry = 5 };
    // Diagonal flip across 2 diagonals (rotation + flip).
    a[6] = Tile{ .num = [4]T{ num[1], num[0], num[3], num[2] }, .id = t.id, .all = t.all, .symmetry = 6 };
    a[7] = Tile{ .num = [4]T{ rev[3], rev[2], rev[1], rev[0] }, .id = t.id, .all = t.all, .symmetry = 7 };
    return a;
}

fn parseInput(r: anytype, a: *Allocator) !TileMap {
    var m = TileMap.init(a);
    errdefer m.deinit();

    var buf: [20]u8 = undefined;
    while (true) {
        var line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        const ind = mem.indexOf(u8, line, " ") orelse return error.InvalidInput;
        const tile_index = try fmt.parseUnsigned(usize, line[ind + 1 .. line.len - 1], 10);

        var rows: [tile_size]T = undefined;
        var left: T = 0;
        var right: T = 0;
        var i: usize = 0;
        while (i < tile_size) {
            line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
            rows[i] = try parseLine(line);
            left = (left << 1) | ((rows[i] & (1 << shift)) >> shift);
            right = (right << 1) | (rows[i] & 1);
            i += 1;
        }
        try m.put(tile_index, Tile{
            .id = tile_index,
            .num = [4]T{ left, rows[0], right, rows[rows.len - 1] },
            .all = rows,
            .symmetry = 0,
        });
        _ = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
    }
    return m;
}

fn parseLine(s: []const u8) !T {
    var num: T = 0;
    for (s) |c| {
        switch (c) {
            '.' => num <<= 1,
            '#' => num = (num << 1) | 1,
            else => return error.InvalidInput,
        }
    }
    return num;
}

test "part 1" {
    const input =
        \\Tile 2311:
        \\..##.#..#.
        \\##..#.....
        \\#...##..#.
        \\####.#...#
        \\##.##.###.
        \\##...#.###
        \\.#.#.#..##
        \\..#....#..
        \\###...#.#.
        \\..###..###
        \\
        \\Tile 1951:
        \\#.##...##.
        \\#.####...#
        \\.....#..##
        \\#...######
        \\.##.#....#
        \\.###.#####
        \\###.##.##.
        \\.###....#.
        \\..#.#..#.#
        \\#...##.#..
        \\
        \\Tile 1171:
        \\####...##.
        \\#..##.#..#
        \\##.#..#.#.
        \\.###.####.
        \\..###.####
        \\.##....##.
        \\.#...####.
        \\#.##.####.
        \\####..#...
        \\.....##...
        \\
        \\Tile 1427:
        \\###.##.#..
        \\.#..#.##..
        \\.#.##.#..#
        \\#.#.#.##.#
        \\....#...##
        \\...##..##.
        \\...#.#####
        \\.#.####.#.
        \\..#..###.#
        \\..##.#..#.
        \\
        \\Tile 1489:
        \\##.#.#....
        \\..##...#..
        \\.##..##...
        \\..#...#...
        \\#####...#.
        \\#..#.#.#.#
        \\...#.#.#..
        \\##.#...##.
        \\..##.##.##
        \\###.##.#..
        \\
        \\Tile 2473:
        \\#....####.
        \\#..#.##...
        \\#.##..#...
        \\######.#.#
        \\.#...#.#.#
        \\.#########
        \\.###.#..#.
        \\########.#
        \\##...##.#.
        \\..###.#.#.
        \\
        \\Tile 2971:
        \\..#.#....#
        \\#...###...
        \\#.#.###...
        \\##.##..#..
        \\.#####..##
        \\.#..####.#
        \\#..#.#..#.
        \\..####.###
        \\..#.#.###.
        \\...#.#.#.#
        \\
        \\Tile 2729:
        \\...#.#.#.#
        \\####.#....
        \\..#.#.....
        \\....#..#.#
        \\.##..##.#.
        \\.#.####...
        \\####.#.#..
        \\##.####...
        \\##..#.##..
        \\#.##...##.
        \\
        \\Tile 3079:
        \\#.#.#####.
        \\.#..######
        \\..#.......
        \\######....
        \\####.#..#.
        \\.#...#.##.
        \\#.#####.##
        \\..#.###...
        \\..#.......
        \\..#.###...
    ;

    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 20899048083289), try runPart1(r));

    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 273), try runPart2(r));
}
