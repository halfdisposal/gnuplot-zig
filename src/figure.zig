const std = @import("std");
const Io = std.Io;

pub fn is_string(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| switch (ptr.size) {
            .slice => ptr.child == u8,
            .one => switch (@typeInfo(ptr.child)) {
                .array => |arr| arr.child == u8,
                else => false,
            },
            else => false,
        },
        .array => |arr| arr.child == u8,
        else => false,
    };
}

pub fn check_type(data: anytype) bool {
    // std.debug.print("Data Info: {}\n", .{@typeInfo(@TypeOf(data))});
    const is_valid: bool = switch (@typeInfo(@TypeOf(data))) {
        .array => |arr| scan: {
            if (arr.len == 0) {
                break :scan false;
            }
            // std.debug.print("Array Child: {}\n", .{@typeInfo(arr.child)});
            switch (@typeInfo(arr.child)) {
                .int => break :scan true,
                .float => break :scan true,
                else => break :scan false,
            }
        },
        .pointer => |ptr| switch (ptr.size) {
            .slice => scan: {
                // std.debug.print("Ptr Size: {}\n", .{@typeInfo(@TypeOf(ptr.size))});
                // std.debug.print("Ptr Slice: {}\n", .{@typeInfo(ptr.child)});
                switch (@typeInfo(ptr.child)) {
                    .int => break :scan true,
                    .float => break :scan true,
                    else => break :scan false,
                }
            },
            .one => switch (@typeInfo(ptr.child)) {
                .array => |arr| scan: {
                    if (arr.len == 0) {
                        break :scan false;
                    }
                    // std.debug.print("Ptr Child: {}\n", .{@typeInfo(ptr.child)});
                    // std.debug.print("Ptr One: {}\n", .{@typeInfo(arr.child)});
                    switch (@typeInfo(arr.child)) {
                        .int => break :scan true,
                        .float => break :scan true,
                        else => break :scan false,
                    }
                },
                else => false,
            },
            else => false,
        },
        else => false,
    };
    return is_valid;
}
const FileTerm = struct {
    ext: []const u8,
    term: []const u8,
    inches: bool = false,
};

const file_terms = [_]FileTerm{
    .{ .ext = ".png", .term = "pngcairo" },
    .{ .ext = ".jpg", .term = "jpeg" },
    .{ .ext = ".jpeg", .term = "jpeg" },
    .{ .ext = ".gif", .term = "gif" },
    .{ .ext = ".svg", .term = "svg" },
    .{ .ext = ".pdf", .term = "pdfcairo", .inches = true },
    .{ .ext = ".eps", .term = "epscairo", .inches = true },
};

fn fileTerm(path: []const u8) !FileTerm {
    for (file_terms) |t| {
        if (std.ascii.endsWithIgnoreCase(path, t.ext)) return t;
    }
    return error.UnsupportedFormat;
}

