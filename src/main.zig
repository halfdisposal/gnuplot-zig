const std = @import("std");
const Io = std.Io;

const g = @import("figure.zig");
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
    try fig.plot(&x, &y, .{.label = "line 1", .points = true});
    try fig.scatter(&x, &y, .{.label = "points 1", .color = "red"});
    try fig.plot(&x, &y2, .{.label = "line2"});
    try fig.show();
    
    // const image = [_]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    // try fig.imshow(&image, 4, 3, .{.cblabel = "label"});
    // try fig.axis("off");
    // try fig.show();

    const x2 = [_]f32{0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0};
    try fig.bar(&x2, .{.ticks = &.{"A", "B", "C"}, .color = "#ff00ef"});
    try fig.ylim(0.0, 11.0);
    try fig.xreverse();
    try fig.show();
}

