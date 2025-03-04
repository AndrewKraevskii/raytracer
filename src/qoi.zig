//! This module provides functions for parsing Qoi image format.

const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;

const Header = packed struct(u80) {
    pub const Channels = enum(u8) {
        RGB = 3,
        RGBA = 4,
    };
    pub const ColorSpace = enum(u8) {
        sRGB = 0,
        AllLinear = 1,
    };
    const magic: [4]u8 = .{ 'q', 'o', 'i', 'f' };

    width: u32,
    height: u32,
    channels: Channels,
    colorspace: ColorSpace,

    fn parse(data: []const u8) error{
        FileIsToShort,
        WrongMagic,
        ChannelDoesNotExist,
        ColorSpaceDoesNotExist,
    }!@This() {
        if (data.len < 14) return error.FileIsToShort;
        if (!std.mem.eql(u8, data[0..4], &magic)) return error.WrongMagic;

        const width = std.mem.readInt(u32, data[4..8], .big);
        const height = std.mem.readInt(u32, data[8..12], .big);
        const channels: Channels = std.meta.intToEnum(Channels, data[12]) catch {
            return error.ChannelDoesNotExist;
        };
        const colorspace: ColorSpace = std.meta.intToEnum(ColorSpace, data[13]) catch {
            return error.ColorSpaceDoesNotExist;
        };
        return .{
            .width = width,
            .height = height,
            .channels = channels,
            .colorspace = colorspace,
        };
    }

    fn encode(self: @This()) [14]u8 {
        var res: [10]u8 = undefined;

        std.mem.writeInt(u32, res[0..4], self.width, .big);
        std.mem.writeInt(u32, res[4..8], self.height, .big);
        res[8] = @intFromEnum(self.channels);
        res[9] = @intFromEnum(self.colorspace);
        return magic ++ res;
    }
};

fn colorHash(color: Color) u6 {
    return @as(u6, @truncate(color.r)) *% 3 +%
        @as(u6, @truncate(color.g)) *% 5 +%
        @as(u6, @truncate(color.b)) *% 7 +%
        @as(u6, @truncate(color.a)) *% 11;
}

const MASK = 0b1100_0000;

const OP_RGB = 0b1111_1110;
const OP_RGBA = 0b1111_1111;
const OP_INDEX = 0b0000_0000;
const OP_DIFF = 0b0100_0000;
const OP_LUMA = 0b1000_0000;
const OP_RUN = 0b1100_0000;
const END: [8]u8 = .{0x00} ** 7 ++ .{0x01};

