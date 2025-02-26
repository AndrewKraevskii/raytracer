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
            .right = vec.crossProduct(self.up, target.sub(position)),
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

    /// Accepts x and y coordinates of sceen in range of 0..1 and returns ray that passes throw that pixel
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
            .right = vec.crossProduct(self.up, target.sub(position)),
            .height = self.height,
            .width = self.width,
            .focal_distance = self.focal_distance,
        };
    }

    fn topLeft(self: @This()) Vec {
        return self.position.sub(self.right.normalize().mul(self.width)).add(self.up.normalize().mul(self.height));
    }

    fn topRight(self: @This()) Vec {
        return self.position.add(self.right.normalize().mul(self.width)).add(self.up.normalize().mul(self.height));
    }

    fn bottomLeft(self: @This()) Vec {
        return self.position.sub(self.right.normalize().mul(self.width)).sub(self.up.normalize().mul(self.height));
    }

    fn bottomRight(self: @This()) Vec {
        return self.position.add(self.right.normalize().mul(self.width)).sub(self.up.normalize().mul(self.height));
    }

    fn front(self: @This()) Vec {
        return vec.crossProduct(self.right, self.up);
    }

    /// Accepts x and y coordinates of sceen in range of 0..1 and returns ray that passes throw that pixel
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
        return .{
            .start = start,
            .direction = start.sub(self.position.sub(vec.normalize(self.front()).mul(self.focal_distance))),
        };
    }
};

pub fn drawSphere(image: *Image, camera: anytype, sphere: Sphere) void {
    const step_x = @as(f32, 1) / @as(f32, @floatFromInt(image.height));
    const step_y = @as(f32, 1) / @as(f32, @floatFromInt(image.height));

    var pos_x: f32 = 0;
    for (0..image.height) |col| {
        defer pos_x += step_x;
        var pos_y: f32 = 0;
        for (0..image.width) |row| {
            defer pos_y += step_y;

            const ray = camera.getRay(pos_x, pos_y);
            if (intersectRaySphere(
                ray,
                sphere,
            )) |intersection| {
                image.get(col, row).* = .{
                    .r = @intFromFloat(std.math.clamp(
                        (intersection[0].normal.x * 255),
                        0.0,
                        255.0,
                    )),
                    .g = @intFromFloat(std.math.clamp(
                        (intersection[0].normal.y * 255),
                        0.0,
                        255.0,
                    )),
                    .b = @intFromFloat(std.math.clamp(
                        (intersection[0].normal.z * 255),
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
    const discriminant = (ray.direction.dot(ray.start.sub(sphere.center)) * ray.direction.dot(ray.start.sub(sphere.center))) +
        (vec.sabs(ray.direction) * (sphere.radius * sphere.radius - ray.start.sabs() +
        2 * ray.start.dot(sphere.center) - sphere.center.sabs()));

    if (discriminant < 0) return null;
    const res = vec.dot(ray.direction, (sphere.center.sub(ray.start))) / vec.sabs(ray.direction);
    const distance = .{
        res - @sqrt(discriminant) / vec.sabs(ray.direction),
        res + @sqrt(discriminant) / vec.sabs(ray.direction),
    };

    const normals = .{
        (ray.start.add(ray.direction.mul(distance[0])).sub(sphere.center)).normalize(),
        (ray.start.add(ray.direction.mul(distance[1])).sub(sphere.center)).normalize(),
    };

    return .{ .{
        .distance = distance[0],
        .normal = normals[0],
        .point = ray.start.add(ray.direction.mul(distance[0])),
    }, .{
        .distance = distance[1],
        .normal = normals[1],
        .point = ray.start.add(ray.direction.mul(distance[1])),
    } };
}

test "Intersect" {
    const res = intersectRaySphere(.{
        .start = .init(0, 0, -20),
        .direction = .init(0, 0, 1),
    }, .{
        .center = .init(0, 0, 0),
        .radius = 1,
    }) orelse return error.ShouldIntersect;
    try std.testing.expectApproxEqAbs(19, res[0].distance, 0.0000000001);
    try std.testing.expectApproxEqAbs(21, res[1].distance, 0.0000000001);
}

test "Not Intersect" {
    try std.testing.expectEqual(null, intersectRaySphere(.{
        .start = .init(0, 0, -20),
        .direction = .init(0, 1, 1),
    }, .{
        .center = .init(0, 0, 0),
        .radius = 1,
    }));
}
