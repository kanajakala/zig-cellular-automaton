const std = @import("std");
const capy = @import("capy");

// This is required for your app to build to WebAssembly and other particular architectures
pub usingnamespace capy.cross_platform;

//random
var prng = std.rand.DefaultPrng.init(42);
const rand = prng.random();
const stdout = std.io.getStdOut().writer();

//timer

//consts
const size_x: u20 = 200;
const size_y: u20 = 200;
const cell_size: u8 = 4;
//used when drawing with ellipses
//const cell_size_float: f32 = cell_size;

//initializing the Game 2D array and the temp array wich is used to iterate the automaton
var Game: [size_y][size_x]u2 = undefined;

//Crappy variable to fiw update and draw synchronisation
var sync_fix: bool = false;

//function to fill the game with random values between 0 and 2
fn populateGame(game: *[size_y][size_x]u2) void {
    for (1..(size_y - 1)) |y| {
        for (1..(size_x - 1)) |x| {
            game[y][x] = @mod(rand.int(u2), 3);
        }
    }
}

//this function is used to return the ammount of values n in a neighborhood
fn count_n(n: *const [8]u2, number: u2) u8 {
    var out: u8 = 0;
    for (n) |i| {
        if (i == number) {
            out += 1;
        }
    }
    return out;
}

const iErr = error{InvalidValue};

//this function takes the game and advances it to next state
fn iter() !void {
    const temp = Game;
    for (1..(size_y - 1)) |y| {
        for (1..(size_x - 1)) |x| {

            //n contains the values of all the neighbors of the current cell
            const n: [8]u2 = .{ temp[y - 1][x - 1], temp[y - 1][x], temp[y - 1][x + 1], temp[y][x - 1], temp[y][x + 1], temp[y + 1][x - 1], temp[y + 1][x], temp[y + 1][x + 1] };

            //Updating the automaton
            switch (temp[y][x]) {
                0 => if (count_n(&n, 1) >= 3) {
                    Game[y][x] = 1;
                },
                1 => if (count_n(&n, 2) >= 3) {
                    Game[y][x] = 2;
                },
                2 => if (count_n(&n, 0) >= 3) {
                    Game[y][x] = 0;
                },
                else => {
                    return iErr.InvalidValue;
                },
            }
        }
    }
    sync_fix = false;
    //std.time.sleep(1000 * std.time.ns_per_ms);
}

fn triangle(ctx: *capy.DrawContext, x: i32, y: i32) void {
    ctx.line(x, y, x + cell_size, y);
    ctx.line(x + cell_size, y, x + cell_size, y + cell_size);
    ctx.line(x + cell_size, y + cell_size, x, y);
    ctx.fill();
}

fn onDraw(c: *capy.Canvas, ctx: *capy.DrawContext) !void {
    _ = c;

    for (Game, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            switch (cell) {
                0 => ctx.setColor(0, 0.459, 0.643),
                1 => ctx.setColor(0.294, 0.267, 0.325),
                2 => ctx.setColor(1, 0.502, 0.4),
                else => {
                    return iErr.InvalidValue;
                },
            }
            //triangle(ctx, @intCast(x * cell_size), @intCast(y * cell_size));
            ctx.rectangle(@intCast(x * cell_size), @intCast(y * cell_size), cell_size, cell_size);
            //ctx.ellipse(@intCast(x * cell_size), @intCast(y * cell_size), cell_size_float * 2, cell_size_float * 2);
            ctx.fill();
        }
    }
    sync_fix = true;
    //try onDraw(w, ctx);
}

fn draw(c: *capy.Canvas) !void {
    var timer = try std.time.Timer.start();
    while (true) {
        try c.requestDraw();
        if (sync_fix) {
            try iter();
            std.debug.print("time: {}ms   \r", .{timer.lap() / 1_000_000});
        }
    }
}

pub fn main() !void {
    //create a 2D array filled with random values
    populateGame(&Game);

    //window init
    try capy.init();
    var window = try capy.Window.init();

    //creating the canvas
    const canvas = capy.canvas(.{
        .preferredSize = capy.Size.init(size_x * cell_size, size_y * cell_size),
        .ondraw = @as(*const fn (*anyopaque, *capy.DrawContext) anyerror!void, @ptrCast(&onDraw)),
    });

    window.setTitle("Cellular automaton test");
    window.setPreferredSize(size_x * cell_size, size_y * cell_size);

    try window.set(canvas);
    window.show();

    var iterThread = try std.Thread.spawn(.{}, draw, .{canvas});
    defer iterThread.join();

    capy.runEventLoop();
}
