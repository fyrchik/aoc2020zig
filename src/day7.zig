usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    return run(r, addReverse, true);
}

pub fn runPart2(r: anytype) !usize {
    return run(r, addDirect, false);
}

fn run(r: anytype, comptime f: anytype, return_size: bool) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var m = &std.StringHashMap(ArrayList(BagWithCount)).init(&arena.allocator);
    try m.ensureCapacity(100_000);

    while (true) {
        var buf = try arena.allocator.alloc(u8, 1024);
        var line = (try r.readUntilDelimiterOrEof(buf, '\n')) orelse break;
        try parseRule(line, m, f);
    }

    var cnt: usize = undefined;
    const sz = try getPathCount("shiny gold", m, &cnt);
    return if (return_size) sz else cnt;
}

const BagWithCount = struct {
    color: []const u8,
    count: usize = 0,
};

inline fn addReverse(m: *StringHashMap(ArrayList(BagWithCount)), main: []const u8, no: usize, color: []const u8) anyerror!void {
    const res = try m.getOrPut(color);
    if (!res.found_existing) {
        res.entry.value = std.ArrayList(BagWithCount).init(m.allocator);
    }
    try res.entry.value.append(BagWithCount{ .color = main, .count = no });
}

inline fn addDirect(m: *StringHashMap(ArrayList(BagWithCount)), main: []const u8, no: usize, color: []const u8) anyerror!void {
    const res = try m.getOrPut(main);
    if (!res.found_existing) {
        res.entry.value = std.ArrayList(BagWithCount).init(m.allocator);
    }
    try res.entry.value.append(BagWithCount{ .color = color, .count = no });
}

fn parseRule(s: []const u8, m: anytype, comptime add: fn (*StringHashMap(ArrayList(BagWithCount)), []const u8, usize, []const u8) anyerror!void) !void {
    const end1 = mem.indexOf(u8, s, " bags") orelse return error.InvalidRule;
    const main = s[0..end1];

    var index = end1 + 1 + 4 + 1 + 8;
    if (mem.startsWith(u8, s[index..], "no other")) {
        return;
    }
    while (true) {
        var num_end: usize = 0;
        for (s[index..]) |c| {
            switch (c) {
                '0'...'9' => num_end += 1,
                else => break,
            }
        }
        const num = try fmt.parseUnsigned(usize, s[index .. index + num_end], 10);
        index += num_end + 1;

        const end = mem.indexOf(u8, s[index..], " bag") orelse return error.InvalidRule;
        const color = s[index .. index + end];
        try add(m, main, num, color);

        index += end + 4;
        for (s[index..]) |c| {
            switch (c) {
                's', ',', ' ' => index += 1,
                '.' => return,
                else => break,
            }
        }
    }
}

fn getPathCount(key: []const u8, m: *StringHashMap(ArrayList(BagWithCount)), count: *usize) !usize {
    var seen = std.StringHashMap(usize).init(testing.allocator);
    defer seen.deinit();

    var queue = std.ArrayList(BagWithCount).init(m.allocator);
    defer queue.deinit();

    const arr = m.get(key) orelse return 0;
    for (arr.items) |item| {
        try queue.append(item);
    }

    var cnt: usize = 0;
    var index: usize = 0;
    while (index < queue.items.len) {
        const next = queue.items[index];
        index += 1;

        try seen.put(next.color, next.count);
        cnt += next.count;
        if (m.get(next.color)) |val| {
            for (val.items) |item| {
                try queue.append(BagWithCount{
                    .color = item.color,
                    .count = item.count * next.count,
                });
            }
        }
    }
    count.* = cnt;
    return @as(usize, seen.count());
}

fn freeMap(m: *StringHashMap(ArrayList(BagWithCount))) void {
    var iter = m.iterator();
    while (iter.next()) |entry| {
        entry.value.deinit();
    }
    m.deinit();
}

test "parse rule" {
    var m = &std.StringHashMap(ArrayList(BagWithCount)).init(testing.allocator);
    defer freeMap(m);

    try parseRule("light red bags contain 1 bright white bag, 2 muted yellow bags.", m, addReverse);
    try parseRule("dark orange bags contain 3 bright white bags, 4 muted yellow bags.", m, addReverse);
    try parseRule("bright white bags contain 1 shiny gold bag.", m, addReverse);
    try parseRule("muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.", m, addReverse);
    try parseRule("shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.", m, addReverse);
    try parseRule("dark olive bags contain 3 faded blue bags, 4 dotted black bags.", m, addReverse);
    try parseRule("vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.", m, addReverse);
    try parseRule("faded blue bags contain no other bags.", m, addReverse);
    try parseRule("dotted black bags contain no other bags.", m, addReverse);

    var tmp: usize = undefined;
    const cnt = try getPathCount("shiny gold", m, &tmp);
    expectEqual(@as(usize, 4), cnt);
}

test "parse rule, part2" {
    var m = &std.StringHashMap(ArrayList(BagWithCount)).init(testing.allocator);
    defer freeMap(m);

    try parseRule("shiny gold bags contain 2 dark red bags.", m, addDirect);
    try parseRule("dark red bags contain 2 dark orange bags.", m, addDirect);
    try parseRule("dark orange bags contain 2 dark yellow bags.", m, addDirect);
    try parseRule("dark yellow bags contain 2 dark green bags.", m, addDirect);
    try parseRule("dark green bags contain 2 dark blue bags.", m, addDirect);
    try parseRule("dark blue bags contain 2 dark violet bags.", m, addDirect);
    try parseRule("dark violet bags contain no other bags.", m, addDirect);

    var tmp: usize = undefined;
    const cnt = try getPathCount("shiny gold", m, &tmp);
    expectEqual(@as(usize, 126), tmp);
}