pub const Figure = struct {
    width: u32,
    height: u32,
    term: []const u8,
    gnuplot: []const u8,

    data: std.ArrayList(u8) = .empty,
    options: std.ArrayList(u8) = .empty,
    clauses: std.ArrayList(u8) = .empty,
    series_count: usize = 0,

    io: Io,
    allocator: std.mem.Allocator,

    pub const Options = struct {
        width: u32 = 600,
        height: u32 = 400,
        term: []const u8 = "qt",
        gnuplot: []const u8 = "gnuplot.exe",
    };

    pub fn init(io: Io, allocator: std.mem.Allocator, config: Options) Figure {
        return Figure{
            .width = config.width,
            .height = config.height,
            .term = config.term,
            .gnuplot = config.gnuplot,

            .io = io,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Figure) void {
        self.data.deinit(self.allocator);
        self.options.deinit(self.allocator);
        self.clauses.deinit(self.allocator);
        self.* = undefined;
    }

    pub const PlotOptions = struct {
        label: ?[]const u8 = null,
        color: ?[]const u8 = null,
        linewidth: f32 = 1.0,
        linetype: u32 = 1,
        points: bool = false,
        pointsize: f64 = 1.5,
        pointstyle: u8 = 7,
        pointinterval: f64 = 2.0,
        pointnumber: f64 = -1.0,
    };

    pub fn plot(self: *Figure, x: anytype, y: anytype, option: PlotOptions) !void {
        if (!check_type(x) | !check_type(y)) {
            return error.GnuplotMismatchDataType;
        }
        if (x.len != y.len) return error.LengthMismatch;

        const id = self.series_count;
        const a = self.allocator;

        try self.data.print(a, "$d{d} << EOD\n", .{id});
        for (x, y) |xi, yi| {
            try self.data.print(a, "{d} {d}\n", .{ xi, yi });
        }
        try self.data.appendSlice(a, "EOD\n");

        const style = if (option.points) "linespoints" else "lines";

        if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");
        try self.clauses.print(a, "$d{d} using 1:2 with {s} lw {d} dt {d}", .{ id, style, option.linewidth, option.linetype });
        if (option.color) |c| try self.clauses.print(a, " lc rgb '{s}'", .{c});
        if (option.points) try self.clauses.print(a, " pt {d} ps {d} pointinterval {d}", .{ option.pointstyle, option.pointsize, option.pointinterval });
        if (option.pointnumber > 0) try self.clauses.print(a, " pointnumber {d}", .{option.pointnumber});
        if (option.label) |l| {
            try self.clauses.print(a, " title '{s}'", .{l});
        } else {
            try self.clauses.appendSlice(a, " notitle");
        }
        self.series_count += 1;
    }

    pub const BarOptions = struct {
        boxwidth: f64 = 0.5,
        alpha: f64 = 0.5,
        border: bool = false,
        color: ?[]const u8 = null,
        label: ?[]const u8 = null,
        ticks: ?[]const []const u8 = null,
    };

    pub fn bar(self: *Figure, data: anytype, option: BarOptions) !void {
        if (!check_type(data)) {
            return error.GnuplotMismatchDataType;
        }

        const id = self.series_count;
        const a = self.allocator;

        try self.data.print(a, "$d{d} << EOD\n", .{id});
        for (1..(data.len + 1), data) |xi, yi| {
            try self.data.print(a, "{d} {d}\n", .{ xi, yi });
        }
        try self.data.appendSlice(a, "EOD\n");

        if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");
        try self.clauses.print(a, "$d{d} using 1:2 with boxes", .{id});
        if (option.color) |c| try self.clauses.print(a, " lc rgb '{s}'", .{c});
        if (option.label) |l| {
            try self.clauses.print(a, " title '{s}'", .{l});
        } else {
            try self.clauses.appendSlice(a, " notitle");
        }
        if (option.ticks) |ticks| {
            try self.options.appendSlice(a, "set xtics(");
            for (1..(ticks.len + 1), ticks) |i, t| {
                try self.options.print(a, "'{s}' {d}", .{ t, i });
                if (i != ticks.len) try self.options.appendSlice(a, ",");
            }
            try self.options.appendSlice(a, ")\n");
        }
        try self.options.appendSlice(a, "set style data boxes\n");
        try self.options.print(a, "set boxwidth {d}\n", .{option.boxwidth});
        try self.options.print(a, "set style fill solid {d} ", .{option.alpha});
        if (option.border) {
            try self.options.appendSlice(a, "border\n");
        } else {
            try self.options.appendSlice(a, "\n");
        }

        self.series_count += 1;
    }

    pub const ScatterOptions = struct {
        label: ?[]const u8 = null,
        color: ?[]const u8 = null,
        pointsize: f32 = 1.0,
        pointtype: u32 = 7,
    };
    pub fn scatter(self: *Figure, x: anytype, y: anytype, option: ScatterOptions) !void {
        if (!check_type(x) | !check_type(y)) {
            return error.GnuplotMismatchDataType;
        }
        if (x.len != y.len) return error.LengthMismatch;

        const id = self.series_count;
        const a = self.allocator;

        try self.data.print(a, "$d{d} << EOD\n", .{id});
        for (x, y) |xi, yi| {
            try self.data.print(a, "{d} {d}\n", .{ xi, yi });
        }
        try self.data.appendSlice(a, "EOD\n");

        if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");
        try self.clauses.print(a, "$d{d} using 1:2 with points ps {d} pt {d}", .{ id, option.pointsize, option.pointtype });
        if (option.color) |c| try self.clauses.print(a, " lc rgb '{s}'", .{c});
        if (option.label) |l| {
            try self.clauses.print(a, " title '{s}'", .{l});
        } else {
            try self.clauses.appendSlice(a, " notitle");
        }
        self.series_count += 1;
    }

    pub const ImageConfig = struct {
        rgbformulae: [3]u32 = [_]u32{ 33, 13, 10 },
        cblabel: ?[]const u8 = null,
        title: ?[]const u8 = null,
    };

    pub fn imshow(self: *Figure, image: anytype, width: usize, height: usize, options: ImageConfig) !void {
        var ext: ?[]const u8 = null;
        if (comptime is_string(@TypeOf(image))) {
            const file = fileTerm(image) catch FileTerm{ .ext = ".null", .inches = false, .term = ".null" };
            ext = file.ext[1..4];
            if (std.mem.eql(u8, ext.?, "null")) { 
                return error.MismatchImageFileType;
            }
            const a = self.allocator;

            if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");

            try self.options.print(a, "set palette rgbformulae {d},{d},{d}\n", 
                .{ options.rgbformulae[0], options.rgbformulae[1], options.rgbformulae[2] });
            try self.options.print(a, "set cbrange [*:*]\n", .{});
            if (options.cblabel) |l| try self.options.print(a, "set cblabel '{s}'\n", .{l});
            try self.options.print(a, "set colorbox\n", .{});
            try self.options.print(a, "unset key\n", .{});
            try self.options.print(a, "set size ratio -1\n", .{});

            try self.clauses.print(a, "'{s}' binary filetype={s} with rgbimage", .{image, ext.?});
            if (options.title) |t| {
                try self.clauses.print(a, " title '{s}'", .{t});
            } else {
                try self.clauses.appendSlice(a, " notitle");
            }
        } else {
            if (!check_type(image)) {
                return error.MismatchImageDataType;
            }
            const id = self.series_count;
            const a = self.allocator;

            var min_c: f64 = std.math.inf(f64);
            var max_c: f64 = -std.math.inf(f64);

            try self.data.print(a, "$d{d} << EOD\n", .{id});
            for (0..height) |y| {
                for (0..width) |x| {
                    const index = width * y + x;
                    const value = image[index];
                    if (value <= min_c) min_c = value;
                    if (value >= max_c) max_c = value;
                    try self.data.print(a, "{d} ", .{value});
                }
                try self.data.print(a, "\n", .{});
            }
            try self.data.appendSlice(a, "EOD\n");
            if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");

            if (min_c == max_c) {
                min_c -= 0.5;
                max_c += 0.5;
            }

            try self.options.print(a, "set palette rgbformulae {d},{d},{d}\n", .{ options.rgbformulae[0], options.rgbformulae[1], options.rgbformulae[2] });
            try self.options.print(a, "set cbrange [*:*]\n", .{});
            if (options.cblabel) |l| try self.options.print(a, "set cblabel '{s}'\n", .{l});
            try self.options.print(a, "set colorbox\n", .{});
            try self.options.print(a, "unset key\n", .{});
            try self.options.print(a, "set size ratio -1\n", .{});
            try self.clauses.print(a, "$d{d} matrix with image", .{id});
            if (options.title) |t| {
                try self.clauses.print(a, " title '{s}'", .{t});
            } else {
                try self.clauses.appendSlice(a, " notitle");
            }

            self.series_count += 1;
        }
    }

    const LabelOptions = struct {
        font: []const u8 = "Sans",
        fontsize: u32 = 14,
        offset_x: i32 = 0,
        offset_y: i32 = 0,
        color: []const u8 = "black",
    };

    pub fn xlabel(self: *Figure, label: []const u8, option: LabelOptions) !void {
        try self.options.print(self.allocator, "set xlabel '{s}' font '{s},{d}' offset {d},{d} textcolor rgb '{s}'\n", .{ label, option.font, option.fontsize, option.offset_x, option.offset_y, option.color });
    }
    pub fn ylabel(self: *Figure, label: []const u8, option: LabelOptions) !void {
        try self.options.print(self.allocator, "set ylabel '{s}' font '{s},{d}' offset {d},{d} textcolor rgb '{s}'\n", .{ label, option.font, option.fontsize, option.offset_x, option.offset_y, option.color });
    }

    pub fn xlim(self: *Figure, min: f64, max: f64) !void {
        try self.options.print(self.allocator, "set xrange [{d}:{d}]\n", .{ min, max });
    }
    pub fn ylim(self: *Figure, min: f64, max: f64) !void {
        try self.options.print(self.allocator, "set yrange [{d}:{d}]\n", .{ min, max });
    }

    pub fn xreverse(self: *Figure) !void {
        try self.options.appendSlice(self.allocator, "set xrange [*:*] reverse\n");
    }

    pub fn yreverse(self: *Figure) !void {
        try self.options.appendSlice(self.allocator, "set yrange [*:*] reverse\n");
    }

    pub fn axis(self: *Figure, state: []const u8) !void {
        if (std.mem.eql(u8, state, "off")) {
            try self.options.appendSlice(self.allocator, "unset xtics\n");
            try self.options.appendSlice(self.allocator, "unset ytics\n");
            try self.options.appendSlice(self.allocator, "unset xlabel\n");
            try self.options.appendSlice(self.allocator, "unset ylabel\n");
            try self.options.appendSlice(self.allocator, "unset border\n");
            try self.options.appendSlice(self.allocator, "unset xzeroaxis\n");
            try self.options.appendSlice(self.allocator, "unset yzeroaxis\n");
        } else if (std.mem.eql(u8, state, "off-labels")) {
            try self.options.appendSlice(self.allocator, "unset xlabel\n");
            try self.options.appendSlice(self.allocator, "unset ylabel\n");
        } else if (std.mem.eql(u8, state, "off-ticks")) {
            try self.options.appendSlice(self.allocator, "unset xtics\n");
            try self.options.appendSlice(self.allocator, "unset ytics\n");
        } else if (std.mem.eql(u8, state, "off-border")) {
            try self.options.appendSlice(self.allocator, "unset border\n");
        }
    }

    pub fn grid(self: *Figure) !void {
        try self.options.print(self.allocator, "set grid\n", .{});
    }

    pub const Output = union(enum) {
        window,
        file: []const u8,
    };

    fn build(self: *const Figure, output: Output) ![]u8 {
        if (self.clauses.items.len == 0) return error.EmptyFigure;

        const a = self.allocator;
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(a);

        switch (output) {
            .window => try out.print(a, "set terminal {s} size {d}, {d}\n", .{
                self.term, self.width, self.height,
            }),
            .file => |path| {
                const t = try fileTerm(path);
                if (t.inches) {
                    const dpi: f32 = 100.0;
                    const w = @as(f32, @floatFromInt(self.width)) / dpi;
                    const h = @as(f32, @floatFromInt(self.height)) / dpi;
                    try out.print(a, "set terminal {s} size {d}, {d}\n", .{ t.term, w, h });
                } else {
                    try out.print(a, "set terminal {s} size {d}, {d}\n", .{ t.term, self.width, self.height });
                }
                try out.print(a, "set output '{s}'\n", .{path});
            },
        }

        try out.appendSlice(a, "reset\n");
        try out.appendSlice(a, self.options.items);
        try out.appendSlice(a, self.data.items);
        try out.appendSlice(a, "plot ");
        try out.appendSlice(a, self.clauses.items);
        try out.append(a, '\n');

        return out.toOwnedSlice(a);
    }

    fn run(self: *const Figure, script: []const u8, persist: bool) !void {
        const argv: []const []const u8 = if (persist) &.{ self.gnuplot, "-persist" } else &.{self.gnuplot};

        var child = try std.process.spawn(self.io, .{
            .argv = argv,
            .stdin = .pipe,
            .stdout = .inherit,
            .stderr = .inherit,
        });
        {
            errdefer child.kill(self.io);

            const stdin = child.stdin orelse return error.MissingStdinPipe;

            var buf: [4096]u8 = undefined;
            var w = stdin.writer(self.io, &buf);
            try w.interface.writeAll(script);
            try w.flush();

            stdin.close(self.io);
            child.stdin = null;
        }

        const term = try child.wait(self.io);
        switch (term) {
            .exited => |code| if (code != 0) return error.GnuplotFailed,
            else => return error.GnuplotFailed,
        }
    }

    pub fn show(self: *Figure) !void {
        const script = try self.build(.window);
        defer self.allocator.free(script);
        try self.run(script, true);
        self.clear();
    }

    pub fn savefig(self: *Figure, path: []const u8) !void {
        const script = try self.build(.{ .file = path });
        defer self.allocator.free(script);
        try self.run(script, false);
        self.clear();
    }

    pub fn clear(self: *Figure) void {
        self.data.clearRetainingCapacity();
        self.options.clearRetainingCapacity();
        self.clauses.clearRetainingCapacity();
        self.series_count = 0;
    }
};

// tests

const testing = std.testing;

fn testFigure(a: std.mem.Allocator) Figure {
    return Figure.init(undefined, a, .{});
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, haystack, needle) == null) {
        std.debug.print("\nmissing: {s}\nin:\n{s}\n", .{ needle, haystack });
        return error.TestUnexpectedResult;
    }
}

