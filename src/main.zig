const rl = @import("raylib");
const rm = @import("raymath");
const act = @import("actor.zig");
const mb = @import("mailbox.zig");

const Rect = rl.Rectangle;
const Vec2 = rl.Vector2;
const Color = rl.Color;
const Camera2D = rl.Camera2D;
const std = @import("std");
const PriorityQueue = std.PriorityQueue;

const NAME_OFFSET = 65;
const NAME_FONT_SIZE = 16;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var actControl = act.ActorControl.init(allocator);
    defer actControl.deinit();

    const player1 = try actControl.createCharActor("Cubelumbo");
    player1.color = .white;
    player1.position = Rect.init(700, 700, 60, 60);
    player1.player = true;

    const player2 = try actControl.createCharActor("Suspect");
    player2.color = .black;
    player2.position = Rect.init(800, 800, 60, 60);

    _ = try actControl.createConsole("Console", .{ "Welcome to Cubelumbo!", "Powered by actors", "Cause it's all for play" });

    const screenWidth = 1080;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Cubelumbo");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Main game loop
    while (!rl.windowShouldClose()) {

        // Update
        const camera: rl.Camera2D = .{
            .target = Vec2.init(player1.position.x, player1.position.y),
            .offset = Vec2.init(screenWidth / 2, screenHeight / 2),
            .rotation = 0,
            .zoom = 1,
        };

        if (rl.isKeyDown(.space)) {
            player1.player = !player1.player;
            player2.player = !player2.player;
        }

        try actControl.broadcast_msg(.Move, 1);

        // Draw
        rl.beginDrawing();

        defer rl.endDrawing();

        rl.clearBackground(.gray);
        {
            rl.beginMode2D(camera);
            defer rl.endMode2D();

            try actControl.broadcast_msg(.Render, 1);
            rl.drawText("Welcome to Cubelumbo", screenWidth / 2, screenHeight / 2, 30, .black);
        }

        try actControl.broadcast_msg(.ConsoleDraw, 1);
    }
}
