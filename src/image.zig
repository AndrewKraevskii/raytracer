const std = @import("std");

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,
    pub const WHITE = @This(){ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const BLACK = @This(){ .r = 0, .g = 0, .b = 0, .a = 255 };

    pub fn as_gray(self: @This()) u8 {
        return @intCast((@as(u16, self.r) + @as(u16, self.g) + @as(u16, self.b)) / 3);
    }
};

pub const Image = struct {
    height: u32,
    width: u32,
    data: [*]Color,
    alloc: std.mem.Allocator,

    pub fn zeroed(
        alloc: std.mem.Allocator,
        dim: [2]u32,
    ) !@This() {
        const len = dim[0] * dim[1];
        const memory = try alloc.alloc(Color, len);
        for (memory) |*m| {
            m.* = Color.BLACK;
        }
        return @This(){
            .height = dim[0],
            .width = dim[1],
            .data = memory.ptr,
            .alloc = alloc,
        };
    }

    /// Returens number of pixels in image
    pub fn size(self: @This()) usize {
        return self.height * self.width;
    }

    pub fn deinit(self: *@This()) void {
        self.alloc.free(self.data[0..self.size()]);
    }

    pub fn get(self: @This(), x: usize, y: usize) Color {
        std.debug.assert(y < self.height);
        std.debug.assert(x < self.width);
        return self.data[self.width * y + x];
    }

    pub fn get_mut(self: *@This(), x: usize, y: usize) *Color {
        std.debug.assert(y < self.height);
        std.debug.assert(x < self.width);
        return &self.data[self.width * y + x];
    }

    pub fn slice(self: *@This()) []Color {
        return self.data[0..self.size()];
    }
};
