const std = @import("std");

const Vec = @This();

x: f32,
y: f32,
z: f32,

pub fn init(x: f32, y: f32, z: f32) Vec {
    return .{
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn add(a: Vec, b: Vec) Vec {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z,
    };
}

pub fn sub(a: Vec, b: Vec) Vec {
    return .{
        .x = a.x - b.x,
        .y = a.y - b.y,
        .z = a.z - b.z,
    };
}

pub fn mul(a: Vec, n: f32) Vec {
    return .{
        .x = a.x * n,
        .y = a.y * n,
        .z = a.z * n,
    };
}

pub fn dot(a: Vec, b: Vec) f32 {
    return a.x * b.x +
        a.y * b.y +
        a.z * b.z;
}

pub fn sq(t: Vec) Vec {
    return .{
        .x = t.x * t.x,
        .y = t.y * t.y,
        .z = t.z * t.z,
    };
}

/// Squared absolute value
pub fn sabs(self: Vec) f32 {
    return dot(self, self);
}

pub fn abs(self: Vec) f32 {
    return @sqrt(sabs(self));
}

pub fn normalize(self: Vec) Vec {
    return self.mul(1 / self.abs());
}

pub fn lerp(a: Vec, b: Vec, t: f32) Vec {
    return a.add(b.sub(a).mul(t));
}

pub fn crossProduct(a: Vec, b: Vec) Vec {
    const _a = @Vector(3, f32){ a.x, a.y, a.z };
    const _b = @Vector(3, f32){ b.x, b.y, b.z };
    const res = (@shuffle(f32, _a, undefined, @Vector(3, i32){ 1, 2, 0 }) *
        @shuffle(f32, _b, undefined, @Vector(3, i32){ 2, 0, 1 })) -
        (@shuffle(f32, _a, undefined, @Vector(3, i32){ 2, 0, 1 }) *
        @shuffle(f32, _b, undefined, @Vector(3, i32){ 1, 2, 0 }));

    return .{
        .x = res[0],
        .y = res[1],
        .z = res[2],
    };
}

test "Abs" {
    try std.testing.expect(abs(.init(0, 3, 4)) == 5.0);
}
