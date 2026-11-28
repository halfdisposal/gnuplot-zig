//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
pub const Figure = @import("figure.zig").Figure;
pub const Utils = @import("utils.zig");

pub const linspace = Utils.linspace;
pub const vspace = Utils.vspace;

test "figure" {
    _ = @import("figure.zig");
}
