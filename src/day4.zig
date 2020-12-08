const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const testing = std.testing;
const expect = testing.expect;
const assert = std.debug.assert;
const print = std.debug.print;
const mem = std.mem;

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return countValidPassports(r, validate, &arena.allocator);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return countValidPassports(r, validateStrict, &arena.allocator);
}

const Passport = struct {
    const Self = @This();

    byr: ?[]const u8 = null,
    iyr: ?[]const u8 = null,
    eyr: ?[]const u8 = null,
    hgt: ?[]const u8 = null,
    hcl: ?[]const u8 = null,
    ecl: ?[]const u8 = null,
    pid: ?[]const u8 = null,
    cid: ?[]const u8 = null,

    fn new() Self {
        return Self{};
    }
};

inline fn validate(p: Passport) bool {
    return (p.byr != null) and (p.iyr != null) and
        (p.eyr != null) and (p.hgt != null) and
        (p.hcl != null) and (p.ecl != null) and
        (p.pid != null);
}

inline fn isBetween(comptime T: type, a: T, min: T, max: T) bool {
    return (min <= a) and (a <= max);
}

fn validateBetween(comptime T: type, y: []const u8, min: T, max: T) bool {
    const num = fmt.parseUnsigned(T, y, 10) catch |_| return false;
    return isBetween(u16, num, min, max);
}

fn validateStrict(p: Passport) bool {
    if (!validate(p)) {
        return false;
    }
    if (!validateBetween(u16, p.byr.?, 1920, 2002)) {
        return false;
    }
    if (!validateBetween(u16, p.iyr.?, 2010, 2020)) {
        return false;
    }
    if (!validateBetween(u16, p.eyr.?, 2020, 2030)) {
        return false;
    }

    const hgt = p.hgt orelse return false;
    const hl = hgt.len;
    if (hl < 3) {
        return false;
    } else if (mem.eql(u8, "cm", hgt[hl - 2 ..])) {
        if (!validateBetween(u8, hgt[0 .. hl - 2], 150, 193)) {
            return false;
        }
    } else if (mem.eql(u8, "in", hgt[hl - 2 ..])) {
        if (!validateBetween(u8, hgt[0 .. hl - 2], 59, 76)) {
            return false;
        }
    } else {
        return false;
    }

    const hcl = p.hcl orelse return false;
    if ((hcl.len != 7) or (hcl[0] != '#')) {
        return false;
    }
    for (hcl[1..]) |c| {
        switch (c) {
            '0'...'9' => {},
            'a'...'f' => {},
            else => return false,
        }
    }

    const pid = p.pid orelse return false;
    if (pid.len != 9) {
        return false;
    }
    for (pid) |c| {
        switch (c) {
            '0'...'9' => {},
            else => return false,
        }
    }

    const ecl = p.ecl orelse return false;
    const validEcl = [_][]const u8{ "amb", "blu", "brn", "gry", "grn", "hzl", "oth" };
    inline for (validEcl) |c| {
        if (mem.eql(u8, c, ecl)) {
            return true;
        }
    }
    return false;
}

fn countValidPassports(r: anytype, isValid: fn (Passport) bool, allocator: *std.mem.Allocator) !usize {
    const maxLineSize = 100;

    var cnt: usize = 0;

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var exitNext = false;
    while (!exitNext) {
        const res = r.readUntilDelimiterAlloc(allocator, '\n', maxLineSize) catch |err| {
            if (err != error.EndOfStream) {
                return err;
            }
            exitNext = true;
        };
        if (res) |act| {
            defer allocator.free(act);
            try buf.appendSlice(act);
            if (act.len != 0) {
                try buf.append(' ');
                continue;
            }
        }

        const line = buf.toOwnedSlice();
        defer allocator.free(line);

        if (!exitNext) {
            buf = std.ArrayList(u8).init(allocator);
            defer buf.deinit();
        }

        const iter: *mem.SplitIterator = &mem.split(line, " ");
        var p = &Passport.new();
        while (iter.next()) |val| {
            const i = mem.indexOf(u8, val, ":") orelse continue;
            if (mem.eql(u8, "byr", val[0..i])) {
                p.byr = val[i + 1 ..];
            }
            if (mem.eql(u8, "iyr", val[0..i])) {
                p.iyr = val[i + 1 ..];
            }
            if (mem.eql(u8, "eyr", val[0..i])) {
                p.eyr = val[i + 1 ..];
            }
            if (mem.eql(u8, "hgt", val[0..i])) {
                p.hgt = val[i + 1 ..];
            }
            if (mem.eql(u8, "hcl", val[0..i])) {
                p.hcl = val[i + 1 ..];
            }
            if (mem.eql(u8, "ecl", val[0..i])) {
                p.ecl = val[i + 1 ..];
            }
            if (mem.eql(u8, "pid", val[0..i])) {
                p.pid = val[i + 1 ..];
            }
            if (mem.eql(u8, "cid", val[0..i])) {
                p.cid = val[i + 1 ..];
            }
        }
        if (isValid(p.*)) {
            cnt += 1;
        }
    }
    return cnt;
}

test "check valid example" {
    const passList =
        \\ecl:gry pid:860033327 eyr:2020 hcl:#fffffd
        \\byr:1937 iyr:2017 cid:147 hgt:183cm
        \\
        \\iyr:2013 ecl:amb cid:350 eyr:2023 pid:028048884
        \\hcl:#cfa07d byr:1929
        \\
        \\hcl:#ae17e1 iyr:2013
        \\eyr:2024
        \\ecl:brn pid:760753108 byr:1931
        \\hgt:179cm
        \\
        \\hcl:#cfa07d eyr:2025 pid:166559648
        \\iyr:2011 ecl:brn hgt:59in
        \\
    ;
    var r = io.fixedBufferStream(passList).reader();
    const cnt = try countValidPassports(r, validate, testing.allocator);
    testing.expect(2 == cnt);
}

test "check valid example (part 2)" {
    const passList =
        \\eyr:1972 cid:100
        \\hcl:#18171d ecl:amb hgt:170 pid:186cm iyr:2018 byr:1926
        \\
        \\iyr:2019
        \\hcl:#602927 eyr:1967 hgt:170cm
        \\ecl:grn pid:012533040 byr:1946
        \\
        \\hcl:dab227 iyr:2012
        \\ecl:brn hgt:182cm pid:021572410 eyr:2020 byr:1992 cid:277
        \\
        \\hgt:59cm ecl:zzz
        \\eyr:2038 hcl:74454a iyr:2023
        \\pid:3556412378 byr:2007
        \\
        \\pid:087499704 hgt:74in ecl:grn iyr:2012 eyr:2030 byr:1980
        \\hcl:#623a2f
        \\
        \\eyr:2029 ecl:blu cid:129 byr:1989
        \\iyr:2014 pid:896056539 hcl:#a97842 hgt:165cm
        \\
        \\hcl:#888785
        \\hgt:164cm byr:2001 iyr:2015 cid:88
        \\pid:545766238 ecl:hzl
        \\eyr:2022
        \\
        \\iyr:2010 hgt:158cm hcl:#b6652a ecl:blu byr:1944 eyr:2021 pid:093154719
        \\
    ;

    var r = io.fixedBufferStream(passList).reader();
    const cnt = try countValidPassports(r, validateStrict, testing.allocator);
    testing.expect(4 == cnt);
}
