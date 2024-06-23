const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");
const math = std.math;

const Vector2 = rl.Vector2;
const THICKNESS = 1.5;
const SCALE = 32.0;
const SIZE = Vector2.init(640 * 1.5, 480 * 1.5);

const State = struct {
    now: f32 = 0,
    delta: f32 = 0,
    ship: Ship,
};

const Ship = struct {
    pos: Vector2,
    vel: Vector2,
    rot: f32,
};

var state: State = undefined;

pub fn drawLines(org: Vector2, scale: f32, rot: f32, points: []const Vector2) void {
    const Transformer = struct {
        org: Vector2,
        scale: f32,
        rot: f32,

        fn apply(self: @This(), p: Vector2) Vector2 {
            return rlm.vector2Add(rlm.vector2Scale(rlm.vector2Rotate(p, self.rot), self.scale), self.org);
        }
    };

    const t = Transformer {
        .org = org,
        .scale = scale,
        .rot = rot,
    };

    for (0..points.len) |i| {
        rl.drawLineEx(
            t.apply(points[i]),
            t.apply(points[(i + 1) % points.len]),
            THICKNESS,
            rl.Color.white,
        );
    }
}

// pub fn drawShip(pos: Vector2) void {
//     _ = pos;
// }

pub fn update() void {
    //rotation / second
    const ROT_SPEED: f32 = 1.0;
    const SHIP_SPEED: f32 = 32.0;

    if (rl.isKeyDown(.key_a)) {
        state.ship.rot -= state.delta * math.tau * ROT_SPEED;
    }

    if (rl.isKeyDown(.key_d)) {
        state.ship.rot += state.delta * math.tau * ROT_SPEED;
    }

    const dirAngle = state.ship.rot + (math.pi * 0.5);
    const shipDir = Vector2.init(math.cos(dirAngle), math.sin(dirAngle));
    if (rl.isKeyDown(.key_w)) {
        state.ship.vel = rlm.vector2Add(state.ship.vel, rlm.vector2Scale(shipDir, state.delta * SHIP_SPEED));
    }

    const DRAG: f32 = 0.03;
    state.ship.vel = rlm.vector2Scale(state.ship.vel, 1.0 - DRAG);
    state.ship.pos = rlm.vector2Add(state.ship.pos, state.ship.vel);
    state.ship.pos = Vector2.init(@mod(state.ship.pos.x, SIZE.x), @mod(state.ship.pos.y, SIZE.y));
}

pub fn render() void {
    drawLines(
        state.ship.pos,
        SCALE,
        state.ship.rot,
        &.{
            Vector2.init(-0.4, -0.5),
            Vector2.init(0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(0.3, -0.4),
            Vector2.init(-0.3, -0.4),
        },
    );
}

pub fn main() !void {
    rl.initWindow(SIZE.x , SIZE.y, "LARGE SPACE ROCKS");
    rl.setWindowPosition(100, 100);
    rl.setTargetFPS(60);

    state = .{
        .ship = .{
            .rot = 0.0,
            .pos = rlm.vector2Scale(SIZE, 0.5),
            .vel = Vector2.init(0, 0),
        }
    };

    while (!rl.windowShouldClose()) {
        state.delta = rl.getFrameTime();
        state.now  += state.delta;

        update();

        rl.beginDrawing();
        defer rl.endDrawing();

        render();

        rl.clearBackground(rl.Color.black);
    }
}
