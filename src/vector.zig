const std = @import("std");

pub const Vec = @Vector(3, f32);

pub fn dot(self: Vec, other: Vec) f32 {
    return @reduce(.Add, self * other);
}
pub fn sq(t: anytype) @TypeOf(t) {
    return t * t;
}
/// Squared absolute value
pub fn sabs(self: Vec) f32 {
    return dot(self, self);
}

pub fn abs(self: Vec) f32 {
    return @sqrt(sabs(self));
}

pub fn normalize(self: Vec) Vec {
    return self / @as(Vec, @splat(abs(self)));
}

pub fn lerp(a: Vec, b: Vec, t: f32) Vec {
    return a + (b - a) * @as(Vec, @splat(t));
}

pub fn cross_product(a: Vec, b: Vec) Vec {
    return (@shuffle(f32, a, undefined, @Vector(3, i32){ 1, 2, 0 }) *
        @shuffle(f32, b, undefined, @Vector(3, i32){ 2, 0, 1 })) -
        (@shuffle(f32, a, undefined, @Vector(3, i32){ 2, 0, 1 }) *
        @shuffle(f32, b, undefined, @Vector(3, i32){ 1, 2, 0 }));
}

test "Abs" {
    try std.testing.expect(abs(Vec{ 0, 3, 4 }) == 5.0);
}
