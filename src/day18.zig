usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    return run(r, false);
}

pub fn runPart2(r: anytype) !usize {
    return run(r, true);
}

fn run(r: anytype, with_precedence: bool) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buf: [1000]u8 = undefined;
    var sum: usize = 0;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        var p = Evaluator().init(line, with_precedence);
        sum += try p.calculate(&arena.allocator);
    }
    return sum;
}

fn Evaluator() type {
    return struct {
        const Self = @This();

        stack_size: usize,
        str: []const u8,
        pos: usize,
        with_precedence: bool,

        const Token = union(enum) {
            Number: usize,
            AddOp,
            MulOp,
            OpenBrace,
            CloseBrace,
            End,
        };

        fn init(s: []const u8, with_precedence: bool) Self {
            return Self{
                .stack_size = 0,
                .str = s,
                .pos = 0,
                .with_precedence = with_precedence,
            };
        }

        fn calculate(s: *Self, a: *Allocator) anyerror!usize {
            var st = ArrayList(Token).init(a);
            defer st.deinit();

            var ops = ArrayList(Token).init(a);
            defer ops.deinit();

            while (true) {
                const tok = try s.nextToken();
                switch (tok) {
                    .OpenBrace => {
                        const num = try s.calculate(a);
                        try st.append(Token{ .Number = num });
                    },
                    .Number => try st.append(tok),
                    .MulOp => {
                        while (ops.popOrNull()) |v| {
                            try st.append(v);
                        }
                        try ops.append(tok);
                    },
                    .AddOp => {
                        while (ops.popOrNull()) |v| {
                            if (!s.with_precedence or v == .AddOp) {
                                try st.append(v);
                            } else {
                                try ops.append(v);
                                break;
                            }
                        }
                        try ops.append(tok);
                    },
                    .End, .CloseBrace => {
                        while (ops.popOrNull()) |op| {
                            try st.append(op);
                        }
                        return popNumber(&st);
                    },
                }
            }
        }

        fn popNumber(s: *ArrayList(Token)) anyerror!usize {
            const tok = s.popOrNull() orelse return error.EmptyStack;
            switch (tok) {
                .Number => return tok.Number,
                .AddOp => {
                    const a = try popNumber(s);
                    const b = try popNumber(s);
                    return a + b;
                },
                .MulOp => {
                    const a = try popNumber(s);
                    const b = try popNumber(s);
                    return a * b;
                },
                else => unreachable,
            }
        }

        fn nextToken(s: *Self) !Token {
            var num: usize = 0;
            var startNum = false;
            while (s.pos < s.str.len) switch (s.str[s.pos]) {
                '0'...'9' => {
                    startNum = true;
                    num = num * 10 + @as(usize, s.str[s.pos] - '0');
                    s.pos += 1;
                },
                else => {
                    if (startNum) {
                        return Token{ .Number = num };
                    }
                    s.pos += 1;
                    switch (s.str[s.pos - 1]) {
                        ' ' => {},
                        '+' => return Token.AddOp,
                        '*' => return Token.MulOp,
                        '(' => {
                            s.stack_size += 1;
                            return Token.OpenBrace;
                        },
                        ')' => {
                            if (s.stack_size == 0) {
                                return error.InvalidInput;
                            }
                            s.stack_size -= 1;
                            return Token.CloseBrace;
                        },
                        else => return error.InvalidInput,
                    }
                },
            };
            if (startNum) {
                return Token{ .Number = num };
            }
            return Token.End;
        }
    };
}

test "part 1" {
    var input: []const u8 = "1 + 2 * 3 + 4 * 5 + 6";
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 71), try runPart1(r));

    input = "2 * 3 + (4 * 5)";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 26), try runPart1(r));

    input = "5 + (8 * 3 + 9 + 3 * 4 * 3)";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 437), try runPart1(r));

    input = "5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 12240), try runPart1(r));

    input = "((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 13632), try runPart1(r));
}

test "part 2" {
    var input: []const u8 = "1 + 2 * 3 + 4 * 5 + 6";
    var r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 231), try runPart2(r));

    input = "2 * 3 + (4 * 5)";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 46), try runPart2(r));

    input = "5 + (8 * 3 + 9 + 3 * 4 * 3)";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 1445), try runPart2(r));

    input = "5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 669060), try runPart2(r));

    input = "((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2";
    r = io.fixedBufferStream(input).reader();
    expectEqual(@as(usize, 23340), try runPart2(r));
}
