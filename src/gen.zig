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

    return switch (dist) {
        .clustered => genClustered(seed, num),
        .uniform => genUniform(seed, num),
    };
}

fn genClustered(seed: u64, num: u64) !void {
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
    };

    const centers = [_]Point{
        .{ .x = rng.float(f64) * 360 - 180, .y = rng.float(f64) * 180 - 90 },
        .{ .x = rng.float(f64) * 360 - 180, .y = rng.float(f64) * 180 - 90 },
        .{ .x = rng.float(f64) * 360 - 180, .y = rng.float(f64) * 180 - 90 },
        .{ .x = rng.float(f64) * 360 - 180, .y = rng.float(f64) * 180 - 90 },
    };

    for (0..num) |i| {
        const x1 = centers[i % centers.len].x + rng.float(f64) * 60 - 30;
        const y1 = centers[i % centers.len].y + rng.float(f64) * 30 - 15;
        const x2 = centers[(i + 1) % centers.len].x + rng.float(f64) * 60 - 30;
        const y2 = centers[(i + 1) % centers.len].y + rng.float(f64) * 30 - 15;

        scratch_mem.reset();
        var json_value = std.json.Value{ .object = std.json.ObjectMap.init(scratch) };
        defer json_value.object.deinit();

        try json_value.object.put("x1", std.json.Value{ .float = x1 });
        try json_value.object.put("y1", std.json.Value{ .float = y1 });
        try json_value.object.put("x2", std.json.Value{ .float = x2 });
        try json_value.object.put("y2", std.json.Value{ .float = y2 });

        const this_dist = referenceFormula(x1, y1, x2, y2, 6372.8);
        running_sum += this_dist;
        running_avg = running_sum / @intToFloat(f64, i + 1);

        try out.arrayElem();
        try out.emitJson(json_value);
    }

    log.debug("average: {d}\n", .{running_avg});

    try out.endArray();
    try out.endObject();
    try io.out.print("\n", .{});
}

fn genUniform(seed: u64, num: u64) !void {
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

    for (0..num) |i| {
        const x1 = (rng.float(f64) * 360) - 180;
        const y1 = (rng.float(f64) * 180) - 90;
        const x2 = (rng.float(f64) * 360) - 180;
        const y2 = (rng.float(f64) * 180) - 90;

        scratch_mem.reset();
        var json_value = std.json.Value{ .object = std.json.ObjectMap.init(scratch) };
        defer json_value.object.deinit();

        try json_value.object.put("x1", std.json.Value{ .float = x1 });
        try json_value.object.put("y1", std.json.Value{ .float = y1 });
        try json_value.object.put("x2", std.json.Value{ .float = x2 });
        try json_value.object.put("y2", std.json.Value{ .float = y2 });

        const this_dist = referenceFormula(x1, y1, x2, y2, 6372.8);
        running_sum += this_dist;
        running_avg = running_sum / @intToFloat(f64, i + 1);

        try out.arrayElem();
        try out.emitJson(json_value);
    }

    log.debug("average: {d}\n", .{running_avg});

    try out.endArray();
    try out.endObject();
    try io.out.print("\n", .{});
}

fn referenceFormula(x1: f64, y1: f64, x2: f64, y2: f64, earth_radius: f64) f64 {
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
