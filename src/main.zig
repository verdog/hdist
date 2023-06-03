const log = std.log.scoped(.main);

pub fn main() !u8 {
    defer io.stdout_buffer.flush() catch {};
    try branchArgv(std.os.argv);
    return 0;
}

fn printUsage(argv: [][*:0]u8) void {
    io.err.print("Usage: {s} <subcommand>\n\n", .{argv[0]}) catch {};
    io.err.print("Available subcommands:\n\n", .{}) catch {};

    const subcommand_fmt = "{s: <8} - {s}\n";
    io.err.print(subcommand_fmt, .{ "gen", "generate input json blob" }) catch {};
}

fn branchArgv(argv: [][*:0]u8) !void {
    log.debug("{s}", .{argv});

    if (argv.len < 2) {
        printUsage(argv);
        return error.InvalidArguments;
    }

    if (std.mem.eql(u8, "gen", std.mem.sliceTo(argv[1], '\x00'))) {
        return try gen.main(argv[1..]);
    }

    printUsage(argv);
    return error.InvalidArguments;
}

test {
    std.testing.refAllDeclsRecursive(@This());
}

const std = @import("std");
const io = @import("io.zig");
const gen = @import("gen.zig");
