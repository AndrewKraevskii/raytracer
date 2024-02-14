const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const qoi = @import("qoi.zig");

pub fn draw_ascii(
    self: Image,
    writer: std.io.AnyWriter,
) void {
    for (0..self.height) |row| {
        for (0..self.width) |col| {
            const symbol: u8 = if (self.get(col, row).as_gray() < @as(usize, 128)) 'X' else '.';
            writer.print(
                "{c}",
                .{symbol},
            ) catch return;
        }
        writer.print("\n", .{}) catch return;
    }
}

fn Point(comptime inner: type) type {
    return struct {
        x: inner,
        y: inner,
    };
}

fn draw_circle(image: *Image, center: Point(f32), radius: f32) void {
    for (0..image.height) |col| {
        for (0..image.width) |row| {
            if (std.math.pow(f32, (center.x - @as(f32, @floatFromInt(col))), 2.0) +
                std.math.pow(f32, (center.y - @as(f32, @floatFromInt(row))), 2.0) < radius * radius)
            {
                image.get_mut(col, row).* = Color.WHITE;
            }
        }
    }
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buffer = [_]u8{0} ** 1000 ** 1000;
    var alloc = std.heap.FixedBufferAllocator.init(buffer[0..]);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);

    const stdout = bw.writer();

    const test_image = @embedFile("assets/Sprite-0001.qoi");

    var image = try qoi.parse_qoi(alloc.allocator(), test_image);
    std.debug.assert(image.width == 16);
    std.debug.assert(image.height == 32);
    defer image.deinit();

    draw_ascii(image, stdout.any());
    try bw.flush(); // don't forget to flush!
}
