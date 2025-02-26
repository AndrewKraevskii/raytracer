const std = @import("std");

pub const Color = packed struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    // zig fmt: off
    pub const white: @This() = .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 0xff };
    pub const black: @This() = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff };
    pub const blank: @This() = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 };
    pub const red: @This()   = .{ .r = 0xff, .g = 0x00, .b = 0x00, .a = 0xff };
    pub const green: @This() = .{ .r = 0x00, .g = 0xff, .b = 0x00, .a = 0xff };
    pub const blue: @This()  = .{ .r = 0x00, .g = 0xff, .b = 0xff, .a = 0xff };
    // zig fmt: on

    pub fn asGray(self: @This()) u8 {
        return @intCast((@as(u16, self.r) + @as(u16, self.g) + @as(u16, self.b)) / 3);
    }
};

pub const Image = struct {
    height: u32,
    width: u32,
    data: [*]Color,

    /// Creates image with all pixels set to `color`
    pub fn filled(
        alloc: std.mem.Allocator,
        dimensions: [2]u32,
        color: Color,
    ) !@This() {
        var image = try createUndefined(alloc, dimensions);
        fill(&image, color);
        return image;
    }

    /// Creates image with pixels initialized to zero
    pub fn zeroed(
        alloc: std.mem.Allocator,
        dim: [2]u32,
    ) !@This() {
        return filled(alloc, dim, .black);
    }

    /// Create image without initializing pixel values
    pub fn createUndefined(
        alloc: std.mem.Allocator,
        dim: [2]u32,
    ) !@This() {
        const len = dim[0] * dim[1];
        const memory = try alloc.alloc(Color, len);
        return @This(){
            .height = dim[0],
            .width = dim[1],
            .data = memory.ptr,
        };
    }

    /// Fill whole image with provided color
    pub fn fill(
        self: *@This(),
        color: Color,
    ) void {
        @memset(self.slice(), color);
    }

    /// Returens number of pixels in image
    pub fn size(self: @This()) usize {
        return self.height * self.width;
    }

    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        gpa.free(self.data[0..self.size()]);
    }

    /// Returns pointer to pixel color. If index out of bounds raises panic
    pub fn get(self: @This(), x: usize, y: usize) *Color {
        std.debug.assert(y < self.height);
        std.debug.assert(x < self.width);
        return &self.data[self.width * y + x];
    }

    /// Returns slice to mutable underlaing data. Use it instead of `data` if you want slice and not just pointer.
    pub fn slice(self: *const @This()) []Color {
        return self.data[0..self.size()];
    }
};
