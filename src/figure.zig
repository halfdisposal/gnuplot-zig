const std = @import("std");
const Io = std.Io;

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
        pointsize: f32 = 1.0,
        pointtype: u32 = 7,
    };

    pub fn plot(self: *Figure, x: anytype, y: anytype, option: PlotOptions) !void {
        if (x.len != y.len) return error.LengthMismatch;
        
        const id = self.series_count;
        const a = self.allocator;
        
        try self.data.print(a, "$d{d} << EOD\n", .{id});
        for (x, y) |xi, yi| {
            try self.data.print(a, "{d} {d}\n", .{xi, yi});
        }
        try self.data.appendSlice(a, "EOD\n");

        if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");
        try self.clauses.print(a, "$d{d} using 1:2 with lines lw {d} dt {d}", .{id, option.linewidth, option.linetype});
        if (option.color) |c| try self.clauses.print(a, " lc rgb '{s}'", .{c});
        if (option.label) |l| {
            try self.clauses.print(a, " title '{s}'", .{l});
        } else {
        try self.clauses.appendSlice(a, " notitle");
        }
        self.series_count += 1;
    }


    pub fn scatter(self: *Figure, x: anytype, y: anytype, option: PlotOptions) !void {
        if (x.len != y.len) return error.LengthMismatch;
        
        const id = self.series_count;
        const a = self.allocator;
        
        try self.data.print(a, "$d{d} << EOD\n", .{id});
        for (x, y) |xi, yi| {
            try self.data.print(a, "{d} {d}\n", .{xi, yi});
        }
        try self.data.appendSlice(a, "EOD\n");

        if (self.clauses.items.len > 0) try self.clauses.appendSlice(a, ", ");
        try self.clauses.print(a, "$d{d} using 1:2 with points ps {d} pt {d}", .{id, option.pointsize, option.pointtype});
        if (option.color) |c| try self.clauses.print(a, " lc rgb '{s}'", .{c});
        if (option.label) |l| {
            try self.clauses.print(a, " title '{s}'", .{l});
        } else {
        try self.clauses.appendSlice(a, " notitle");
        }
        self.series_count += 1;
    }

    const LabelOptions = struct {
        font: []const u8 = "Sans",
        fontsize: u32 = 14,
        offset_x: i32 = 0,
        offset_y: i32 = 0,
        color: []const u8 = "black",
    };

    pub fn xlabel(self: *Figure, label: []const u8, option: LabelOptions) !void {
        try self.options.print(self.allocator, "set xlabel '{s}' font '{s},{d}' offset {d},{d} textcolor rgb '{s}'\n", .{label, option.font, option.fontsize, option.offset_x, option.offset_y, option.color});
    }
    pub fn ylabel(self: *Figure, label: []const u8, option: LabelOptions) !void {
        try self.options.print(self.allocator, "set ylabel '{s}' font '{s},{d}' offset {d},{d} textcolor rgb '{s}'\n", .{label, option.font, option.fontsize, option.offset_x, option.offset_y, option.color});
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
        
        try out.appendSlice(a, self.options.items);
        try out.appendSlice(a, self.data.items);
        try out.appendSlice(a, "plot ");
        try out.appendSlice(a, self.clauses.items);
        try out.append(a, '\n');
        
        return out.toOwnedSlice(a);
    }

    fn run(self: *const Figure, script: []const u8, persist: bool) !void {
        const argv: []const []const u8 = if (persist) &.{self.gnuplot, "-persist"} else &.{self.gnuplot};

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
    
    pub fn show(self: *const Figure) !void {
        const script = try self.build(.window);
        defer self.allocator.free(script);
        try self.run(script, true);
    }

    pub fn savefig(self: *const Figure, path: []const u8) !void {
        const script = try self.build(.{ .file =  path});
        defer self.allocator.free(script);
        try self.run(script, false);
    }
    
};

