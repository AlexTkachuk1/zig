const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");
const math = std.math;
const rand = std.rand;

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

fn drawLines(org: Vector2, scale: f32, rot: f32, points: []const Vector2) void {
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

const AsteroidSize = enum {
    BIG,
    MEDIUM,
    SMALL,

    fn size(self: @This()) f32 {
        return switch (self) {
            .BIG => SCALE * 3.0,
            .MEDIUM => SCALE * 1.4,
            .SMALL => SCALE * 0.8,
        };
    }
};

fn drawAsteroid(pos: Vector2, size: AsteroidSize, seed: u64) !void {

    var prng = rand.Xoshiro256.init(seed);
    var random = prng.random();

    var points = try std.BoundedArray(Vector2, 16).init(0);
    const n = random.intRangeLessThan(i32, 8, 15);

    for (0..@intCast(n)) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));

        if (random.float(f32) < 0.2) {
            radius -= 0.2;
        }

        const angle = (@as(f32, @floatFromInt(i)) * (math.tau / @as(f32, @floatFromInt(n)))) + (math.pi * 0.125 * random.float(f32));

        try points.append(
            rlm.vector2Scale(Vector2.init(math.cos(angle), math.sin(angle)), radius)
        );
    }
    
    drawLines(
        pos,
        size.size(),
        0.0,
        points.slice()
    );
}

fn update() !void {
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

fn render() !void {
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

    if (rl.isKeyDown(.key_w) and @mod(@as(i32, @intFromFloat(state.now * 20)), 2) == 0) {
        drawLines(
            state.ship.pos,
            SCALE,
            state.ship.rot,
            &.{
                Vector2.init(-0.2, -0.4),
                Vector2.init(0.0, -0.8),
                Vector2.init(0.2, -0.4),
            },
        );
    }

    try drawAsteroid(Vector2.init(50, 50), AsteroidSize.BIG, 2330);
    try drawAsteroid(Vector2.init(250, 250), AsteroidSize.BIG, 2130);
    try drawAsteroid(Vector2.init(450, 450), AsteroidSize.BIG, 2338);
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

        try update();

        rl.beginDrawing();
        defer rl.endDrawing();

        try render();

        rl.clearBackground(rl.Color.black);
    }
}
