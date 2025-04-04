const rl = @import("raylib");
const rm = @import("raymath");
const act = @import("actor.zig");
const mb = @import("mailbox.zig");
const cns = @import("console.zig");

const Rect = rl.Rectangle;
const Vec2 = rl.Vector2;
const Color = rl.Color;
const Camera2D = rl.Camera2D;
const std = @import("std");
const PriorityQueue = std.PriorityQueue;

const NAME_OFFSET = 65;
const NAME_FONT_SIZE = 16;

var console = cns.ConsoleBox{ .lines = .{ "Welcome to Cubelumbo.", "Written By Goldenpants (oneword)", "With help from Duck" } };

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var actControl = act.ActorControl.init(allocator);
    defer actControl.deinit();

    const player1 = try actControl.createActor("Cubelumbo", act.ActorType{ .Player = act.CharActor{} });
    player1.*.type.Player.color = .white;
    player1.*.type.Player.position = Rect.init(700, 700, 60, 60);

    const player2 = try actControl.createActor("Suspect", act.ActorType{ .Player = act.CharActor{} });
    player2.*.type.Player.color = .black;
    player2.*.type.Player.position = Rect.init(800, 800, 60, 60);

    const screenWidth = 1080;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Cubelumbo");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Main game loop
    while (!rl.windowShouldClose()) {

        // Update
        const camera: rl.Camera2D = .{
            .target = Vec2.init(player1.type.Player.position.x, player1.type.Player.position.y),
            .offset = Vec2.init(screenWidth / 2, screenHeight / 2),
            .rotation = 0,
            .zoom = 1,
        };

        const move_msg = mb.Message{ .message = .Move, .priority = 1, .sender = 0 };
        try actControl.broadcast(move_msg);
        actControl.runActors();

        // Draw
        rl.beginDrawing();

        defer rl.endDrawing();

        rl.clearBackground(.gray);
        {
            rl.beginMode2D(camera);
            defer rl.endMode2D();

            const render_msg = mb.Message{ .message = .Render, .priority = 1, .sender = 0 };
            try actControl.broadcast(render_msg);
            actControl.runActors();
            rl.drawText("Welcome to Cubelumbo", screenWidth / 2, screenHeight / 2, 30, .black);
        }
        console.draw();
    }
}
