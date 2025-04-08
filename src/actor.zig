const std = @import("std");

const rl = @import("raylib");
const rm = @import("raymath");

const Rect = rl.Rectangle;
const Vec2 = rl.Vector2;
const Color = rl.Color;
const Camera2D = rl.Camera2D;

const PriorityQueue = std.PriorityQueue;
const mb = @import("mailbox.zig");

pub const ActorType = union(enum) {
    Player: CharActor,
    Item: ItemActor,
    Npc: NpcActor,
    Console: ConsoleActor,
    Camera: CameraActor,
};

pub const ActorControl = struct {
    actors: std.AutoHashMap(u64, *Actor),
    next_id: u64 = 1,
    allocator: std.mem.Allocator,
    control_id: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) ActorControl {
        return .{
            .actors = std.AutoHashMap(u64, *Actor).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn createCharActor(self: *ActorControl, name: [:0]const u8) !*CharActor {
        const act: *Actor = try self.createActor(name, ActorType{ .Player = CharActor{} });
        return &act.type.Player;
    }

    pub fn createConsole(self: *ActorControl, name: [:0]const u8, lines: [3][:0]const u8) !*ConsoleActor {
        const act: *Actor = try self.createActor(name, ActorType{ .Console = ConsoleActor{ .lines = lines } });
        return &act.type.Console;
    }

    pub fn createActor(self: *ActorControl, name: [:0]const u8, actorType: ActorType) !*Actor {
        const actor_ptr: *Actor = try self.allocator.create(Actor);
        actor_ptr.* = Actor.init(self.allocator, self.next_id, name, actorType);
        self.next_id += 1;
        try self.actors.put(actor_ptr.id, actor_ptr);
        return actor_ptr;
    }

    pub fn removeActor(self: *ActorControl, id: u64) void {
        if (self.actors.fetchRemove(id)) |entry| {
            self.allocator.destroy(entry.value);
        }
    }

    pub fn registerActor(self: *ActorControl, actor: *Actor) !void {
        actor.id = self.next_id;
        self.next_id += 1;
        try self.actors.put(actor.id, actor);
    }

    pub fn getActor(self: *ActorControl, id: u64) ?*Actor {
        return self.actors.get(id);
    }

    pub fn broadcast_msg(self: *ActorControl, msg_type: mb.Messages, priority: u8) !void {
        const msg = mb.Message{ .message = msg_type, .priority = priority, .sender = 0 };
        try self.broadcast(msg);
        self.runActors();
    }

    pub fn broadcast(self: *ActorControl, message: mb.Message) !void {
        var it = self.actors.iterator();
        const exclude_id = message.sender;
        while (it.next()) |entry| {
            if (entry.key_ptr.* == exclude_id) {
                continue;
            }
            try entry.value_ptr.*.mailbox.add(message);
        }
    }

    pub fn runActors(self: *ActorControl) void {
        var it = self.actors.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.receive();
        }
    }

    pub fn deinit(self: *ActorControl) void {
        var it = self.actors.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.actors.deinit();
    }
};

pub const ConsoleActor = struct {
    posx: i32 = 0,
    posy: i32 = 0,
    lines: [3][:0]const u8,

    pub fn draw(self: *ConsoleActor) void {
        rl.drawRectangle(self.posx, self.posy, 400, 200, .black);
        for (self.lines, 0..) |line, i| {
            const n: i32 = @intCast(i);
            rl.drawText(line, self.posx, self.posy + n * 50, 20, .white);
        }
    }

    pub fn addLine(self: *ConsoleActor, str: [:0]const u8) void {
        self.lines[0] = self.lines[1];
        self.lines[1] = self.lines[2];
        self.lines[2] = str;
    }

    pub fn receive(self: *ConsoleActor, msg: mb.Message) void {
        switch (msg.message) {
            .ConsoleDraw => self.draw(),
            else => {},
        }
    }
};

pub const CameraActor = struct {
    pub fn receive(self: *CameraActor, msg: mb.Message) void {
        _ = self;
        _ = msg;
        std.debug.print("Reached camera\n", .{});
    }
};

pub const ItemActor = struct {
    pub fn receive(self: *ItemActor, msg: mb.Message) void {
        _ = self;
        _ = msg;
        std.debug.print("Reached charactor render\n", .{});
    }
};
pub const NpcActor = struct {
    pub fn receive(self: *NpcActor, msg: mb.Message) void {
        _ = self;
        _ = msg;
        std.debug.print("Reached charactor render\n", .{});
    }
};

pub const CharActor = struct {
    player: bool = false,
    position: Rect = undefined,
    color: rl.Color = undefined,

    pub fn move(self: *CharActor) void {
        if (self.player) {
            if (rl.isKeyDown(.right)) {
                self.position.x += 2.0;
            }
            if (rl.isKeyDown(.left)) {
                self.position.x -= 2.0;
            }
            if (rl.isKeyDown(.up)) {
                self.position.y -= 2.0;
            }
            if (rl.isKeyDown(.down)) {
                self.position.y += 2.0;
            }
        }
    }

    pub fn render(self: *CharActor) void {
        rl.drawRectangleRec(self.position, self.color);
    }

    pub fn receive(self: *CharActor, msg: mb.Message) void {
        switch (msg.message) {
            .Render => self.render(),
            .Move => self.move(),
            else => {},
        }
    }
};

const Actor = struct {
    id: u64,
    mailbox: mb.MailBox = undefined,
    name: [:0]const u8 = "",
    type: ActorType,

    pub fn init(allocator: std.mem.Allocator, id: u64, name: [:0]const u8, actorType: ActorType) Actor {
        return Actor{
            .id = id,
            .mailbox = mb.MailBox.init(allocator),
            .name = name,
            .type = actorType,
        };
    }

    pub fn deinit(self: *Actor) void {
        self.mailbox.deinit();
    }

    pub fn receive(self: *Actor) void {
        const msg = self.mailbox.remove();
        if (msg != null) {
            switch (self.type) {
                .Player => |*player| player.receive(msg.?),
                .Npc => |*npc| npc.receive(msg.?),
                .Item => |*item| item.receive(msg.?),
                .Console => |*console| console.receive(msg.?),
                .Camera => |*camera| camera.receive(msg.?),
            }
        }
    }

    pub fn sendMessage(self: *Actor, target: *Actor, message: mb.Messages, priority: u8) !void {
        const msg = mb.Message{
            .sender = self.id,
            .message = message,
            .priority = priority,
        };
        try target.mailbox.add(msg);
    }
};
