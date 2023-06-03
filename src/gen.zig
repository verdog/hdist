//! test data generation
const log = std.log.scoped(.gen);

var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 16 }){};
var heap = gpa.allocator();

pub fn main(argv: [][*:0]u8) !void {
    log.debug("{s}", .{argv});
    defer if (!gpa.detectLeaks()) log.debug("no leaks", .{});

    if (argv.len < 4) {
        printUsage(argv);
        return error.InvalidArguments;
    }

    const dist: Distribution = blk: {
        if (std.mem.eql(u8, "uniform", std.mem.sliceTo(argv[1], '\x00'))) break :blk .uniform;
        if (std.mem.eql(u8, "clustered", std.mem.sliceTo(argv[1], '\x00'))) break :blk .clustered;
        printUsage(argv);
        return error.InvalidArguments;
    };

    const seed = try std.fmt.parseUnsigned(u64, std.mem.sliceTo(argv[2], '\x00'), 10);
    const num = try std.fmt.parseUnsigned(u64, std.mem.sliceTo(argv[3], '\x00'), 10);

    try gen(dist, seed, num);
}

fn printUsage(argv: [][*:0]u8) void {
    io.err.print("Usage: {s} <\"uniform\" or \"clustered\"> <seed: u64> <number of pairs: u64>\n", .{argv[0]}) catch {};
}

const Distribution = enum {
    uniform,
    clustered,
};

fn gen(dist: Distribution, seed: u64, num: u64) !void {
    log.debug("{} {} {}", .{ dist, seed, num });

    var rng_engine = std.rand.DefaultPrng.init(seed);
    const rng = rng_engine.random();

    var out = std.json.writeStream(io.out, 4);

    try out.beginObject();
    try out.objectField("pairs");
    try out.beginArray();

    var scratch_buf: [1024]u8 = undefined;
    var scratch_mem = std.heap.FixedBufferAllocator.init(&scratch_buf);
    var scratch = scratch_mem.allocator();

    var running_avg: f64 = 0.0;
    var running_sum: f64 = 0.0;

    const Point = struct {
        x: f64,
        y: f64,

        pub fn perturbed(self: @This(), rnd: std.rand.Random) @This() {
            return .{
                .x = self.x + rnd.float(f64) * 30 - 15,
                .y = self.y + rnd.float(f64) * 15 - 7.5,
            };
        }

        pub fn random(rnd: std.rand.Random) @This() {
            return .{
                .x = rnd.float(f64) * 360 - 180,
                .y = rnd.float(f64) * 180 - 90,
            };
        }
    };

    // used for clustered generation
    const centers = [_]Point{
        Point.random(rng),
        Point.random(rng),
    };

    for (0..num) |i| {
        const p1 = if (dist == .uniform) Point.random(rng) else centers[i % centers.len].perturbed(rng);
        const p2 = if (dist == .uniform) Point.random(rng) else centers[(i + 1) % centers.len].perturbed(rng);

        scratch_mem.reset();
        var json_value = std.json.Value{ .object = std.json.ObjectMap.init(scratch) };
        defer json_value.object.deinit();

        try json_value.object.put("x1", std.json.Value{ .float = p1.x });
        try json_value.object.put("y1", std.json.Value{ .float = p1.y });
        try json_value.object.put("x2", std.json.Value{ .float = p2.x });
        try json_value.object.put("y2", std.json.Value{ .float = p2.y });

        const this_dist = calc.naiveHaversineDistance(p1.x, p1.y, p2.x, p2.y);
        running_sum += this_dist;
        running_avg = running_sum / @intToFloat(f64, i + 1);

        try out.arrayElem();
        try out.emitJson(json_value);
    }

    log.info("average of {} pairs: {d}", .{ num, running_avg });

    try out.endArray();
    try out.endObject();
    try io.out.print("\n", .{});
}

const std = @import("std");
const io = @import("io.zig");
const calc = @import("calc.zig");
