const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const qoi = @import("qoi.zig");
const raytracing = @import("raytracing.zig");
const Vec = @import("vector.zig").Vec;

pub fn drawAscii(
    self: Image,
    writer: std.io.AnyWriter,
) void {
    for (0..self.height) |row| {
        for (0..self.width) |col| {
            const symbol: u8 = if (self.get(col, row).asGray() < @as(usize, 128)) 'X' else '.';
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

fn drawCircle(image: *Image, center: Point(f32), radius: f32) void {
    for (0..image.height) |col| {
        for (0..image.width) |row| {
            if (std.math.pow(f32, (center.x - @as(f32, @floatFromInt(col))), 2.0) +
                std.math.pow(f32, (center.y - @as(f32, @floatFromInt(row))), 2.0) < radius * radius)
            {
                image.getMut(col, row).* = Color.WHITE;
            }
        }
    }
}

const SCREEN_SIZE = 320;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var image = try Image.zeroed(gpa.allocator(), .{ SCREEN_SIZE, SCREEN_SIZE });
    defer image.deinit();

    const distance_from_center = 10;

    var camera = raytracing.PerspectiveCamera{
        .position = .{ 0, 0, 20 },
        .right = .{ 25, 0, 0 },
        .up = .{ 0, 25, 0 },
        .height = SCREEN_SIZE,
        .width = SCREEN_SIZE,
        .focal_distance = 50,
    };

    image.fill(Color.BLACK);
    // raytracing.draw_sphere(&image, camera, raytracing.Sphere{
    //     .center = .{ 0, 0, 0 },
    //     .radius = 100,
    // });

    // raytracing.draw_sphere(&image, camera, raytracing.Sphere{
    //     .center = .{ 0, 0, 100 },
    //     .radius = 50,
    // });
    for (0..5) |i| {
        for (0..5) |j| {
            for (0..5) |k| {
                raytracing.drawSphere(&image, camera, raytracing.Sphere{
                    .center = .{ @as(f32, @floatFromInt(i)) * 20 - 50, @as(f32, @floatFromInt(j)) * 20 - 50, @as(f32, @floatFromInt(k)) * 20 - 50 },
                    .radius = 10,
                });
            }
        }
    }

    camera = camera.lookAt(
        .{
            @floatCast(distance_from_center * @sin(0.0)),
            0,
            @floatCast(distance_from_center * @cos(0.0)),
        },
        .{ 0, 0, 0 },
    );
    const out = try std.fs.cwd().createFile("out.qoi", .{});
    try qoi.encodeQoi(out.writer(), image);
}
