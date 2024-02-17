const std = @import("std");
const vec = @import("vector.zig");
const Vec = vec.Vec;

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
    const discriminant = vec.sq(vec.dot(ray.direction, ray.start - sphere.center)) +
        vec.sabs(ray.direction) * (vec.sq(sphere.radius) - vec.sabs(ray.start) +
        2 * vec.dot(ray.start, sphere.center) - vec.sabs(sphere.center));
    if (discriminant < 0) return null;
    const res = vec.dot(ray.direction, (sphere.center - ray.start)) / vec.sabs(ray.direction);
    const distance = .{
        res - @sqrt(discriminant) / vec.sabs(ray.direction),
        res + @sqrt(discriminant) / vec.sabs(ray.direction),
    };

    const normals = .{
        vec.normalize(ray.start + ray.direction * @as(Vec, @splat(distance[0])) - sphere.center),
        vec.normalize(ray.start + ray.direction * @as(Vec, @splat(distance[1])) - sphere.center),
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
