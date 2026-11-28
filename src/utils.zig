const std = @import("std");

fn check_float(comptime T: type) bool {
    // std.debug.print("Info: {}\n", .{@typeInfo(T)});
    return switch (@typeInfo(T)) {
        .comptime_float => true,
        .float => true,
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .comptime_float => true,
                .float => true,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}
fn check_int(comptime T: type) bool {
    // std.debug.print("Info: {}\n", .{@typeInfo(T)});
    return switch (@typeInfo(T)) {
        .comptime_int => true,
        .int => true,
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .comptime_int => true,
                .int => true,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

pub fn check_vector(comptime v: type) bool {
    return @typeInfo(v) == .vector;
}

pub fn VectorToArray(v: anytype) ![@typeInfo(@TypeOf(v)).vector.len]@typeInfo(@TypeOf(v)).vector.child {
    if (!comptime check_vector(@TypeOf(v))) {
        return error.InvalidVectorAsArgument;
    }
    const data = @typeInfo(@TypeOf(v)).vector;
    return @as([data.len]data.child, v);
}

pub fn linspace(start: anytype, stop: anytype, comptime n: usize) ![n]f64 {
    if (!((comptime check_float(@TypeOf(start))) | (comptime check_int(@TypeOf(start))))) {
        return error.LinspaceTypeError;
    }
    if (!((comptime check_float(@TypeOf(stop))) | (comptime check_int(@TypeOf(stop))))) {
        return error.LinspaceTypeError;
    }
    const nf: f64 = @floatFromInt(n);
    const diff: f64 = (stop - start) / nf;
    var arr: [n]f64 = undefined;
    for (&arr, 0..) |*item, i| {
        const i_f: f64 = @floatFromInt(i);
        item.* = start + diff * i_f;
    }
    return arr;
}

pub fn vspace(start: anytype, stop: anytype, comptime n: usize) !@Vector(n, f64) {
    if (!((comptime check_float(@TypeOf(start))) | (comptime check_int(@TypeOf(start))))) {
        return error.LinspaceTypeError;
    }
    if (!((comptime check_float(@TypeOf(stop))) | (comptime check_int(@TypeOf(stop))))) {
        return error.LinspaceTypeError;
    }
    const nf: f64 = @floatFromInt(n);
    const diff: f64 = (stop - start) / nf;
    var arr: [n]f64 = undefined;
    for (&arr, 0..) |*item, i| {
        const i_f: f64 = @floatFromInt(i);
        item.* = start + diff * i_f;
    }
    return @as(@Vector(n, f64), arr);
}
