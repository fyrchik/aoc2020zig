const std = @import("std");
const io = std.io;
const day1 = @import("src/day1.zig");
const day2 = @import("src/day2.zig");
const day3 = @import("src/day3.zig");
const day4 = @import("src/day4.zig");
const day5 = @import("src/day5.zig");
const day6 = @import("src/day6.zig");
const day7 = @import("src/day7.zig");
const day8 = @import("src/day8.zig");
const day9 = @import("src/day9.zig");
const day10 = @import("src/day10.zig");
const day11 = @import("src/day11.zig");
const day12 = @import("src/day12.zig");
const day13 = @import("src/day13.zig");
const day14 = @import("src/day14.zig");
const day15 = @import("src/day15.zig");
const day16 = @import("src/day16.zig");
const day17 = @import("src/day17.zig");
const day18 = @import("src/day18.zig");
const day19 = @import("src/day19.zig");
const day20 = @import("src/day20.zig");
const day22 = @import("src/day22.zig");
const day24 = @import("src/day24.zig");

var stdin = std.io.getStdIn().reader();
var stdout = std.io.getStdOut().writer();

pub fn main() anyerror!void {
    const result = try day22.runPart2(stdin);
    try stdout.print("{}\n", .{result});
}
