const std = @import("std");

fn findFirst(str: []const u8, start: usize, chr: u8) ?usize {
    for (start..str.len) |i| {
        if (str[i] == chr) return i;
    }
    return null;
}

pub fn findLast(str: []const u8, chr: u8) ?usize {
    for (0..str.len) |i| {
        const j = str.len - 1 - i;
        if (str[j] == chr) return j;
    }
    return null;
}

pub fn getOpeningBracketPos(str: []const u8, prefix: []const u8) !?usize {
    const keywordPos = std.mem.indexOf(u8, str, prefix);
    const comment = findFirst(str, 0, '%');

    if ((keywordPos != null) and ((comment == null) or (keywordPos.? < comment.?)))
        return findFirst(str, keywordPos.?, '{') orelse error.BracketNotFound;

    return null;
}

pub fn getPairingBracketPos(
    str: []const u8,
    start: usize,
    op_br: u8,
    cl_br: u8,
) !usize {
    if (str[start] != op_br) return error.NoBracket;

    var ctr: i32 = 1;
    for (start + 1..str.len) |i| {
        if (str[i] == op_br) {
            ctr += 1;
        } else if (str[i] == cl_br) {
            ctr -= 1;
            if (ctr == 0) return i;
        }
    }

    return error.BracketNotFound;
}

//
// -- Tests --
//

test findFirst {
    const str = "01234567890123456789";
    try std.testing.expectEqual(@as(?usize, null), findFirst(str, 0, 'a'));
    try std.testing.expectEqual(@as(?usize, null), findFirst(str, 14, '3'));
    try std.testing.expectEqual(@as(?usize, 1), findFirst(str, 0, '1'));
    try std.testing.expectEqual(@as(?usize, 9), findFirst(str, 3, '9'));
}

test findLast {
    const str = "01234567890123456789";
    try std.testing.expectEqual(@as(?usize, null), findLast(str, 'a'));
    try std.testing.expectEqual(@as(?usize, 11), findLast(str, '1'));
    try std.testing.expectEqual(@as(?usize, 19), findLast(str, '9'));
}

test getOpeningBracketPos {
    const input_prefix = "\\input";

    const line1 = "\\input_blahblahblah";
    try std.testing.expectError(
        error.BracketNotFound,
        getOpeningBracketPos(line1, input_prefix),
    );

    const line2 = "%\\input{palabras}";
    const s2 = try getOpeningBracketPos(line2, input_prefix);
    try std.testing.expectEqual(@as(?usize, null), s2);

    inline for ([_][]const u8{
        "\\input{123456789 {} {}...}",
        "\\input{queseyo} % Acá hay un comentario",
    }) |line| {
        const p = try getOpeningBracketPos(line, input_prefix);
        try std.testing.expectEqual(@as(u8, '{'), line[p.?]);
    }

    const include_prefix = "\\include";

    const line3 = "\\include_blahblahblah";
    try std.testing.expectError(
        error.BracketNotFound,
        getOpeningBracketPos(line3, include_prefix),
    );

    const line4 = "%\\include{palabras}";
    const s4 = try getOpeningBracketPos(line4, include_prefix);
    try std.testing.expectEqual(@as(?usize, null), s4);

    inline for ([_][]const u8{
        "\\include{123456789 {} {}...}",
        "\\include{queseyo} % Acá hay un comentario",
    }) |line| {
        const p = try getOpeningBracketPos(line, include_prefix);
        try std.testing.expectEqual(@as(u8, '{'), line[p.?]);
    }
}

test getPairingBracketPos {
    const line1 = "a";
    try std.testing.expectError(
        error.NoBracket,
        getPairingBracketPos(line1, 0, '{', '}'),
    );

    const line2 = "\\input{queseyo";
    try std.testing.expectError(
        error.BracketNotFound,
        getPairingBracketPos(line2, 6, '{', '}'),
    );

    inline for ([_]struct { str: []const u8, start: usize }{
        .{ .str = "\\input{queseyo} % Acá hay un comentario", .start = 6 },
        .{ .str = "\\include{123456789 {} {}...}", .start = 8 },
    }) |t| {
        const p = try getPairingBracketPos(t.str, t.start, '{', '}');
        try std.testing.expectEqual(@as(u8, '}'), t.str[p]);
    }
}
