//! input/output

const stdout_unbuffered = std.io.getStdOut().writer();
pub var stdout_buffer = std.io.bufferedWriter(stdout_unbuffered);
pub const out = stdout_buffer.writer();

const stderr_unbuffered = std.io.getStdErr();
pub const err = stderr_unbuffered.writer();

const std = @import("std");
