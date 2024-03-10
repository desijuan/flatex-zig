const std = @import("std");
const stdout = std.io.getStdOut().writer();

const utils = @import("utils.zig");
const getOpeningBracketPos = utils.getOpeningBracketPos;
const getPairingBracketPos = utils.getPairingBracketPos;
const findLast = utils.findLast;

const MAX_LEVEL = 10;

pub fn flatIt(
    source_path: []const u8,
    dest_file_writer: anytype,
    fbs: *std.io.FixedBufferStream([]u8),
    level: *u8,
) !void {
    const source_file = try std.fs.cwd().openFile(source_path, .{ .mode = .read_only });
    defer source_file.close();

    var buffered_reader = std.io.bufferedReader(source_file.reader());
    const source_file_reader = buffered_reader.reader();

    // Print level
    for (0..level.*) |_| try stdout.print("  ", .{}) else try stdout.print("{s}\n", .{source_path});
    level.* += 1;

    while (source_file_reader.streamUntilDelimiter(fbs.writer(), '\n', fbs.buffer.len)) {
        const line = fbs.getWritten();
        fbs.reset();

        if (try getOpeningBracketPos(line, "\\input{") orelse
            try getOpeningBracketPos(line, "\\include{")) |op_br|
        {
            if (level.* >= MAX_LEVEL) return error.RecursionLimitExceeded;

            const cl_br = try getPairingBracketPos(line, op_br, '{', '}');

            const arg = line[op_br + 1 .. cl_br];
            const suffix = ".tex";

            const next_source_path = line[0 .. arg.len + suffix.len];
            for (0..arg.len) |i| {
                next_source_path[i] = arg[i];
            }
            for (0..suffix.len) |i| {
                next_source_path[i + arg.len] = suffix[i];
            }

            try flatIt(next_source_path, dest_file_writer, fbs, level);
        } else {
            if (try getOpeningBracketPos(line, "\\includepdf") orelse
                try getOpeningBracketPos(line, "\\includegraphics")) |op_br|
            {
                const cl_br = try getPairingBracketPos(line, op_br, '{', '}');
                const arg = line[op_br + 1 .. cl_br];

                // strip basename
                if (findLast(arg, '/')) |bar_pos| {
                    const offset = bar_pos + 1;
                    const new_line = line[0 .. line.len - offset];
                    for (op_br + 1..new_line.len) |i| {
                        new_line[i] = line[i + offset];
                    }
                    try dest_file_writer.writeAll(new_line);
                } else {
                    try dest_file_writer.writeAll(line);
                }
            } else {
                try dest_file_writer.writeAll(line);
            }
            try dest_file_writer.writeByte('\n');
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    level.* -= 1;
}

test "Recursion Limit" {
    const n = 3;
    inline for (1..n + 1) |i| {
        const file_name = std.fmt.comptimePrint("0{d}.tex", .{i});
        const file_contents = std.fmt.comptimePrint(
            "\\input{{0{d}}}\n",
            .{@mod(i, n) + 1},
        );
        const file = try std.fs.cwd().createFile(file_name, .{});
        try file.writeAll(file_contents);
        file.close();
    }

    const dest_file_name = "a.tex";
    const dest_file = try std.fs.cwd().createFile(dest_file_name, .{});
    defer std.fs.cwd().deleteFile(dest_file_name) catch {};
    defer dest_file.close();

    var buffered_writer = std.io.bufferedWriter(dest_file.writer());
    const dest_file_writer = buffered_writer.writer();

    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    var level: u8 = 0;

    std.debug.print("\n", .{});
    try std.testing.expectError(
        error.RecursionLimitExceeded,
        flatIt("01.tex", dest_file_writer, &fbs, &level),
    );

    inline for (1..n + 1) |i| {
        const file_name = std.fmt.comptimePrint("0{d}.tex", .{i});
        try std.fs.cwd().deleteFile(file_name);
    }
}
