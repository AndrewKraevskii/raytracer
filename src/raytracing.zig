const std = @import("std");
const vec = @import("vector.zig");
const Vec = vec.Vec;
const Image = @import("image.zig").Image;
const Color = @import("image.zig").Color;

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

pub const OrthographicCamera = struct {
    position: Vec,
    right: Vec,
    up: Vec,
    height: f32,
    width: f32,

    pub fn lookAt(self: @This(), position: Vec, target: Vec) @This() {
        return .{
            .position = position,
            .up = self.up,
            .right = vec.crossProduct(self.up, -position + target),
            .height = self.height,
            .width = self.width,
        };
    }

    fn topLeft(self: @This()) Vec {
        return self.position -
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) +
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn topRight(self: @This()) Vec {
        return self.position +
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) +
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn bottomLeft(self: @This()) Vec {
        return self.position -
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) -
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn bottomRight(self: @This()) Vec {
        return self.position +
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) -
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    /// Accepts x and y coodrinates of sceen in range of 0..1 and returnes ray that passes throw that pixel
    fn getRay(self: @This(), x: f32, y: f32) Ray {
        std.debug.assert(0 <= x);
        std.debug.assert(x <= 1);
        std.debug.assert(0 <= y);
        std.debug.assert(y <= 1);

        return Ray{
            .start = vec.lerp(
                vec.lerp(self.topLeft(), self.topRight(), x),
                vec.lerp(self.bottomLeft(), self.bottomRight(), x),
                y,
            ),
            .direction = vec.normalize(vec.crossProduct(self.right, self.up)),
        };
    }
};

pub const PerspectiveCamera = struct {
    position: Vec,
    right: Vec,
    up: Vec,
    height: f32,
    width: f32,
    focal_distance: f32,

    pub fn lookAt(self: @This(), position: Vec, target: Vec) @This() {
        return .{
            .position = position,
            .up = self.up,
            .right = vec.crossProduct(self.up, -position + target),
            .height = self.height,
            .width = self.width,
            .focal_distance = self.focal_distance,
        };
    }

    fn topLeft(self: @This()) Vec {
        return self.position -
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) +
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn topRight(self: @This()) Vec {
        return self.position +
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) +
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn bottomLeft(self: @This()) Vec {
        return self.position -
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) -
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn bottomRight(self: @This()) Vec {
        return self.position +
            vec.normalize(self.right) * @as(Vec, @splat(self.width)) -
            vec.normalize(self.up) * @as(Vec, @splat(self.height));
    }

    fn front(self: @This()) Vec {
        return vec.crossProduct(self.right, self.up);
    }
    /// Accepts x and y coodrinates of sceen in range of 0..1 and returnes ray that passes throw that pixel
    fn getRay(self: @This(), x: f32, y: f32) Ray {
        std.debug.assert(0 <= x);
        std.debug.assert(x <= 1);
        std.debug.assert(0 <= y);
        std.debug.assert(y <= 1);
        const start = vec.lerp(
            vec.lerp(self.topLeft(), self.topRight(), x),
            vec.lerp(self.bottomLeft(), self.bottomRight(), x),
            y,
        );
        return Ray{
            .start = start,
            .direction = start - (self.position -
                vec.normalize(self.front()) *
                @as(Vec, @splat(self.focal_distance))),
        };
    }
};

pub fn drawSphere(image: *Image, camera: anytype, sphere: Sphere) void {
    for (0..image.height) |col| {
        for (0..image.width) |row| {
            const pos_x = @as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(image.height));
            const pos_y = @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(image.width));
            const ray = camera.getRay(pos_x, pos_y);
            if (intersectRaySphere(
                ray,
                sphere,
            )) |intersection| {
                image.getMut(col, row).* = Color{
                    .r = @intFromFloat(std.math.clamp(
                        (intersection[0].normal[0] * 255),
                        0.0,
                        255.0,
                    )),
                    .g = @intFromFloat(std.math.clamp(
                        (intersection[0].normal[1] * 255),
                        0.0,
                        255.0,
                    )),
                    .b = @intFromFloat(std.math.clamp(
                        (intersection[0].normal[2] * 255),
                        0.0,
                        255.0,
                    )),
                    .a = 255,
                };
            }
        }
    }
}

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