pub fn parse(alloc: std.mem.Allocator, data: []const u8) !Image {
    const header: Header = try .parse(data);

    var image: Image = try .createUndefined(alloc, .{ header.height, header.width });
    var prev_pixel_value: Color = .black;

    var array: [64]Color = @splat(.blank);

    var qoi_index: usize = 14;
    var image_index: usize = 0;
    var image_data = image.slice();
    while (image_index < image_data.len) {
        if (qoi_index + 8 >= data.len or std.mem.eql(u8, data[qoi_index .. qoi_index + 8], &END)) {
            break;
        }
        if (data[qoi_index] == OP_RGB) {
            const next: Color = .{
                .r = data[qoi_index + 1],
                .g = data[qoi_index + 2],
                .b = data[qoi_index + 3],
                .a = prev_pixel_value.a,
            };
            prev_pixel_value = next;
            array[colorHash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 4;
            image_index += 1;
        } else if (data[qoi_index] == OP_RGBA) {
            const next: Color = .{
                .r = data[qoi_index + 1],
                .g = data[qoi_index + 2],
                .b = data[qoi_index + 3],
                .a = data[qoi_index + 4],
            };
            qoi_index += 5;
            array[colorHash(next)] = next;
            image_data[image_index] = next;
            prev_pixel_value = next;
            image_index += 1;
        } else if (data[qoi_index] & MASK == OP_INDEX) {
            image_data[image_index] = array[data[qoi_index] & 0b0011_1111];
            prev_pixel_value = image_data[image_index];
            qoi_index += 1;
            image_index += 1;
        } else if (data[qoi_index] & MASK == OP_DIFF) {
            const next: Color = .{
                .a = prev_pixel_value.a,
                .r = prev_pixel_value.r +% (data[qoi_index] & 0b0011_0000 >> 4) -% 2,
                .g = prev_pixel_value.g +% (data[qoi_index] & 0b0000_1100 >> 2) -% 2,
                .b = prev_pixel_value.b +% (data[qoi_index] & 0b0000_0011) -% 2,
            };
            prev_pixel_value = next;
            array[colorHash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 1;
            image_index += 1;
        } else if (data[qoi_index] & MASK == OP_LUMA) {
            const dgreen = data[qoi_index] & 0b0011_1111;
            const drdg = data[qoi_index + 1] & 0b1111_0000 >> 4;
            const dbdg = data[qoi_index + 1] & 0b0000_1111;
            const next = Color{
                .a = prev_pixel_value.a,
                .r = prev_pixel_value.r +% drdg -% 8 +% dgreen -% 32,
                .g = prev_pixel_value.g +% dgreen -% 32,
                .b = prev_pixel_value.g +% dbdg -% 8 +% dgreen -% 32,
            };
            prev_pixel_value = next;
            array[colorHash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 2;
            image_index += 1;
        } else if (data[qoi_index] & MASK == OP_RUN) {
            const len = (data[qoi_index] & 0b0011_1111) + 1;
            @memset(image_data[image_index .. image_index + len], prev_pixel_value);
            qoi_index += 1;
            image_index += len;
        }
    }
    return image;
}

pub fn encode(write_buffer: anytype, image: Image) !void {
    const header: Header = .{
        .width = image.width,
        .height = image.height,
        .channels = .RGBA,
        .colorspace = .sRGB,
    };
    try write_buffer.writeAll(&header.encode());

    var prev_pixel_value: Color = .black;
    var array: [64]Color = @splat(.blank);
    var pixel_run: u6 = 0;
    for (image.slice()) |pixel| {
        defer prev_pixel_value = pixel;
        const eq = std.meta.eql(pixel, prev_pixel_value);
        if (eq) {
            pixel_run += 1;
        }
        if (pixel_run > 0 and (pixel_run == 62 or !eq)) {
            try write_buffer.writeByte(OP_RUN | @as(u8, pixel_run - 1));
            pixel_run = 0;
        }
        if (eq) continue;
        const hash = colorHash(pixel);
        if (std.meta.eql(array[hash], pixel)) {
            try write_buffer.writeByte(OP_INDEX | hash);
            continue;
        }
        array[hash] = pixel;

        const diff_r = @as(i16, pixel.r) - @as(i16, prev_pixel_value.r);
        const diff_g = @as(i16, pixel.g) - @as(i16, prev_pixel_value.g);
        const diff_b = @as(i16, pixel.b) - @as(i16, prev_pixel_value.b);
        const diff_a = @as(i16, pixel.a) - @as(i16, prev_pixel_value.a);

        if (diff_a != 0) {
            try write_buffer.writeAll(&[5]u8{ OP_RGBA, pixel.r, pixel.g, pixel.b, pixel.a });
            continue;
        }

        if (-2 <= diff_r and diff_r < 2 and -2 <= diff_g and diff_g < 2 and -2 <= diff_b and diff_b < 2) {
            try write_buffer.writeByte(OP_DIFF |
                @as(u8, @intCast((diff_r + 2) << 4)) |
                @as(u8, @intCast((diff_g + 2) << 2)) |
                @as(u8, @intCast(diff_b + 2)));
            continue;
        }

        const dr_dg = diff_r - diff_g;
        const db_dg = diff_b - diff_g;

        if (-32 <= diff_g and diff_g < 32 and -8 <= dr_dg and dr_dg < 8 and -8 <= db_dg and db_dg < 8) {
            try write_buffer.writeAll(&.{
                OP_LUMA | @as(u8, @intCast(diff_g + 32)),
                (@as(u8, @intCast(dr_dg + 8)) << 4) | (@as(u8, @intCast(db_dg + 8))),
            });
            continue;
        }
        try write_buffer.writeAll(&.{ OP_RGB, pixel.r, pixel.g, pixel.b });
    }
    if (pixel_run > 0) {
        try write_buffer.writeByte(OP_RUN | @as(u8, pixel_run));
    }

    try write_buffer.writeAll(&END);
}

const expect = std.testing.expect;

test "Parsing header test" {
    const test_image = @embedFile("assets/qoi_logo.qoi");
    const header: Header = try .parse(test_image[0..]);
    try expect(std.meta.eql(header, .{ .width = 448, .height = 220, .channels = .RGBA, .colorspace = .sRGB }));

    for (0..14) |i| {
        try std.testing.expectError(error.FileIsToShort, Header.parse(test_image[0..i]));
    }
    _ = parse;
}

test "Parsing image" {
    const alloc = std.testing.allocator;
    const test_image = @embedFile("assets/qoi_logo.qoi");
    var image = try parse(alloc, test_image);
    defer image.deinit(alloc);
}