fn indexOfOrFail(haystack: []const u8, needle: []const u8) !usize {
    return std.mem.indexOf(u8, haystack, needle) orelse {
        std.debug.print("\nmissing: {s}\nin:\n{s}\n", .{ needle, haystack });
        return error.TestUnexpectedResult;
    };
}

test "empty figure refuses to build" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();
    try testing.expectError(error.EmptyFigure, fig.build(.window));
}

test "plot writes an exact datablock and a lines clause" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const x = [_]i32{ 1, 2 };
    const y = [_]i32{ 10, 20 };
    try fig.plot(&x, &y, .{});

    try testing.expectEqualStrings("$d0 << EOD\n1 10\n2 20\nEOD\n", fig.data.items);
    try expectContains(fig.clauses.items, "$d0 using 1:2 with lines");
    try testing.expectEqual(@as(usize, 1), fig.series_count);
}

test "length mismatch errors and leaves no partial data" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const x = [_]i32{ 1, 2, 3 };
    const y = [_]i32{ 1, 2 };
    try testing.expectError(error.LengthMismatch, fig.plot(&x, &y, .{}));
    try testing.expectEqual(@as(usize, 0), fig.data.items.len);
    try testing.expectEqual(@as(usize, 0), fig.clauses.items.len);
    try testing.expectEqual(@as(usize, 0), fig.series_count);
}

