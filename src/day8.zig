const std = @import("std");
const mem = std.mem;
const io = std.io;
const fmt = std.fmt;

const print = std.debug.print;
const assert = std.debug.assert;

const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

const Allocator = mem.Allocator;

pub fn runPart1(r: anytype) !isize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var v = try Vm.load(r, &arena.allocator);
    return v.run();
}

pub fn runPart2(r: anytype) !isize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var v = try Vm.load(r, &arena.allocator);
    return v.fixAndRun();
}

const Vm = struct {
    const Self = @This();
    const Opcode = enum {
        Nop,
        Acc,
        Jmp,
    };
    const Instruction = struct {
        opcode: Opcode,
        arg: isize,
    };

    allocator: *Allocator,
    prog: []Instruction,
    acc: isize = 0,

    fn load(r: anytype, a: *Allocator) !Self {
        var prog = try parseProgram(r, a);
        return Self{
            .allocator = a,
            .prog = prog,
        };
    }

    fn deinit(s: *Self) void {
        s.allocator.free(s.prog);
    }

    const initial_tag = -1;
    const current_orbit = -2;

    fn fixAndRun(s: *Self) !isize {
        var tags = try s.allocator.alloc(isize, s.prog.len);
        defer s.allocator.free(tags);
        mem.set(isize, tags, initial_tag);

        const final_tag = try s.tagInstructions(tags);

        var seen = try s.allocator.alloc(bool, s.prog.len);
        defer s.allocator.free(seen);

        _ = try s.runInternal(seen);

        for (s.prog) |inst, i| {
            if (!seen[i]) {
                continue;
            }
            switch (inst.opcode) {
                .Jmp => if ((i == s.prog.len - 1) or (tags[i + 1] == final_tag)) {
                    // A `jmp` right before the instruction on a correct execution path.
                    s.prog[i].opcode = .Nop;
                    break;
                },
                .Nop => {
                    const tgt = @intCast(isize, i) + inst.arg;
                    if ((tgt == s.prog.len) or ((tgt < s.prog.len) and (tags[@intCast(usize, tgt)] == final_tag))) {
                        // A `nop` with the argument pointing at the instruction on a correct execution path.
                        s.prog[i].opcode = .Jmp;
                        break;
                    }
                },
                else => {},
            }
        }

        return try s.runInternal(seen);
    }

    // Each instruction either participates in a single loop
    // because there are no data-dependencies or in an execution
    // which finishes normally.
    // We assign to each instruction a unique tag which depends
    // on execution path started at this instruction.
    // Correct execution path is the path with finishes right after the
    // last instruction. All instruction participating in correct
    // execution paths are assigned with the same tag.
    fn tagInstructions(s: *Self, tags: []isize) !isize {
        var final_tag: isize = -1;
        var path = std.ArrayList(usize).init(s.allocator);
        defer path.deinit();

        for (s.prog) |_, start| {
            if (tags[start] >= 0) {
                continue;
            }

            const pos = try s.executeUntilTag(start, &path, tags, &final_tag);

            var tag: isize = undefined;
            if (pos == s.prog.len) {
                tag = final_tag;
            } else if ((pos < s.prog.len) and (tags[pos] != current_orbit)) {
                tag = tags[pos];
            } else {
                tag = @intCast(isize, start);
            }

            for (path.items) |index| {
                tags[index] = tag;
            }
            path.shrink(0);
        }
        return final_tag;
    }

    // executes program from start until already encountered tag is found or finish.
    fn executeUntilTag(s: *Self, start: usize, path: *std.ArrayList(usize), tags: []isize, final_tag: *isize) !usize {
        var pos: usize = start;
        while (true) {
            if (tags[pos] != initial_tag) {
                break;
            }
            try path.append(pos);
            tags[pos] = current_orbit;
            pos = try s.step(pos);
            if (pos < s.prog.len) {
                continue;
            }
            if ((pos == s.prog.len) and (final_tag.* == -1)) {
                final_tag.* = @intCast(isize, start);
            }
            break;
        }
        return pos;
    }

    // runs program and returns accumulator value.
    fn run(s: *Self) !isize {
        var seen = try s.allocator.alloc(bool, s.prog.len);
        defer s.allocator.free(seen);

        return s.runInternal(seen);
    }

    fn runInternal(s: *Self, seen: []bool) !isize {
        var pos: usize = 0;

        mem.set(bool, seen, false);
        s.acc = 0;
        while (true) {
            if ((pos >= s.prog.len) or seen[pos]) {
                return s.acc;
            }
            seen[pos] = true;
            pos = try s.step(pos);
        }
    }

    // executes a single opcode.
    inline fn step(s: *Self, pos: usize) !usize {
        const inst = s.prog[pos];
        switch (inst.opcode) {
            .Nop => return pos + 1,
            .Acc => {
                s.acc += inst.arg;
                return pos + 1;
            },
            .Jmp => {
                const next = @intCast(isize, pos) + inst.arg;
                if (next < 0) {
                    return error.InvalidJumpTarget;
                }
                return @intCast(usize, next);
            },
        }
    }

    // parseProgram reads program from r and returns an array of instructions.
    // Caller owns returned slice.
    fn parseProgram(r: anytype, a: *Allocator) ![]Vm.Instruction {
        var prog = std.ArrayList(Vm.Instruction).init(a);
        defer prog.deinit();

        var buf: [20]u8 = undefined;
        while (true) {
            const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse break;
            const inst = try parseInstruction(line);
            try prog.append(inst);
        }
        return prog.toOwnedSlice();
    }

    inline fn parseInstruction(s: []const u8) !Vm.Instruction {
        var op: Vm.Opcode = undefined;
        if (mem.eql(u8, "nop", s[0..3])) {
            op = .Nop;
        } else if (mem.eql(u8, "acc", s[0..3])) {
            op = .Acc;
        } else if (mem.eql(u8, "jmp", s[0..3])) {
            op = .Jmp;
        } else {
            return error.InvalidOpcode;
        }

        const num = fmt.parseInt(isize, s[4..], 10) catch |_| return error.InvalidArgument;
        return Vm.Instruction{
            .opcode = op,
            .arg = num,
        };
    }
};

