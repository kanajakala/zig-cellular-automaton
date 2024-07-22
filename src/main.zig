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
const size_x: u20 = 800;
const size_y: u20 = 800;
const cell_size: u8 = 1;

//initializing the Game 2D array and the temp array wich is used to iterate the automaton
var Game: [size_y][size_x]u2 = .{.{0} ** size_x} ** size_y;

//Crappy variable to fiw update and draw synchronisation
var sync_fix: bool = false;

var iter_count: u32 = 0;

//function to fill the game with random values between 0 and 2
fn populateGame(game: *[size_y][size_x]u2) void {
    for (1..(size_y - 1)) |y| {
        for (1..(size_x - 1)) |x| {
            game[y][x] = @mod(rand.int(u2), 3);
        }
    }
}
//function to print the game in the console (debug)
fn printGame() void {
    for (Game) |row| {
        for (row) |cell| {
            std.debug.print("{} ", .{cell});
        }
        std.debug.print("\n", .{});
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
            switch (temp[x][y]) {
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
                    std.debug.print("Invalid value in iterate: {}", .{temp[y][x]});
                    return iErr.InvalidValue;
                },
            }
        }
    }
    iter_count += 1;
    sync_fix = false;
    //std.time.sleep(1000 * std.time.ns_per_ms);
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
                    std.debug.print("Invalid value in onDraw: {}", .{cell});
                    return iErr.InvalidValue;
                },
            }
            ctx.rectangle(@intCast(x * cell_size), @intCast(y * cell_size), cell_size, cell_size);
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
            std.debug.print("iter time: {}ms   \r", .{timer.lap() / 1_000_000});
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
