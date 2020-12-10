usingnamespace @import("util.zig");

const Policy = struct {
    letter: u21,
    min: usize,
    max: usize,
};

pub fn runPart1(r: anytype) !usize {
    return countValid(r, isValid1);
}

pub fn runPart2(r: anytype) !usize {
    return countValid(r, isValid2);
}

fn countValid(r: anytype, check: fn ([]const u8, Policy) bool) !usize {
    var cnt: usize = 0;
    var line_buf: [100]u8 = undefined;
    while (true) {
        const buf = (try r.readUntilDelimiterOrEof(&line_buf, '\n')) orelse return cnt;
        const pp = try parsePolicy(buf);
        cnt += @boolToInt(check(pp.password, pp.policy));
    }
}

fn isValid1(pass: []const u8, p: Policy) bool {
    var cnt: usize = 0;
    var iter = &unicode.Utf8Iterator{
        .bytes = pass,
        .i = 0,
    };
    while (iter.nextCodepoint()) |c| {
        if (c == p.letter) {
            cnt += 1;
        }
    }
    return (p.min <= cnt) and (cnt <= p.max);
}

fn isValid2(pass: []const u8, p: Policy) bool {
    var cnt: u2 = 0;
    var iter = &unicode.Utf8Iterator{
        .bytes = pass,
        .i = 0,
    };
    var i: usize = 0;
    while (iter.nextCodepoint()) |c| {
        i += 1;
        if ((i == p.min) or (i == p.max)) {
            cnt += @boolToInt(c == p.letter);
        }
    }
    return cnt == 1;
}

const PassWithPolicy = struct {
    policy: Policy,
    password: []const u8,
};

fn parsePolicy(raw: []const u8) !PassWithPolicy {
    const iter: *mem.SplitIterator = &mem.split(raw, " ");
    const minMax = iter.next() orelse return error.InvalidFormat;

    const i = mem.indexOf(u8, minMax, "-") orelse return error.InvalidFormat;
    const min = fmt.parseUnsigned(usize, minMax[0..i], 10) catch return error.InvalidFormat;
    const max = fmt.parseUnsigned(usize, minMax[i + 1 ..], 10) catch return error.InvalidFormat;

    const rawLetter = iter.next() orelse return error.InvalidFormat;
    if ((rawLetter.len <= 1) or (rawLetter[rawLetter.len - 1] != ':')) {
        return error.InvalidFormat;
    }
    const letter = try unicode.utf8Decode(rawLetter[0 .. rawLetter.len - 1]);
    const pass = iter.next() orelse return error.InvalidFormat;
    return PassWithPolicy{
        .policy = Policy{
            .letter = letter,
            .min = min,
            .max = max,
        },
        .password = pass,
    };
}

test "parse policy" {
    var p = try parsePolicy("3-11 z: zzzzzdzzzzlzz");
    expect(p.policy.min == 3);
    expect(p.policy.max == 11);
    expect(p.policy.letter == 'z');
    expect(mem.eql(u8, "zzzzzdzzzzlzz", p.password));

    // non-ASCII letter
    p = try parsePolicy("2-4 Ж: zzzzzdzzzzlzz");
    expect(p.policy.min == 2);
    expect(p.policy.max == 4);
    expect(p.policy.letter == 'Ж');
    expect(mem.eql(u8, "zzzzzdzzzzlzz", p.password));

    // errors
    testing.expectError(error.InvalidFormat, parsePolicy("2- a: aa"));
    testing.expectError(error.InvalidFormat, parsePolicy("-3 a: aa"));
    testing.expectError(error.InvalidFormat, parsePolicy("2-3 : aa"));
    testing.expectError(error.InvalidFormat, parsePolicy("2- a:"));
}

test "check password (part 1)" {
    // ASCII
    const pa = Policy{ .letter = 'a', .min = 1, .max = 3 };
    expect(isValid1("abcd", pa));
    expect(isValid1("abad", pa));
    expect(isValid1("abaadn", pa));
    expect(!isValid1("abaadn", Policy{ .letter = 'a', .min = 1, .max = 2 }));

    // non-ASCII
    const p = Policy{ .letter = 'ж', .min = 1, .max = 2 };
    expect(isValid1("просто ж", p));
    expect(!isValid1("жжж", p));
}

test "check password (part 2)" {
    // ASCII
    const pa = Policy{ .letter = 'a', .min = 1, .max = 3 };
    expect(isValid2("abcd", pa));
    expect(!isValid2("abad", pa));
    expect(isValid2("bbaadn", pa));
    expect(!isValid2("bbbadn", pa));

    // non-ASCII
    const p = Policy{ .letter = 'ж', .min = 1, .max = 2 };
    expect(!isValid2("просто ж", p));
    expect(!isValid2("жжж", p));
    expect(isValid2("уж", p));
}
