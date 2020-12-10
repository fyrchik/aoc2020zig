usingnamespace @import("util.zig");

fn fromBinary(
    comptime T: type,
    s: [@typeInfo(T).Int.bits]u8,
    comptime bit0: u8,
    comptime bit1: u8,
) !T {
    var num: T = 0;
    comptime var sz = @typeInfo(T).Int.bits;
    comptime var i = 0;
    inline while (i < sz) {
        switch (s[i]) {
            bit0 => {},
            bit1 => num |= (1 << (sz - i - 1)),
            else => return error.InvalidBoardingPass,
        }
        i += 1;
    }
    return num;
}

fn parseSeatID(s: []const u8) !u10 {
    if (s.len < 9) {
        return error.InvalidBoardingPass;
    }
    const row = try fromBinary(u7, s[0..7].*, 'F', 'B');
    const column = try fromBinary(u3, s[7..10].*, 'L', 'R');
    return (@as(u10, row) << 3) + @as(u10, column);
}

pub fn runPart1(r: anytype) !u10 {
    const sz = @typeInfo(u10).Int.bits;

    var buf: [sz]u8 = undefined;
    var max: u10 = 0;
    while (true) {
        var line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return max;
        if (line.len != sz) {
            return error.InvalidBoardingPass;
        }

        const id = try parseSeatID(line[0..sz]);
        if (id > max) {
            max = id;
        }
    }
}

pub fn runPart2(r: anytype) !u10 {
    const sz = @typeInfo(u10).Int.bits;

    var buf: [sz]u8 = undefined;
    var sum: u20 = 0;
    var min: u10 = std.math.maxInt(u10);
    var max: u10 = 0;
    while (true) {
        var line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse {
            const to_min: u20 = @as(u20, min) * (@as(u20, min) - 1) >> 1; // don't include min
            const to_max: u20 = @as(u20, max) * (@as(u20, max) + 1) >> 1; // include max
            const expected: u20 = to_max - to_min;
            return @truncate(u10, expected - sum);
        };
        if (line.len != sz) {
            return error.InvalidBoardingPass;
        }

        const id = try parseSeatID(line[0..sz]);
        sum += @as(u20, id);
        if (id < min) {
            min = id;
        } else if (id > max) {
            max = id;
        }
    }
}

test "parse seat id" {
    testing.expectEqual(@as(u10, 567), try parseSeatID("BFFFBBFRRR"));
    testing.expectEqual(@as(u10, 119), try parseSeatID("FFFBBBFRRR"));
    testing.expectEqual(@as(u10, 820), try parseSeatID("BBFFBBFRLL"));
}
