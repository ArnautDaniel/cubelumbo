const rl = @import("raylib");
const rm = @import("raymath");

const Rect = rl.Rectangle;
const Vec2 = rl.Vector2;
const Color = rl.Color;
const Camera2D = rl.Camera2D;
const std = @import("std");
const PriorityQueue = std.PriorityQueue;

const NAME_OFFSET = 65;
const NAME_FONT_SIZE = 16;

const ConsoleBox = struct {
    posx: i32 = 0,
    posy: i32 = 0,
    lines: [3][:0]const u8,

    pub fn draw(this: ConsoleBox) void {
        rl.drawRectangle(this.posx, this.posy, 400, 200, .black);
        for (this.lines, 0..) |line, i| {
            const n: i32 = @intCast(i);
            rl.drawText(line, this.posx, this.posy + n * 50, 20, .white);
        }
    }

    pub fn addLine(self: *ConsoleBox, str: [:0]const u8) void {
        self.lines[0] = self.lines[1];
        self.lines[1] = self.lines[2];
        self.lines[2] = str;
    }
};

const Messages = enum {
    Render,
    Move,
};

const Message = struct {
    sender: u64,
    message: Messages,
    priority: u8,
};

const MailBox = struct {
    queue: PriorityQueue(Message, void, comparePriority),
    allocator: std.mem.Allocator,

    fn comparePriority(context: void, a: Message, b: Message) std.math.Order {
        _ = context;
        return std.math.order(a.priority, b.priority);
    }

    pub fn init(allocator: std.mem.Allocator) MailBox {
        return MailBox{
            .queue = PriorityQueue(Message, void, comparePriority).init(allocator, {}),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MailBox) void {
        self.queue.deinit();
    }

    pub fn add(self: *MailBox, message: Message) !void {
        try self.queue.add(message);
    }

    pub fn remove(self: *MailBox) ?Message {
        if (self.queue.count() == 0) return null;
        return self.queue.remove();
    }

    pub fn debugQueueSize(self: MailBox) void {
        std.debug.print("Queue size: {}\n", .{self.queue.count()});
    }
};

const ActorType = enum {
    Player,
    Item,
    Npc,
};

const ActorControl = struct {
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

    pub fn broadcast(self: *ActorControl, message: Message) !void {
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

const Actor = struct {
    id: u64,
    mailbox: MailBox = undefined,
    name: [:0]const u8 = "",
    position: Rect = undefined,
    actor_type: ActorType,
    color: rl.Color = undefined,

    pub fn init(allocator: std.mem.Allocator, id: u64, name: [:0]const u8, actorType: ActorType) Actor {
        return Actor{
            .id = id,
            .mailbox = MailBox.init(allocator),
            .name = name,
            .actor_type = actorType,
        };
    }

    pub fn deinit(self: *Actor) void {
        self.mailbox.deinit();
    }

    pub fn render(self: *Actor) void {
        rl.drawRectangleRec(self.position, self.color);
    }

    pub fn move(self: *Actor) void {
        if (self.actor_type == .Player) {
            var player = self;
            if (rl.isKeyDown(.right)) {
                player.position.x += 2.0;
            }
            if (rl.isKeyDown(.left)) {
                player.position.x -= 2.0;
            }
            if (rl.isKeyDown(.up)) {
                player.position.y -= 2.0;
            }
            if (rl.isKeyDown(.down)) {
                player.position.y += 2.0;
            }
        }
    }

    pub fn receive(self: *Actor) void {
        const msg = self.mailbox.remove();
        if (msg != null) {
            switch (msg.?.message) {
                .Render => self.render(),
                .Move => self.move(),
            }
        }
    }

    pub fn sendMessage(self: *Actor, target: *Actor, message: Messages, priority: u8) !void {
        const msg = Message{
            .sender = self.id,
            .message = message,
            .priority = priority,
        };
        try target.mailbox.add(msg);
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var actControl = ActorControl.init(allocator);
    defer actControl.deinit();

    const player1 = try actControl.createActor("Cubelumbo", .Player);
    player1.*.color = .white;
    player1.*.position = Rect.init(700, 700, 60, 60);

    const player2 = try actControl.createActor("Suspect", .Npc);
    player2.*.color = .black;
    player2.*.position = Rect.init(800, 800, 60, 60);

    const screenWidth = 1080;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Cubelumbo");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const console = ConsoleBox{ .lines = .{ "Welcome to Cubelumbo.", "Written By Goldenpants (oneword)", "With help from Duck" } };

    // Main game loop
    while (!rl.windowShouldClose()) {

        // Update
        //----------------------------------------------------------------------------------
        const camera: rl.Camera2D = .{
            .target = Vec2.init(player1.position.x, player1.position.y),
            .offset = Vec2.init(screenWidth / 2, screenHeight / 2),
            .rotation = 0,
            .zoom = 1,
        };

        const move_msg = Message{ .message = .Move, .priority = 1, .sender = 0 };
        try actControl.broadcast(move_msg);
        actControl.runActors();

        //---------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();

        defer rl.endDrawing();

        rl.clearBackground(.gray);
        {
            rl.beginMode2D(camera);
            defer rl.endMode2D();

            const render_msg = Message{ .message = .Render, .priority = 1, .sender = 0 };
            try actControl.broadcast(render_msg);
            actControl.runActors();
            rl.drawText("Welcome to Cubelumbo", screenWidth / 2, screenHeight / 2, 30, .black);
        }
        console.draw();
        //----------------------------------------------------------------------------------
    }
}
