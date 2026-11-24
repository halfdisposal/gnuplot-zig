# A Lightweight Gnuplot Wrapper in Zig - inspired by Matplotlib API
*Why??*

*I just love exploring languages and their ecosystem, particularly in numerical analysis and simulations, yeah its a wierd enough reason. But exploring zig I couldn't find a gnuplot wapper with api I like, so as a dev does, I made one... The api is similar to matplotlib from Python. Although technically this packages is just a wrapper to convert the passed arrays and options into the command strings, but it does its job. Doesn't have much here as it is pretty simple to use. The below example demonstrate the features*

# Installation
Fetch the repo
```bash
zig fetch --save git+https://github.com/halfdisposal/gnuplot-zig.git#HEAD
```
Include it in the `build.zig`
```zig
const gnuplot_dep = b.dependency("gnuplot_zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("gnuplot", gnuplot_dep.module("gnuplot_zig"));
```

# Usage
## Example
```zig
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
```
![gnuplot-zig example plot](fig.png)

Each plot command is accompanied by a struct with options for the plot. Currently only 2D line and scatter plot are supported.
**Saving To File**
```zig
try fig.savefig("file.png");
```
Supported Files `png, jpg, jpeg, svg, pdf, gif, eps`

# Features
- **Lazy Evaluation**: No Commands (gnuplot side) is evaluated unless `fig.show()` is called.

I will try to keep the api as similar as possible to *matplotlib*, atleast where ever possible. 
