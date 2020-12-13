# Advent of Code 2020 solutions in Zig
## Structure
`main.zig` contains code for main runner.

`src/dayX.zig` contain solutions for each day.
Every file has 2 public functions `runPart1` and `runPart2` for parts 1 and 2 respectively.

## Run
1. Change needed day in `main.zig`.
2. `cat input | zig build run`.
## Test
`zig test src/dayX.zig`

At some point tests are written only for examples, because I had no time.
