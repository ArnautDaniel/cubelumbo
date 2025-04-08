const std = @import("std");
const PriorityQueue = std.PriorityQueue;

pub const Messages = enum {
    Render,
    Move,
    ConsoleDraw,
    CameraFollow,
};

pub const Message = struct {
    sender: u64,
    message: Messages,
    priority: u8,
};

pub const MailBox = struct {
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
