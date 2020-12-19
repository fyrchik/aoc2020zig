usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const rules = try parseRules(r, &arena.allocator);
    return countValid(r, rules, &arena.allocator);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var rules = try parseRules(r, &arena.allocator);
    // Rewrite with:
    // 8: 42 | 42 8
    // 11: 42 31 | 42 11 31
    var res = try rules.getOrPut(8);
    res.entry.value = Rule{ .Alt = &[_][]const usize{ &[_]usize{42}, &[_]usize{ 42, 8 } } };

    res = try rules.getOrPut(11);
    res.entry.value = Rule{ .Alt = &[_][]const usize{ &[_]usize{ 42, 31 }, &[_]usize{ 42, 11, 31 } } };

    return countValid(r, rules, &arena.allocator);
}

const Rule = union(enum) {
    Char: u8,
    Alt: []const []const usize,
};

const RuleMap = std.AutoHashMap(usize, Rule);

fn countValid(r: anytype, rules: RuleMap, a: *Allocator) !usize {
    var buf: [100]u8 = undefined;
    var cnt: usize = 0;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return cnt;
        const is_valid = try isMessageValid(line, rules, a);
        cnt += @boolToInt(is_valid);
    }
    return cnt;
}

// Caller owns returned map.
fn parseRules(r: anytype, a: *Allocator) !RuleMap {
    var buf: [100]u8 = undefined;
    var rules = std.AutoHashMap(usize, Rule).init(a);

    while (true) {
        var line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return error.InvalidInput;
        if (0 == line.len)
            break;
        const start = mem.indexOf(u8, line, ": ") orelse return error.InvalidInput;
        const rule_index = try fmt.parseUnsigned(usize, line[0..start], 10);

        line = line[start + 2 ..];
        if (mem.startsWith(u8, line, "\"")) {
            try rules.put(rule_index, Rule{ .Char = line[1] });
            continue;
        }

        var iter = mem.split(line, "|");
        var rule = ArrayList([]usize).init(a);
        defer rule.deinit();

        while (iter.next()) |s| {
            var nums = mem.split(s, " ");
            var single = ArrayList(usize).init(a);
            defer single.deinit();

            while (nums.next()) |num| {
                if (0 == num.len)
                    continue;
                const n = try fmt.parseUnsigned(usize, num, 10);
                try single.append(n);
            }
            try rule.append(single.toOwnedSlice());
        }
        try rules.put(rule_index, Rule{ .Alt = rule.toOwnedSlice() });
    }
    return rules;
}

/// Checks if message satisfies first rule.
fn isMessageValid(line: []const u8, rules: RuleMap, a: *Allocator) !bool {
    const rule0 = rules.get(0).?;
    const result = (try checkRule(line, rule0, rules, a)) orelse return false;
    for (result) |last| {
        if (last == line.len)
            return true;
    }
    return false;
}

var debug: bool = false;

fn checkRule(msg: []const u8, r: Rule, rs: RuleMap, a: *Allocator) anyerror!?[]usize {
    if (msg.len == 0)
        return null;

    switch (r) {
        .Char => {
            if (msg[0] != r.Char)
                return null;
            const res = try a.alloc(usize, 1);
            res[0] = 1;
            return res;
        },
        .Alt => {
            var good = ArrayList(usize).init(a);
            defer good.deinit();
            loop: for (r.Alt) |list, i| {
                var curr: []const usize = &[_]usize{0};
                for (list) |num| {
                    if (curr.len == 0)
                        continue :loop;

                    const rule_to_check = rs.get(num) orelse unreachable;
                    var next = ArrayList(usize).init(a);
                    defer next.deinit();
                    for (curr) |c| {
                        const indices = (try checkRule(msg[c..], rule_to_check, rs, a)) orelse continue;
                        for (indices) |ind| {
                            try next.append(c + ind);
                        }
                    }
                    curr = next.toOwnedSlice();
                }
                for (curr) |ind| {
                    try good.append(ind);
                }
            }
            return good.toOwnedSlice();
        },
    }
}

test "part 1" {
    const input =
        \\0: 4 1 5
        \\1: 2 3 | 3 2
        \\2: 4 4 | 5 5
        \\3: 4 5 | 5 4
        \\4: "a"
        \\5: "b"
        \\
        \\ababbb
        \\bababa
        \\abbbab
        \\aaabbb
        \\aaaabbb
    ;
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 2), try runPart1(r));
}

test "part 2" {
    const input =
        \\42: 9 14 | 10 1
        \\9: 14 27 | 1 26
        \\10: 23 14 | 28 1
        \\1: "a"
        \\11: 42 31
        \\5: 1 14 | 15 1
        \\19: 14 1 | 14 14
        \\12: 24 14 | 19 1
        \\16: 15 1 | 14 14
        \\31: 14 17 | 1 13
        \\6: 14 14 | 1 14
        \\2: 1 24 | 14 4
        \\0: 8 11
        \\13: 14 3 | 1 12
        \\15: 1 | 14
        \\17: 14 2 | 1 7
        \\23: 25 1 | 22 14
        \\28: 16 1
        \\4: 1 1
        \\20: 14 14 | 1 15
        \\3: 5 14 | 16 1
        \\27: 1 6 | 14 18
        \\14: "b"
        \\21: 14 1 | 1 14
        \\25: 1 1 | 1 14
        \\22: 14 14
        \\8: 42
        \\26: 14 22 | 1 20
        \\18: 15 15
        \\7: 14 5 | 1 21
        \\24: 14 1
        \\
        \\abbbbbabbbaaaababbaabbbbabababbbabbbbbbabaaaa
        \\bbabbbbaabaabba
        \\babbbbaabbbbbabbbbbbaabaaabaaa
        \\aaabbbbbbaaaabaababaabababbabaaabbababababaaa
        \\bbbbbbbaaaabbbbaaabbabaaa
        \\bbbababbbbaaaaaaaabbababaaababaabab
        \\ababaaaaaabaaab
        \\ababaaaaabbbaba
        \\baabbaaaabbaaaababbaababb
        \\abbbbabbbbaaaababbbbbbaaaababb
        \\aaaaabbaabaaaaababaa
        \\aaaabbaaaabbaaa
        \\aaaabbaabbaaaaaaabbbabbbaaabbaabaaa
        \\babaaabbbaaabaababbaabababaaab
        \\aabbbbbaabbbaaaaaabbbbbababaaaaabbaaabba
    ;

    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 3), try runPart1(r));

    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 12), try runPart2(r));
}
