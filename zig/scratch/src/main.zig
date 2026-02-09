const std = @import("std");

pub fn main() !void {
    const a1 = [_]i32{ 3, 1, 4 };
    const a2 = [_]i32{ 1, 5, 9 };
    const a3 = a1 ++ a2;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("a3: {any}\n", .{a3});
    try stdout.flush();
}
