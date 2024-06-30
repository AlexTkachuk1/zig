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
    asteroids: std.ArrayList(Asteroid),
    asteroids_queue: std.ArrayList(Asteroid),
    particles: std.ArrayList(Particle),
    projectiles: std.ArrayList(Projectile),
    rand: rand.Random,
};

const Asteroid = struct {
    pos: Vector2,
    vel: Vector2,
    size: AsteroidSize,
    seed: u64,
    remove: bool = false,
};

const Ship = struct {
    pos: Vector2,
    vel: Vector2,
    rot: f32,
    deathTime: f32 = 0.0,

    fn isDead(self: @This()) bool {
        return self.deathTime != 0.0;
    }
};

const ParticleType = enum {
    LINE,
    DOT,
};

const Particle = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,

    values: union(ParticleType) {
        LINE: struct {
        rot: f32,
        len: f32,
        },
        DOT: struct {
            radius: f32,
        },
    },
};

const Projectile = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,
    remove: bool = false,
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

    fn collisionScale(self: @This()) f32 {
        return switch (self) {
            .BIG => 0.4,
            .MEDIUM => 0.65,
            .SMALL => 1.0,
        };
    }

    fn velosityScale(self: @This()) f32 {
        return switch (self) {
            .BIG => 0.75,
            .MEDIUM => 1.0,
            .SMALL => 1.8,
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

fn hitAsteroid(a: *Asteroid, impact: ?Vector2) !void {
    a.remove = true;

    if (a.size == .SMALL) {
        return;
    }

    for(0..2) |_| {
        const dir = rlm.vector2Normalize(a.vel);
        const size: AsteroidSize = switch (a.size) {
            .BIG => .MEDIUM,
            .MEDIUM => .SMALL,
            else => unreachable,
        };

        try state.asteroids_queue.append(
            .{
                .pos = a.pos,
                .vel = rlm.vector2Add(
                    rlm.vector2Scale(
                        dir,
                        a.size.velosityScale() * 1.5 * state.rand.float(f32),
                    ),
                    if (impact) |i| rlm.vector2Scale(i, 1.5) else Vector2.init(0,0),
                ),
                .size = size,
                .seed = state.rand.int(u64),
            }
        );
    }
}

fn update() !void {
    if (!state.ship.isDead()) {
        //rotation / second
        const ROT_SPEED: f32 = 1.0;
        const SHIP_SPEED: f32 = 24.0;

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

        const DRAG: f32 = 0.018;
        state.ship.vel = rlm.vector2Scale(state.ship.vel, 1.0 - DRAG);
        state.ship.pos = rlm.vector2Add(state.ship.pos, state.ship.vel);
        state.ship.pos = Vector2.init(
            @mod(state.ship.pos.x, SIZE.x),
            @mod(state.ship.pos.y, SIZE.y),
        );

        if (rl.isKeyPressed(.key_space) or rl.isMouseButtonPressed(.mouse_button_left)) {
            try state.projectiles.append(.{
                .pos = rlm.vector2Add(
                    state.ship.pos,
                    rlm.vector2Scale(shipDir, SCALE * 0.55),
                ),
                .vel = rlm.vector2Scale(shipDir, 10),
                .ttl = 1.0,
            });

            state.ship.vel = rlm.vector2Add(state.ship.vel, rlm.vector2Scale(shipDir, -0.5));
        }
    }

    // add asteroids from queue

    for (state.asteroids_queue.items) |a| {
        try state.asteroids.append(a);
    }
    try state.asteroids_queue.resize(0);

    {
        var i: usize = 0;
        while (i < state.asteroids.items.len) {
            var a = &state.asteroids.items[i];
            a.pos = rlm.vector2Add(a.pos, a.vel);

            a.pos = Vector2.init(
                @mod(a.pos.x, SIZE.x),
                @mod(a.pos.y, SIZE.y),
            );

            if (!state.ship.isDead() and rlm.vector2Distance(a.pos, state.ship.pos) < a.size.size() * a.size.collisionScale()) {
                state.ship.deathTime = state.now;

                for (0..5) |_| {
                    const angle = math.tau * state.rand.float(f32);
                    try state.particles.append(.{
                        .pos = rlm.vector2Add(
                            state.ship.pos,
                            Vector2.init(
                                state.rand.float(f32) * 3,
                                state.rand.float(f32) * 3,
                            ),
                        ),
                        .vel = rlm.vector2Scale(
                            Vector2.init(math.cos(angle), math.sin(angle)),
                            2.0 * state.rand.float(f32),

                        ),
                        .ttl = 2.0 + state.rand.float(f32),
                        .values = .{
                            .LINE = .{
                                .rot = math.tau * state.rand.float(f32),
                                .len = SCALE * (0.2 + (0.8 * state.rand.float(f32))),
                            }
                        }

                    });
                }
            }

            // check for projectile v. asteroid collision
            for (state.projectiles.items) |*p| {
                if (!p.remove and rlm.vector2Distance(a.pos, p.pos) < a.size.size() * a.size.collisionScale()) {
                    p.remove = true;
                    try hitAsteroid(a, rlm.vector2Normalize(p.vel));
                }
            }

            if (a.remove) {
                _ = state.asteroids.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    {
        var i: usize = 0;
        while (i < state.particles.items.len) {
            var p = &state.particles.items[i];

            p.pos = rlm.vector2Add(p.pos, p.vel);

            p.pos = Vector2.init(
                @mod(p.pos.x, SIZE.x),
                @mod(p.pos.y, SIZE.y),
            );
            if (p.ttl > state.delta) {
                p.ttl -= state.delta;
                i += 1;
            } else {
                _ = state.particles.swapRemove(i);
            }
        }
    }

    {
        var i: usize = 0;
        while (i < state.projectiles.items.len) {
            var p = &state.projectiles.items[i];

            p.pos = rlm.vector2Add(p.pos, p.vel);

            p.pos = Vector2.init(
                @mod(p.pos.x, SIZE.x),
                @mod(p.pos.y, SIZE.y),
            );
            if (!p.remove and p.ttl > state.delta) {
                p.ttl -= state.delta;
                i += 1;
            } else {
                _ = state.projectiles.swapRemove(i);
            }
        }
    }

    if (state.ship.isDead() and (state.now - state.ship.deathTime) > 3.0) {
        try resetStage();
    }
}

fn render() !void {
    if (!state.ship.isDead()) {
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
    }

    for (state.asteroids.items) |a| {
        try drawAsteroid(a.pos, a.size, a.seed);
    }

    for (state.particles.items) |p| {
        switch (p.values) {
            .LINE => |line| {
                drawLines(p.pos, line.len, line.len, &.{
                    Vector2.init(-0.5, 0),
                    Vector2.init(0.5, 0),
                });
            },
            .DOT => |dot| {
                rl.drawCircleV(p.pos, dot.radius, rl.Color.white);
            }
        }
    }

    for (state.projectiles.items) |p| {
        rl.drawCircleV(p.pos, @max(SCALE * 0.05, 1), rl.Color.white);
    }
}

fn resetAsteroids() !void {
    try state.asteroids.resize(0);

    for(0..14) |_| {
        const angle = math.tau * state.rand.float(f32);
        const size = state.rand.enumValue(AsteroidSize);

         try state.asteroids_queue.append(
            .{
                .pos = Vector2.init(
                    state.rand.float(f32) * SIZE.x,
                    state.rand.float(f32) * SIZE.y,
                ),
                .vel = rlm.vector2Scale(
                    Vector2.init(
                        math.cos(angle),
                        math.sin(angle)
                    ),
                    size.velosityScale() * 3.0 * state.rand.float(f32),
                ),
                .size = size,
                .seed = state.rand.int(u64),
            }
        );
    }
}

fn resetStage() !void {
    state.ship.deathTime = 0.0;

    state.ship = .{
        .rot = 0.0,
        .pos = rlm.vector2Scale(SIZE, 0.5),
        .vel = Vector2.init(0, 0),
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    rl.initWindow(SIZE.x , SIZE.y, "LARGE SPACE ROCKS");
    rl.setWindowPosition(100, 100);
    rl.setTargetFPS(60);

    var prng = rand.Xoshiro256.init(@bitCast(std.time.timestamp()));

    state = .{
        .ship = .{
            .rot = 0.0,
            .pos = rlm.vector2Scale(SIZE, 0.5),
            .vel = Vector2.init(0, 0),
        },
        .asteroids = std.ArrayList(Asteroid).init(allocator),
        .asteroids_queue = std.ArrayList(Asteroid).init(allocator),
        .particles = std.ArrayList(Particle).init(allocator),
        .projectiles = std.ArrayList(Projectile).init(allocator),
        .rand = prng.random(),
    };

    defer state.asteroids.deinit();
    defer state.asteroids_queue.deinit();
    defer state.particles.deinit();
    defer state.projectiles.deinit();

    try resetStage();
    try resetAsteroids();

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
