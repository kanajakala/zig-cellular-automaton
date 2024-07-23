const std = @import("std");
const capy = @import("capy");

// This is required for your app to build to WebAssembly and other particular architectures
pub usingnamespace capy.cross_platform;

//random
var prng = std.rand.DefaultPrng.init(43);
const rand = prng.random();
const stdout = std.io.getStdOut().writer();

//consts
const size_x: u20 = 600;
const size_y: u20 = 600;
const size: u8 = 2;

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
fn count_n(comptime n_of_neighbors: u8, n: [n_of_neighbors]u2, number: u2) u8 {
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
                0 => if (count_n(8, n, 1) >= 3) {
                    Game[y][x] = 1;
                },
                1 => if (count_n(8, n, 2) >= 3) {
                    Game[y][x] = 2;
                },
                2 => if (count_n(8, n, 0) >= 3) {
                    Game[y][x] = 0;
                },
                else => {
                    return iErr.InvalidValue;
                },
            }
        }
    }
    sync_fix = false;
}

fn onDraw(c: *capy.Canvas, ctx: *capy.DrawContext) !void {
    _ = c;

    for (1..(size_y - 1)) |y| {
        for (1..(size_x - 1)) |x| {
            if (Game[y][x] == 0) {
                const n_n: [4]u2 = .{ Game[y - 1][x], Game[y + 1][x], Game[y][x - 1], Game[y][x + 1] };
                if (count_n(4, n_n, 0) != 4 and n_n[1] == 0 and n_n[3] == 0) {
                    ctx.setColor(0.9, 0.9, 0.9);
                } else if (count_n(4, n_n, 0) != 4 and n_n[2] == 0 and n_n[0] == 0) {
                    ctx.setColor(0.08, 0.08, 0.08);
                } else {
                    const yf: f32 = @floatFromInt(y);
                    ctx.setColor(0 + (yf / size_y), 0.459, 0.643);
                }
                ctx.rectangle(@intCast(x * size), @intCast(y * size), size, size);
                ctx.fill();
            }
        }
    }
    //sync_fix makes sure iter and onDraw are coordinated
    sync_fix = true;
}

fn draw(c: *capy.Canvas) !void {
    //timer if one wants the execution time
    const timer = try std.time.Timer.start();
    _ = timer;
    while (true) {
        try c.requestDraw();
        if (sync_fix) {
            try iter();
            //std.debug.print("time: {}ms   \r", .{timer.lap() / 1_000_000});
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
        .preferredSize = capy.Size.init(size_x * size, size_y * size),
        .ondraw = @as(*const fn (*anyopaque, *capy.DrawContext) anyerror!void, @ptrCast(&onDraw)),
    });

    window.setTitle("Cellular Automaton: RPS");
    window.setPreferredSize(size_x * size, size_y * size);

    try window.set(canvas);
    window.show();

    //update and draw the canvas in a different threads, this allows capy to actually launch the window
    var iterThread = try std.Thread.spawn(.{}, draw, .{canvas});
    defer iterThread.join();

    capy.runEventLoop();
}
