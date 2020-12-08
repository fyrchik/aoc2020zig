const std = @import("std");
const io = std.io;
const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;

pub fn runPart1(r: anytype) !usize {
    return countAnswers(r, 0, opOr);
}

pub fn runPart2(r: anytype) !usize {
    return countAnswers(r, ~@as(u26, 0), opAnd);
}

inline fn opOr(a: u26, b: u26) u26 {
    return a | b;
}

inline fn opAnd(a: u26, b: u26) u26 {
    return a & b;
}

fn countAnswers(r: anytype, start: u26, comptime op: fn (u26, u26) u26) !usize {
    var sum: usize = 0;
    var acc: u26 = start;
    var buf: [27]u8 = undefined;
    var seen = false;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse {
            return sum + (if (seen) @popCount(u26, acc) else 0);
        };
        if (line.len != 0) {
            seen = true;
            acc = op(acc, try parseForm(line));
            continue;
        }
        sum += @popCount(u26, acc);
        seen = false;
        acc = start;
    }
}

fn parseForm(s: []const u8) !u26 {
    var acc: u26 = 0;
    for (s) |c| {
        switch (c) {
            'a'...'z' => acc |= (@as(u26, 1) << @truncate(u5, c - 'a')),
            else => return error.InvalidForm,
        }
    }
    return acc;
}

test "count answers" {
    var formList =
        \\abc
        \\
        \\a
        \\b
        \\c
        \\
        \\ab
        \\ac
        \\
        \\a
        \\a
        \\a
        \\a
        \\
        \\b
        \\
    ;
    var r = io.fixedBufferStream(formList).reader();
    expect(11 == try countAnswers(r, 0, opOr));

    // part2
    r = io.fixedBufferStream(formList).reader();
    expect(6 == try countAnswers(r, ~@as(u26, 0), opAnd));
}

test "parse form" {
    expect(0b1000100110 == try parseForm("bcfj"));
    expectError(error.InvalidForm, parseForm("bcdef1h"));
}
