usingnamespace @import("util.zig");

const ParseError = error{
    LineTooLong,
    InvalidNumber,
};

// Note: this solution is not scalable.
// The point was to become more acquainted with compiler builtins.
fn fill(r: anytype) !u2021 {
    var acc: u2021 = 0;
    var line_buf: [5]u8 = undefined;
    while (true) {
        const buf = (try r.readUntilDelimiterOrEof(&line_buf, '\n')) orelse return acc;
        const num = try fmt.parseUnsigned(u11, buf, 10);
        acc |= @as(u2021, 1) << num;
    }
}

pub fn runPart1(r: anytype) !usize {
    const s = try fill(r);
    const rev = s & @bitReverse(u2021, s);
    const no: usize = @ctz(u2021, rev);
    const result = no * (2020 - no);
    return result;
}

inline fn bitSet(s: u2021, i: u11) bool {
    return s & (@as(u2021, 1) << i) != 0;
}

pub fn runPart2(r: anytype) !usize {
    const s = try fill(r);
    var i: u11 = 0;
    while (i < 2021) {
        if (bitSet(s, i)) {
            var j = i + 1;
            while (j < 2021) {
                if (bitSet(s, j) and (@as(usize, i) + j <= 2020)) {
                    const rem = 2020 - i - j;
                    if (bitSet(s, rem)) {
                        return @as(usize, i) * j * rem;
                    }
                }
                j += 1;
            }
        }
        i += 1;
    }
    return error.NotFound;
}

test "test fill" {
    const buf = "123\n456\n3\n12\n";
    var r = io.fixedBufferStream(buf).reader();
    const res = try fill(r);
    testing.expect(4 == @popCount(u2021, res));
    testing.expect(res & (1 << 3) != 0);
    testing.expect(res & (1 << 12) != 0);
    testing.expect(res & (1 << 123) != 0);
    testing.expect(res & (1 << 456) != 0);
}
