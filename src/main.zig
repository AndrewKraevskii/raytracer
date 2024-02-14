const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;

pub fn draw_ascii(
    self: Image,
    writer: std.io.AnyWriter,
) void {
    for (0..self.height) |row| {
        for (0..self.width) |col| {
            const symbol: u8 = if (self.get(row, col).as_gray() < @as(usize, 128)) 'X' else '.';
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
    var buffer = [_]u8{0} ** 10000;
    var alloc = std.heap.FixedBufferAllocator.init(buffer[0..]);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var image = Image.zeroed(alloc.allocator(), .{ 30, 30 }) catch {
        std.debug.print("Run out of memory 😥\n", .{});
        return;
    };
    defer image.deinit();

    draw_circle(&image, .{ .x = 10.0, .y = 10.0 }, 10.0);
    draw_ascii(image, stdout.any());
    // var array: [4]u8 = .{ 0, 255, 0, 255 };
    // (Image{ .size = .{ 2, 2 }, .data = &array }).draw_ascii(stdout.any());

    try bw.flush(); // don't forget to flush!
}
