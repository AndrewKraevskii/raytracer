const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;
const qoi = @import("qoi.zig");
const raytracing = @import("raytracing.zig");
const Vec = @import("Vec.zig");

const DEFAULT_IMAGE_SIZE = 640;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var args = std.process.args();
    _ = args.skip();
    const image_size = blk: {
        const text = args.next() orelse break :blk DEFAULT_IMAGE_SIZE;
        break :blk try std.fmt.parseInt(u16, text, 10);
    };

    var image: Image = try .zeroed(gpa.allocator(), .{ image_size, image_size });
    defer image.deinit(gpa.allocator());

    const camera: raytracing.Camera = .{
        .position = .init(0, 0, 20),
        .right = .init(25, 0, 0),
        .up = .init(0, 25, 0),
        .height = @floatFromInt(image_size),
        .width = @floatFromInt(image_size),
        .focal_distance = 50,
    };

    image.fill(.black);

    for (0..5) |i| {
        for (0..5) |j| {
            for (0..5) |k| {
                raytracing.drawSphere(&image, camera, .{
                    .center = .init(
                        @as(f32, @floatFromInt(i)) * 20 - 50,
                        @as(f32, @floatFromInt(j)) * 20 - 50,
                        @as(f32, @floatFromInt(k)) * 20 - 50,
                    ),
                    .radius = 10,
                });
            }
        }
    }

    const out = try std.fs.cwd().createFile("out.qoi", .{});
    defer out.close();
    var buffered = std.io.bufferedWriter(out.writer());
    defer _ = buffered.flush() catch |e| {
        std.log.err("error while flushing file: {s}", .{@errorName(e)});
    };

    try qoi.encode(buffered.writer(), image);
}

test {
    _ = @import("image.zig");
    _ = @import("qoi.zig");
    _ = @import("raytracing.zig");
    _ = @import("Vec.zig");
    _ = @import("Matrix.zig");
}
