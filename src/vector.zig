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

pub const Sphere = struct {
    center: Vec,
    radius: f32,
};

pub const Ray = struct {
    start: Vec,
    direction: Vec,
};

pub const IntersectionPoint = struct {
    distance: f32,
    point: Vec,
    normal: Vec,
};

pub const RaySphereIntersection = struct {
    IntersectionPoint,
    IntersectionPoint,
};

pub fn intersectRaySphere(ray: Ray, sphere: Sphere) ?RaySphereIntersection {
    const discriminant = sq(dot(ray.direction, ray.start - sphere.center)) +
        sabs(ray.direction) * (sq(sphere.radius) - sabs(ray.start) +
        2 * dot(ray.start, sphere.center) - sabs(sphere.center));
    if (discriminant < 0) return null;
    const res = dot(ray.direction, (sphere.center - ray.start)) / sabs(ray.direction);
    const distance = .{
        res - @sqrt(discriminant) / sabs(ray.direction),
        res + @sqrt(discriminant) / sabs(ray.direction),
    };

    const normals = .{
        normalize(ray.start + ray.direction * @as(Vec, @splat(distance[0])) - sphere.center),
        normalize(ray.start + ray.direction * @as(Vec, @splat(distance[1])) - sphere.center),
    };

    return .{ .{
        .distance = distance[0],
        .normal = normals[0],
        .point = ray.start + ray.direction * @as(Vec, @splat(distance[0])),
    }, .{
        .distance = distance[1],
        .normal = normals[1],
        .point = ray.start + ray.direction * @as(Vec, @splat(distance[1])),
    } };
}

test "Intersect" {
    const res = intersectRaySphere(.{
        .start = .{ 0, 0, -20 },
        .direction = .{ 0, 0, 1 },
    }, .{
        .center = .{ 0, 0, 0 },
        .radius = 1,
    }) orelse return error.ShouldIntersect;
    try std.testing.expectApproxEqAbs(19, res[0].distance, 0.0000000001);
    try std.testing.expectApproxEqAbs(21, res[1].distance, 0.0000000001);
}

test "Not Intersect" {
    try std.testing.expectEqual(null, intersectRaySphere(.{
        .start = .{ 0, 0, -20 },
        .direction = .{ 0, 1, 1 },
    }, .{
        .center = .{ 0, 0, 0 },
        .radius = 1,
    }));
}

test "Abs" {
    try std.testing.expect(abs(Vec{ 0, 3, 4 }) == 5.0);
}
