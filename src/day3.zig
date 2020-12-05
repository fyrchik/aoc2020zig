const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const testing = std.testing;
const expect = testing.expect;
const assert = std.debug.assert;
const mem = std.mem;

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var m = try readMap(r, &arena.allocator);
    return countTrees(m, 3, 1);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var m = try readMap(r, &arena.allocator);
    const c1 = countTrees(m, 1, 1);
    const c2 = countTrees(m, 3, 1);
    const c3 = countTrees(m, 5, 1);
    const c4 = countTrees(m, 7, 1);
    const c5 = countTrees(m, 1, 2);
    return c1 * c2 * c3 * c4 * c5;
}

const treeCell: u8 = '#';

// countTrees counts how much trees will be encountered if moving from
// (0,0) cell with steps of (dx,dy). First coordinate is for horisontal dimension.
fn countTrees(m: std.ArrayList([]const u8), dx: usize, dy: usize) usize {
    var x: usize = 0;
    var y: usize = 0;
    var cnt: usize = 0;
    assert(dy > 0);
    while (true) {
        y += dy;
        if (y >= m.items.len) {
            return cnt;
        }
        const s = m.items[y];
        x = (x + dx) % s.len;
        if (s[x] == treeCell) {
            cnt += 1;
        }
    }
}

// readMap reads map from reader. Caller owns returned list and all items in it.
fn readMap(r: anytype, a: *std.mem.Allocator) !std.ArrayList([]const u8) {
    const maxLineSize = 1000;
    var arr = std.ArrayList([]const u8).init(a);
    errdefer freeMap(arr, a);

    while (true) {
        var buf = try a.alloc(u8, maxLineSize);
        const line = (try r.readUntilDelimiterOrEof(buf, '\n')) orelse {
            a.free(buf);
            break;
        };
        try arr.append(line);
    }
    return arr;
}

fn freeMap(m: std.ArrayList([]const u8), a: *std.mem.Allocator) void {
    for (m.items) |it| {
        a.free(it);
    }
    m.deinit();
}

test "count trees" {
    var arr = std.ArrayList([]const u8).init(testing.allocator);
    defer arr.deinit();
    try arr.append("..##.......");
    try arr.append("#...#...#..");
    try arr.append(".#....#..#.");
    try arr.append("..#.#...#.#");
    try arr.append(".#...##..#.");
    try arr.append("..#.##.....");
    try arr.append(".#.#.#....#");
    try arr.append(".#........#");
    try arr.append("#.##...#...");
    try arr.append("#...##....#");
    try arr.append(".#..#...#.#");

    expect(7 == countTrees(arr, 3, 1));
    expect(3 == countTrees(arr, 0, 1));
    expect(2 == countTrees(arr, 1, 2));
}

test "readMap" {
    const buf = "..##.......\n#...#...#..\n.#....#..#.";
    var r = io.fixedBufferStream(buf).reader();
    var m = readMap(r, testing.allocator) catch unreachable;
    defer freeMap(m, testing.allocator);

    testing.expect(3 == m.items.len);
    testing.expect(mem.eql(u8, "..##.......", m.items[0]));
    testing.expect(mem.eql(u8, "#...#...#..", m.items[1]));
    testing.expect(mem.eql(u8, ".#....#..#.", m.items[2]));
}
