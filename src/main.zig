const std = @import("std");
const clap = @import("clap");
const Allocator = std.mem.Allocator;

const max_read = std.math.maxInt(usize);

fn copyStdInToStdOut() !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    var i: usize = 0;
    while (true) : (i += 1) {
        const c = stdin.reader().readByte() catch break;
        try stdout.writer().writeByte(c);
        if (i >= max_read) break;
    }
}

fn readFiles(alloc: Allocator, filenames: []const []const u8) !void {
    const stdout = std.io.getStdOut();
    if (filenames.len < 1) {
        try copyStdInToStdOut();
    }

    for (filenames) |filename| {
        std.debug.print("filename -> {s}\n", .{filename});
        if (std.mem.eql(u8, filename, "-")) {
            try copyStdInToStdOut();
            continue;
        }
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = .{0} ** std.fs.MAX_PATH_BYTES;
        const path = try std.fs.realpath(filename, &path_buf);
        const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
        defer file.close();

        const contents = try std.fs.cwd().readFileAlloc(alloc, path, max_read);
        defer alloc.free(contents);

        try stdout.writer().writeAll(contents);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Print usage information and exit
        \\-u            Ignored, here for POSIX compliance. Unbuffered output is the default behavior
        \\<file>...     A pathname of an input file. If no file is given, stdin will be used. If `-` is used, stdin will be used at that point
    );
    const parsers = comptime .{
        .file = clap.parsers.string,
    };
    var res = clap.parse(clap.Help, &params, parsers, .{ .allocator = alloc }) catch |err| {
        std.debug.print("Error parsing arguments: {}\n", .{err});
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{
            .indent = 0,
            .max_width = 120,
            .description_on_new_line = false,
            .description_indent = 8,
            .spacing_between_parameters = 0,
        });
        return;
    }

    return readFiles(alloc, res.positionals);
}