test "second series gets its own id and is comma-joined" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2, 3 };
    try fig.plot(&v, &v, .{});
    try fig.scatter(&v, &v, .{});

    try testing.expectEqual(@as(usize, 2), fig.series_count);
    try expectContains(fig.clauses.items, "$d0 using 1:2 with lines");
    try expectContains(fig.clauses.items, ", $d1 using 1:2 with points");
}

test "label and color options reach the clause; no label means notitle" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2 };
    try fig.plot(&v, &v, .{ .label = "squares", .color = "red" });
    try fig.plot(&v, &v, .{});

    try expectContains(fig.clauses.items, "title 'squares'");
    try expectContains(fig.clauses.items, "lc rgb 'red'");
    try expectContains(fig.clauses.items, "notitle");
}

test "script order: terminal, set options, datablocks, then plot" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2 };
    try fig.xlabel("time", .{});
    try fig.plot(&v, &v, .{});

    const script = try fig.build(.window);
    defer testing.allocator.free(script);

    const term_i = try indexOfOrFail(script, "set terminal");
    const label_i = try indexOfOrFail(script, "set xlabel 'time'");
    const data_i = try indexOfOrFail(script, "$d0 << EOD");
    const plot_i = try indexOfOrFail(script, "plot $d0");

    try testing.expect(term_i < label_i);
    try testing.expect(label_i < data_i);
    try testing.expect(data_i < plot_i);
}

