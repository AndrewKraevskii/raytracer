const Vec = @import("Vec.zig");

const Matrix = @This();

data: [4][4]f32,

pub fn mmul(_a: Matrix, _b: Matrix) Matrix {
    const a = _a.data;
    const b = _b.data;
    return .{
        .data = .{
            .{a[0][0] * b[0][0] + a[0][1] * b[1][0] + a[0][2] * b[2][0] + a[0][3] * b[3][0]},
            .{a[1][0] * b[0][1] + a[1][1] * b[1][1] + a[1][2] * b[2][1] + a[1][3] * b[3][1]},
            .{a[2][0] * b[0][2] + a[2][1] * b[1][2] + a[2][2] * b[2][2] + a[2][3] * b[3][2]},
            .{a[3][0] * b[0][3] + a[3][1] * b[1][3] + a[3][2] * b[2][3] + a[3][3] * b[3][3]},
        },
    };
}

pub fn vmul(
    mat: Matrix,
    vec: Vec,
) Vec {
    const b = mat.data;
    return .{
        .x = vec.x * b[0][0] + vec.y * b[1][0] + vec.z * b[2][0] + 1 * b[3][0],
        .y = vec.x * b[0][1] + vec.y * b[1][1] + vec.z * b[2][1] + 1 * b[3][1],
        .z = vec.x * b[0][2] + vec.y * b[1][2] + vec.z * b[2][2] + 1 * b[3][2],
    };
}

pub fn scale(x: f32, y: f32, z: f32) Matrix {
    return .{
        .data = .{
            .{ x, 0, 0, 0 },
            .{ 0, y, 0, 0 },
            .{ 0, 0, z, 0 },
            .{ 0, 0, 0, 1 },
        },
    };
}

pub fn translate(x: f32, y: f32, z: f32) Matrix {
    return .{
        .data = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ x, y, z, 1 },
        },
    };
}

const testing = @import("std").testing;

test {
    const vec: Vec = .{ .x = 1, .y = 2, .z = 3 };
    const mat: Matrix = .{
        .data = .{
            .{ 1, 2, 3, 4 },
            .{ 5, 6, 7, 8 },
            .{ 9, 10, 11, 12 },
            .{ 13, 14, 15, 16 },
        },
    };

    const result = mat.vmul(vec);
    try testing.expectEqual(
        result,
        Vec{
            .x = 51,
            .y = 58,
            .z = 65,
        },
    );
}
