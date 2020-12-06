const std = @import("std");
const io = std.io;
const day1 = @import("src/day1.zig");
const day2 = @import("src/day2.zig");
const day3 = @import("src/day3.zig");
const day4 = @import("src/day4.zig");
const day5 = @import("src/day5.zig");
const day6 = @import("src/day6.zig");

var stdin = std.io.getStdIn().reader();
var stdout = std.io.getStdOut().writer();

pub fn main() anyerror!void {
    //const result = try day1.runPart1(stdin);
    //const result = try day1.runPart2(stdin);
    //const result = try day2.runPart1(stdin);
    //const result = try day2.runPart2(stdin);
    //const result = try day3.runPart1(stdin);
    //const result = try day3.runPart2(stdin);
    //const result = try day4.runPart1(stdin);
    //const result = try day4.runPart2(stdin);
    //const result = try day5.runPart1(stdin);
    //const result = try day5.runPart2(stdin);
    //const result = try day6.runPart1(stdin);
    const result = try day6.runPart2(stdin);
    try stdout.print("{}\n", .{result});
}
