usingnamespace @import("util.zig");

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return runProgram(r, &arena.allocator, writeWithValueMask);
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    return runProgram(r, &arena.allocator, writeWithAddressMask);
}

const Mask = struct {
    one: u36,
    zero: u36,
};

const MemPut = struct {
    index: u36,
    value: u36,
};

const Instruction = union(enum) {
    Mask: Mask,
    Mem: MemPut,
};

fn writeWithValueMask(mask: Mask, inst: MemPut, m: *std.AutoHashMap(u36, u36)) !void {
    var gp = try m.getOrPut(inst.index);
    const val = (inst.value | mask.one) & ~mask.zero;
    gp.entry.value = val;
}

// widen sets zero bits of b to the consecutive bits of a.
// Examples:
//    widen(0b101, 0b001101) = 0b101111
//    widen(0b011, 0b001101) = 0b011111
//    widen(0b110, 0b001101) = 0b111101
fn widen(a: u36, b: u36) u36 {
    var acc = b;
    var ai: u6 = 0;
    var bi: u6 = 0;

    // Note: making b comptime and inlining this while generates invalid code.
    // I haven't figured out why.
    while (bi < 36) {
        const mask: u36 = (@as(u36, 1) << bi);
        if (b & mask == 0) {
            if (a & (@as(u36, 1) << ai) == 0) {
                acc &= ~mask;
            } else {
                acc |= mask;
            }
            ai += 1;
        }
        bi += 1;
    }
    return acc;
}

fn writeWithAddressMask(mask: Mask, inst: MemPut, m: *std.AutoHashMap(u36, u36)) !void {
    const bits = mask.one | mask.zero;
    const size = 36 - @popCount(u36, bits);
    const base_addr: u36 = inst.index | mask.one;

    var i: u36 = 0;
    while (i < (@as(u36, 1) << size)) {
        const w: u36 = widen(i, bits);
        const one: u36 = w & ~bits;
        const addr: u36 = (base_addr | one) & w;
        // As of v0.7.0 removing this line somehow messes with a later call to `iterator()`
        // so value is "appended" instead of being replaced.
        _ = m.remove(addr);
        try m.put(addr, inst.value);
        i += 1;
    }
}

fn runProgram(r: anytype, a: *Allocator, f: anytype) !usize {
    var m = std.AutoHashMap(u36, u36).init(a);
    defer m.deinit();

    var mask = Mask{
        .one = 0,
        .zero = math.maxInt(u36),
    };
    var buf: [100]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
        const inst = try parseInstruction(line);
        switch (inst) {
            .Mask => mask = inst.Mask,
            .Mem => try f(mask, inst.Mem, &m),
        }
    }

    var sum: usize = 0;
    var it = m.iterator();
    while (it.next()) |kv| {
        sum += @as(usize, kv.value);
    }
    return sum;
}

fn parseInstruction(s: []const u8) !Instruction {
    if (mem.startsWith(u8, s, "mask = ")) {
        var one: u36 = 0;
        var zero: u36 = 0;
        for (s[7..]) |c, i| {
            switch (c) {
                '1' => one |= @as(u36, 1) << (35 - @intCast(u6, i)),
                '0' => zero |= @as(u36, 1) << (35 - @intCast(u6, i)),
                'X' => {},
                else => return error.InvalidInstruction,
            }
        }
        return Instruction{
            .Mask = .{
                .one = one,
                .zero = zero,
            },
        };
    }

    // Assume this is `mem` instruction.
    // Don't perform full validation, because input is well formed.
    const last = mem.indexOf(u8, s, "]") orelse return error.InvalidInstruction;
    const index = try fmt.parseUnsigned(u36, s[4..last], 10);
    const value = try fmt.parseUnsigned(u36, s[last + 4 ..], 10);
    return Instruction{
        .Mem = .{
            .index = index,
            .value = value,
        },
    };
}

test "part 1" {
    const prog =
        \\mask = XXXXXXXXXXXXXXXXXXXXXXXXXXXXX1XXXX0X
        \\mem[8] = 11
        \\mem[7] = 101
        \\mem[8] = 0
    ;
    var r = io.fixedBufferStream(prog).reader();
    expectEqual(@as(usize, 165), try runPart1(r));
}

test "part 2" {
    const prog =
        \\mask = 000000000000000000000000000000X1001X
        \\mem[42] = 100
        \\mask = 00000000000000000000000000000000X0XX
        \\mem[26] = 1
    ;
    var r = io.fixedBufferStream(prog).reader();
    expectEqual(@as(usize, 208), try runPart2(r));
}

test "widen" {
    expectEqual(@as(u36, 0b101111), widen(0b101, 0b001101));
    expectEqual(@as(u36, 0b011111), widen(0b011, 0b001101));
    expectEqual(@as(u36, 0b111101), widen(0b110, 0b001101));
}
