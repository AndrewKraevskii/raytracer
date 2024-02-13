const std = @import("std");

const Image = struct {
    dim: [2]u16 = .{ 0, 0 },
    data: [*]u8,
    alloc: std.mem.Allocator,

    fn zero(
        alloc: std.mem.Allocator,
        dim: [2]u16,
    ) !@This() {
        const size = dim[0] * dim[1];
        const memory = try alloc.alloc(u8, size);
        for (memory) |*m| {
            m.* = 0;
        }
        return @This(){
            .dim = dim,
            .data = memory.ptr,
            .alloc = alloc,
        };
    }

    fn draw_ascii(
        self: @This(),
        writer: std.io.AnyWriter,
    ) void {
        for (0..self.dim[0]) |row| {
            for (0..self.dim[1]) |col| {
                const symbol: u8 = if (self.data[row * @as(usize, self.dim[1]) + col] < @as(usize, 128)) 'X' else '.';
                writer.print(
                    "{c}",
                    .{symbol},
                ) catch return;
            }
            writer.print("\n", .{}) catch return;
        }
    }

    fn deinit(self: *@This()) void {
        const size = self.dim[0] * self.dim[1];
        self.alloc.free(self.data[0..size]);
    }

    fn at(self: *@This(), point: Point(usize)) *u8 {
        return &self.data[self.dim[1] * point.y + point.x];
    }
};

fn Point(comptime inner: type) type {
    return struct {
        x: inner,
        y: inner,
    };
}

fn draw_circle(image: *Image, center: Point(f32), radius: f32) void {
    for (0..image.dim[0]) |col| {
        for (0..image.dim[1]) |row| {
            if (std.math.pow(f32, (center.x - @as(f32, @floatFromInt(col))), 2.0) +
                std.math.pow(f32, (center.y - @as(f32, @floatFromInt(row))), 2.0) < radius * radius)
            {
                image.at(.{ .x = col, .y = row }).* = 255;
            }
        }
    }
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buffer = [_]u8{0} ** 1000;
    var alloc = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const a = alloc.allocator();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var angle: f32 = 0.0;

    for (0..10000) |_| {
        var image = try Image.zero(a, .{ 30, 30 });
        defer image.deinit();

        draw_circle(&image, .{ .x = 10.0 + std.math.sin(angle) * 5, .y = 10.0 + std.math.cos(angle) * 10 }, 10.0);
        angle += 0.1;
        image.draw_ascii(stdout.any());
        // var array: [4]u8 = .{ 0, 255, 0, 255 };
        // (Image{ .size = .{ 2, 2 }, .data = &array }).draw_ascii(stdout.any());

        try bw.flush(); // don't forget to flush!
        std.time.sleep(10 * std.time.ns_per_ms);
    }
}
