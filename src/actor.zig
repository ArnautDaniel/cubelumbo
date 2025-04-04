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

const ItemActor = struct {
    pub fn receive(self: *ItemActor, msg: mb.Message) void {
        _ = self;
        _ = msg;
        std.debug.print("Reached charactor render\n", .{});
    }
};
const NpcActor = struct {
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
        _ = self;
        _ = msg;
        std.debug.print("Reached charactor render\n", .{});
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
