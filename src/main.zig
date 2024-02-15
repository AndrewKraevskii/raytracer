const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const qoi = @import("qoi.zig");
const math = @import("vector.zig");

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

fn draw_sphere(image: *Image, sphere: math.Sphere) void {
    for (0..image.height) |col| {
        for (0..image.width) |row| {
            const ray = .{ .start = .{
                -20,
                @as(f32, @floatFromInt(col)) -
                    @as(f32, @floatFromInt(image.height)) / 2,
                @as(f32, @floatFromInt(row)) - @as(f32, @floatFromInt(image.width)) / 2,
            }, .direction = .{ 1, 0, 0 } };
            if (math.intersectRaySphere(
                ray,
                sphere,
            )) |intersection| {
                image.get_mut(col, row).* = Color{
                    .r = @intFromFloat(std.math.clamp(
                        intersection[0].normal[0] * 255,
                        0.0,
                        255.0,
                    )),
                    .g = @intFromFloat(std.math.clamp(
                        intersection[0].normal[1] * 255,
                        0.0,
                        255.0,
                    )),
                    .b = @intFromFloat(std.math.clamp(
                        intersection[0].normal[2] * 255,
                        0.0,
                        255.0,
                    )),
                    .a = 255,
                };
            }
        }
    }
}

const Sphere = struct {
    center: math.Vec,
    radius: f32,
};

const Ray = struct {
    start: math.Vec,
    direction: math.Vec,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    // var buffer = [_]u8{0} ** 1000 ** 1000 ** 10000;
    // var alloc = std.heap.FixedBufferAllocator.init(buffer[0..]);

    var image = try Image.zeroed(gpa.allocator(), .{ 320, 320 });
    defer image.deinit();
    draw_sphere(&image, math.Sphere{
        .center = .{ 0, 0, 0 },
        .radius = 100,
    });

    const out = try std.fs.cwd().createFile("out.qoi", .{});
    defer out.close();
    // var out = std.io.getStdOut();
    // defer out.close();
    var out_buff = std.io.bufferedWriter(out.writer());
    defer _ = out_buff.flush() catch null;

    try qoi.encode_qoi(out_buff.writer().any(), image);
    // draw_ascii(
    //     image,
    //     out_buff.writer().any(),
    // );
}
