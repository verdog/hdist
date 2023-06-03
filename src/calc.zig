//! test data calculations
const log = std.log.scoped(.calc);

var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
var heap = gpa.allocator();

pub fn main(argv: [][*:0]u8) !void {
    log.debug("{s}", .{argv});
    defer if (!gpa.detectLeaks()) log.debug("no leaks", .{});

    if (argv.len < 2) {
        printUsage(argv);
        return error.InvalidArguments;
    }

    const filename = std.mem.sliceTo(argv[1], '\x00');

    try calc(filename);
}

fn printUsage(argv: [][*:0]u8) void {
    io.err.print("Usage: {s} <filename>\n", .{argv[0]}) catch {};
}

fn calc(filename: []const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var txt = try file.readToEndAlloc(heap, 3 * 1024 * 1024 * 1024);
    defer heap.free(txt);

    var pairs = try parseHacky(txt);
    defer pairs.deinit();

    var running_avg: f64 = 0.0;
    var running_sum: f64 = 0.0;

    for (pairs.items, 0..) |pair, i| {
        running_sum += naiveHaversineDistance(pair.l.x, pair.l.y, pair.r.x, pair.r.y);
        running_avg = running_sum / @intToFloat(f64, i + 1);
    }

    log.info("average of {} pairs: {d}", .{ pairs.items.len, running_avg });
}

const Point = struct {
    x: f64,
    y: f64,
};

const Pair = struct {
    l: Point,
    r: Point,
};

fn parseHacky(txt: []const u8) !std.ArrayList(Pair) {
    const State = enum {
        outer,
        inner,
    };

    var current_state: State = .outer;
    var pairs = std.ArrayList(Pair).init(heap);
    errdefer pairs.deinit();

    var tokens = std.mem.tokenize(u8, txt, " \n,");
    while (tokens.next()) |token| {
        switch (token[0]) {
            '{' => {
                switch (current_state) {
                    .outer => current_state = .inner,
                    .inner => {
                        _ = tokens.next(); // key
                        const x1s = tokens.next().?; // value
                        _ = tokens.next(); // key
                        const y1s = tokens.next().?; // value
                        _ = tokens.next(); // key
                        const x2s = tokens.next().?; // value
                        _ = tokens.next(); // key
                        const y2s = tokens.next().?; // value

                        try pairs.append(.{
                            .l = .{
                                .x = try std.fmt.parseFloat(f64, x1s),
                                .y = try std.fmt.parseFloat(f64, y1s),
                            },
                            .r = .{
                                .x = try std.fmt.parseFloat(f64, x2s),
                                .y = try std.fmt.parseFloat(f64, y2s),
                            },
                        });
                    },
                }
            },
            '"', '[', ']', '}' => {},
            else => unreachable,
        }
    }

    return pairs;
}

pub fn naiveHaversineDistance(x1: f64, y1: f64, x2: f64, y2: f64) f64 {
    const earth_radius = 6372.8;
    const lat1 = std.math.degreesToRadians(f64, y1);
    const lat2 = std.math.degreesToRadians(f64, y2);
    const d_lat = lat2 - lat1;

    const d_lon = std.math.degreesToRadians(f64, x2 - x1);

    const a = @sin(d_lat / 2.0) * @sin(d_lat / 2.0) + @cos(lat1) * @cos(lat2) * @sin(d_lon / 2.0) * @sin(d_lon / 2.0);
    const c = 2.0 * std.math.asin(@sqrt(a));

    return earth_radius * c;
}

const std = @import("std");
const io = @import("io.zig");
