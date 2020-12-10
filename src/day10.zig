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

pub fn runPart1(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var nums = try readInts(r, &arena.allocator);
    std.sort.sort(usize, nums, {}, usizeCmpLessThan);

    var diffs = [_]usize{ 0, 0, 0, 0 };
    for (nums[1..]) |n, i| {
        const diff = n - nums[i];
        diffs[diff] += 1;
    }

    return diffs[1] * (diffs[3] + 1); // + my adapter
}

pub fn runPart2(r: anytype) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var nums = try readInts(r, &arena.allocator);
    std.sort.sort(usize, nums, {}, usizeCmpLessThan);

    var arrangements = try arena.allocator.alloc(usize, nums.len);
    mem.set(usize, arrangements, 0);
    arrangements[arrangements.len - 1] = 1;

    var i = nums.len - 2;
    while (true) {
        const curr = nums[i];
        // for loop works if there are different adapters with the same joltage.
        for (nums[i + 1 ..]) |n, j| {
            if (n - curr <= 3) {
                arrangements[i] += arrangements[i + 1 + j];
            } else {
                break;
            }
        }
        if (i == 0) {
            break;
        }
        i -= 1;
    }
    return arrangements[0];
}

// Reads a list of integers from r.
// Caller owns returned slice.
fn readInts(r: anytype, a: *Allocator) ![]usize {
    var lst = std.ArrayList(usize).init(a);
    defer lst.deinit();

    try lst.append(0);

    var sum: usize = 0;
    var buf: [10]u8 = undefined;
    while (true) {
        const line = (try r.readUntilDelimiterOrEof(&buf, '\n')) orelse return lst.toOwnedSlice();
        const num = try fmt.parseUnsigned(usize, line, 10);
        try lst.append(num);
    }
}

fn usizeCmpLessThan(context: void, a: usize, b: usize) bool {
    return a < b;
}

test "part 1, example 1" {
    const buf = "16\n10\n15\n5\n1\n11\n7\n19\n6\n12\n4";
    var r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 35), try runPart1(r));

    r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 8), try runPart2(r));
}

test "part 1, example 2" {
    const buf = "28\n33\n18\n42\n31\n14\n46\n20\n48\n47\n24\n23\n49\n45\n19\n38\n39\n11\n1\n32\n25\n35\n8\n17\n7\n9\n4\n2\n34\n10\n3";
    var r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 220), try runPart1(r));

    r = io.fixedBufferStream(buf).reader();
    expectEqual(@as(usize, 19208), try runPart2(r));
}
