const std = @import("std");

const flatIt = @import("flatex.zig").flatIt;

pub fn main() !u8 {
    var args = std.process.args();

    const bin: []const u8 = args.next().?;
    var source_path: []const u8 = undefined;
    var dest_path: []const u8 = undefined;
    (read_args: {
        source_path = args.next() orelse break :read_args error.InvalidArguments;
        dest_path = args.next() orelse break :read_args error.InvalidArguments;
        if (args.skip()) break :read_args error.InvalidArguments;
    } catch {
        std.debug.print("Usage: {s} <source> <dest>\n", .{bin});
        return 1;
    });

    const dest_file = try std.fs.cwd().createFile(dest_path, .{});
    errdefer std.fs.cwd().deleteFile(dest_path) catch {};
    defer dest_file.close();

    var buffered_writer = std.io.bufferedWriter(dest_file.writer());
    defer buffered_writer.flush() catch {};

    const dest_file_writer = buffered_writer.writer();

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    var level: u8 = 0;

    try flatIt(source_path, dest_file_writer, &fbs, &level);

    return 0;
}
