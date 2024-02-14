//! This module provides functions for parsing Qoi image format.

const std = @import("std");
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;

const QoiHeader = packed struct {
    pub const Channels = enum(u8) {
        RGB = 3,
        RGBA = 4,
    };
    pub const ColorSpace = enum(u8) {
        sRGB = 0,
        AllLinear = 1,
    };
    const magic: [4]u8 = [4]u8{ 'q', 'o', 'i', 'f' };

    width: u32,
    height: u32,
    channels: Channels,
    colorspace: ColorSpace,

    fn parse_qoi_header(data: []const u8) !@This() {
        if (data.len < 14) return error.SliceIsTooShort;
        if (!std.mem.eql(u8, data[0..4], &QoiHeader.magic)) return error.WrongMagic;

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
};

fn color_hash(color: Color) u6 {
    return @as(u6, @truncate(color.r)) *% 3 +%
        @as(u6, @truncate(color.g)) *% 5 +%
        @as(u6, @truncate(color.b)) *% 7 +%
        @as(u6, @truncate(color.a)) *% 11;
}

const QOI_MASK = 0b1100_0000;

const QOI_OP_RGB = 0b1111_1110;
const QOI_OP_RGBA = 0b1111_1111;
const QOI_OP_INDEX = 0b0000_0000;
const QOI_OP_DIFF = 0b0100_0000;
const QOI_OP_LUMA = 0b1000_0000;
const QOI_OP_RUN = 0b1100_0000;
const QOI_END: [8]u8 = .{0x00} ** 7 ++ .{0x01};
pub fn parse_qoi(alloc: std.mem.Allocator, data: []const u8) !Image {
    const header = try QoiHeader.parse_qoi_header(data);

    var image = try Image.zeroed(alloc, .{ header.height, header.width });
    var prev_pixel_value = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    var array: [64]Color = .{Color{ .r = 0, .g = 0, .b = 0, .a = 0 }} ** 64;

    var qoi_index: usize = 14;
    var image_index: usize = 0;
    var image_data = image.slice();
    while (image_index < image_data.len) {
        if (std.mem.eql(u8, data[qoi_index .. qoi_index + 8], &QOI_END)) {
            break;
        }
        if (data[qoi_index] == QOI_OP_RGB) {
            const next = Color{
                .r = data[qoi_index + 1],
                .g = data[qoi_index + 2],
                .b = data[qoi_index + 3],
                .a = prev_pixel_value.a,
            };
            prev_pixel_value = next;
            array[color_hash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 4;
            image_index += 1;
        } else if (data[qoi_index] == QOI_OP_RGBA) {
            const next = Color{
                .r = data[qoi_index + 1],
                .g = data[qoi_index + 2],
                .b = data[qoi_index + 3],
                .a = data[qoi_index + 4],
            };
            qoi_index += 5;
            array[color_hash(next)] = next;
            image_data[image_index] = next;
            prev_pixel_value = next;
            image_index += 1;
        } else if (data[qoi_index] & QOI_MASK == QOI_OP_INDEX) {
            image_data[image_index] = array[data[qoi_index] & 0b0011_1111];
            prev_pixel_value = image_data[image_index];
            qoi_index += 1;
            image_index += 1;
        } else if (data[qoi_index] & QOI_MASK == QOI_OP_DIFF) {
            const next = Color{
                .a = prev_pixel_value.a,
                .r = prev_pixel_value.r +% (data[qoi_index] & 0b0011_0000 >> 4) -% 2,
                .g = prev_pixel_value.g +% (data[qoi_index] & 0b0000_1100 >> 2) -% 2,
                .b = prev_pixel_value.b +% (data[qoi_index] & 0b0000_0011) -% 2,
            };
            prev_pixel_value = next;
            array[color_hash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 1;
            image_index += 1;
        } else if (data[qoi_index] & QOI_MASK == QOI_OP_LUMA) {
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
            array[color_hash(next)] = next;
            image_data[image_index] = next;
            qoi_index += 2;
            image_index += 1;
        } else if (data[qoi_index] & QOI_MASK == QOI_OP_RUN) {
            const len = (data[qoi_index] & 0b0011_1111) + 1;
            @memset(image_data[image_index .. image_index + len], prev_pixel_value);
            qoi_index += 1;
            image_index += len;
        }
    }
    return image;
}

const expect = std.testing.expect;
test "Parsing header test" {
    const test_image = @embedFile("assets/qoi_logo.qoi");
    const header = try QoiHeader.parse_qoi_header(test_image[0..]);
    try expect(std.meta.eql(header, QoiHeader{ .width = 448, .height = 220, .channels = .RGBA, .colorspace = .sRGB }));

    for (0..14) |i| {
        try std.testing.expectError(error.SliceIsTooShort, QoiHeader.parse_qoi_header(test_image[0..i]));
    }
    _ = parse_qoi;
}
test "Parsing image" {
    const alloc = std.testing.allocator;
    const test_image = @embedFile("assets/qoi_logo.qoi");
    var image = try parse_qoi(alloc, test_image);
    defer image.deinit();
}
