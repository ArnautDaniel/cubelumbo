const rl = @import("raylib");

pub const ConsoleBox = struct {
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