test "a set command is its own line, not glued to the next block" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2 };
    try fig.xlabel("x", .{});
    try fig.ylabel("y", .{});
    try fig.plot(&v, &v, .{});

    const script = try fig.build(.window);
    defer testing.allocator.free(script);

    try expectContains(script, "set xlabel 'x' font 'Sans,14' offset 0,0 textcolor rgb 'black'\n");
    try expectContains(script, "set ylabel 'y' font 'Sans,14' offset 0,0 textcolor rgb 'black'\n");
}

test "fileTerm maps extensions, ignoring case" {
    const png = try fileTerm("out.png");
    try testing.expectEqualStrings("pngcairo", png.term);
    try testing.expect(!png.inches);

    const pdf = try fileTerm("REPORT.PDF");
    try testing.expectEqualStrings("pdfcairo", pdf.term);
    try testing.expect(pdf.inches);

    try testing.expectError(error.UnsupportedFormat, fileTerm("notes.txt"));
    try testing.expectError(error.UnsupportedFormat, fileTerm("mypng"));
}

test "file output sets terminal and output, and pdf does not use pixel sizes" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2 };
    try fig.plot(&v, &v, .{});

    const png = try fig.build(.{ .file = "out.png" });
    defer testing.allocator.free(png);
    try expectContains(png, "set terminal pngcairo size 600, 400");
    try expectContains(png, "set output 'out.png'");

    const pdf = try fig.build(.{ .file = "out.pdf" });
    defer testing.allocator.free(pdf);
    try expectContains(pdf, "set terminal pdfcairo");
    try testing.expect(std.mem.indexOf(u8, pdf, "size 600") == null);
}

