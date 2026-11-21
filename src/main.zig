const std = @import("std");
const Io = std.Io;

const Figure = @import("figure.zig").Figure;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var fig = Figure.init(io, gpa, .{.term = "windows", .width = 1024, .height = 750});
    defer fig.deinit();

    const x = [_]i32{1, 2, 3, 4, 5};
    const y = [_]i32{1, 2, 3, 4, 5};
    const y2 = [_]i32{-1, -2, -3, -4, -5};
    try fig.xlabel("x", .{});
    try fig.ylabel("y", .{});
    try fig.grid();
    try fig.plot(&x, &y, .{.label = "line 1"});
    try fig.scatter(&x, &y, .{.label = "points 1", .color = "red"});
    try fig.plot(&x, &y2, .{.label = "line2"});
    try fig.show();
}

