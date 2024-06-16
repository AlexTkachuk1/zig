const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    std.debug.print("Helloaaaaa world!\n", .{});
    rl.initWindow(1280, 700, "LARGE SPACE ROCKS");
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
    }
}