fn testParse(s: []const u8, op: Vm.Opcode, arg: isize) void {
    const inst = Vm.parseInstruction(s) catch unreachable;
    expectEqual(op, inst.opcode);
    expectEqual(arg, inst.arg);
}

test "parse instruction" {
    testParse("nop +0", .Nop, 0);
    testParse("acc +1", .Acc, 1);
    testParse("jmp +4", .Jmp, 4);
    testParse("acc +3", .Acc, 3);
    testParse("jmp -3", .Jmp, -3);
    testParse("acc -99", .Acc, -99);
    testParse("acc +1", .Acc, 1);
    testParse("jmp -4", .Jmp, -4);
    testParse("acc +6", .Acc, 6);
}

test "load program" {
    const prog =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\jmp -4
        \\acc +6
    ;
    var r = io.fixedBufferStream(prog).reader();
    var v = try Vm.load(r, testing.allocator);
    defer v.deinit();

    const result = try v.run();
    expectEqual(@as(isize, 5), result);

    const after_fix = try v.fixAndRun();
    expectEqual(@as(isize, 8), after_fix);
}

test "tagInstructions" {
    const prog =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\jmp -4
        \\acc +6
    ;
    var r = io.fixedBufferStream(prog).reader();
    var v = try Vm.load(r, testing.allocator);
    defer v.deinit();

    var tags = try testing.allocator.alloc(isize, v.prog.len);
    defer testing.allocator.free(tags);
    mem.set(isize, tags, -1);

    const final_tag = try v.tagInstructions(tags);
    expectEqual(@as(isize, 8), final_tag);
    expectEqual(@as(isize, 0), tags[0]);
    expectEqual(@as(isize, 0), tags[1]);
    expectEqual(@as(isize, 0), tags[2]);
    expectEqual(@as(isize, 0), tags[3]);
    expectEqual(@as(isize, 0), tags[4]);
    expectEqual(@as(isize, 0), tags[5]);
    expectEqual(@as(isize, 0), tags[6]);
    expectEqual(@as(isize, 0), tags[7]);
    expectEqual(@as(isize, 8), tags[8]);
}
