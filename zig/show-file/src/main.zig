const std = @import("std");
const builtin = @import("builtin");

// funciton (fn) read_file - takes an array const ([]const) of type u8 (unsigned 8-bit integer, which can
// contain characters), and a buffer, whcih is a mutable array of u8 ([u8]).
fn read_file(path: []const u8, buffer: []u8) !usize {
    // create a file object, the result of which is a call to
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const byteCount = try file.read(buffer[0..]);
    return byteCount;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var file_buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(file_buffer);

    @memset(file_buffer[0..], 0);

    const path = "/home/jflana/src/git/wing/zig-rust_learnin/learning-map.md";
    const read_bytes = try read_file(path, file_buffer[0..]);
    std.debug.print("{s}", .{file_buffer[0..read_bytes]});
}