test "unsupported file extension fails before producing a script" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();

    const v = [_]i32{ 1, 2 };
    try fig.plot(&v, &v, .{});
    try testing.expectError(error.UnsupportedFormat, fig.build(.{ .file = "out.txt" }));
}

fn buildOnce(a: std.mem.Allocator) !void {
    var fig = testFigure(a);
    defer fig.deinit();

    const v = [_]i32{ 1, 2, 3 };
    try fig.xlabel("x", .{});
    try fig.plot(&v, &v, .{ .label = "a" });
    try fig.scatter(&v, &v, .{});

    const script = try fig.build(.window);
    a.free(script);
}

test "no leaks or crashes when any allocation fails" {
    try testing.checkAllAllocationFailures(testing.allocator, buildOnce, .{});
}

test "mismatch type error" {
    var fig = testFigure(testing.allocator);
    defer fig.deinit();
    const v = [_]i32{ 1, 2, 3 };
    try fig.plot(&v, &v, .{ .label = "a" });
    try fig.scatter(&v, &v, .{});

    // const T = struct {
    //     data: i32,
    // };
    // const a = T{ .data = 0 };
    // const b = T{ .data = 0 };
    // const u = [_]T{a, b};
    // try testing.expectError(error.GnuplotMismatchDataType, fig.plot(&u, &u, .{}));
}
