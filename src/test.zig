const std = @import("std");
const Figure = @import("figure.zig").Figure;

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

