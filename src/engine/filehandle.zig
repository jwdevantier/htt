const std = @import("std");
const os = std.os;
const windows = std.os.windows;
const is_windows = @import("builtin").os.tag == .windows;

pub const Timeout = ?u64; // milliseconds
pub const Error = error{
    Timeout,
    EndOfStream,
    IoError,
    OutOfMemory,
    TooManyHandles,
};

pub const FileHandle = struct {
    const Self = @This();

    bytes: std.ArrayList(u8),
    read_pos: usize,
    file: *std.fs.File,
    close: bool,

    pub const Options = struct {
        close: bool = true,
    };

    pub fn init(allocator: std.mem.Allocator, file: *std.fs.File, options: Options) Self {
        return .{
            .bytes = std.ArrayList(u8).init(allocator),
            .read_pos = 0,
            .file = file,
            .close = options.close,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bytes.deinit();
        if (self.close) {
            self.file.close();
        }
    }

    // Helper method that ensures buffer contains at least num bytes without consuming them
    pub fn ensureBytes(self: *Self, num: usize, timeout: Timeout) !void {
        const start_time = if (timeout) |_| std.time.milliTimestamp() else 0;

        // Check if we already have enough bytes
        const available = self.bytes.items.len - self.read_pos;
        if (available >= num) return;

        // Need more bytes - ensure we have space
        const space_needed = num - available;

        // Compact if beneficial
        if (self.read_pos >= self.bytes.items.len / 2) {
            const unread = self.bytes.items.len - self.read_pos;
            @memcpy(self.bytes.items[0..unread], self.bytes.items[self.read_pos..]);
            self.bytes.items.len = unread;
            self.read_pos = 0;
        }

        // Grow buffer if needed
        const minimum_needed = self.bytes.items.len + space_needed;
        if (self.bytes.capacity < minimum_needed) {
            var new_capacity = self.bytes.capacity;
            if (new_capacity == 0) new_capacity = 16;

            while (new_capacity < minimum_needed) {
                if (new_capacity < 4096) {
                    new_capacity *= 2;
                } else {
                    new_capacity += 4096;
                }
            }
            try self.bytes.ensureTotalCapacity(new_capacity);
        }

        // Read loop
        while (true) {
            if (timeout) |t| {
                const elapsed: i64 = std.time.milliTimestamp() - start_time;
                if (elapsed >= @as(i64, @intCast(t))) return Error.Timeout;

                const remaining_ms = @max(0, @as(i64, @intCast(t)) - elapsed);

                // Platform-specific wait for data
                if (is_windows) {
                    // Windows implementation
                    windows.WaitForSingleObject(self.file.handle, @intCast(remaining_ms)) catch |err| switch (err) {
                        error.WaitTimeOut => return error.Timeout,
                        else => return Error.IoError,
                    };
                } else {
                    // Unix implementation
                    var fds = [1]std.posix.pollfd{
                        .{
                            .fd = self.file.handle,
                            .events = std.posix.POLL.IN,
                            .revents = 0,
                        },
                    };

                    const poll_result = std.posix.poll(&fds, @intCast(remaining_ms)) catch {
                        return Error.IoError;
                    };

                    if (poll_result == 0) return Error.Timeout;
                    if (fds[0].revents & std.posix.POLL.ERR != 0) return Error.IoError;
                    if (fds[0].revents & std.posix.POLL.HUP != 0) return Error.EndOfStream;
                    if (fds[0].revents & std.posix.POLL.IN == 0) continue;
                }
            }

            const read_result = self.file.read(self.bytes.unusedCapacitySlice()) catch {
                return Error.IoError;
            };

            if (read_result == 0) return Error.EndOfStream;
            self.bytes.items.len += read_result;

            if (self.bytes.items.len - self.read_pos >= num) {
                return;
            }
        }
    }

    // Core read implementation now uses ensureBytes
    pub fn readBytes(self: *Self, num: usize, timeout: Timeout) ![]const u8 {
        try self.ensureBytes(num, timeout);
        const result = self.bytes.items[self.read_pos .. self.read_pos + num];
        self.read_pos += num;
        return result;
    }

    pub fn readLine(self: *Self, keep_nl: bool, timeout: Timeout) ![]const u8 {
        const start_time = if (timeout) |_| std.time.milliTimestamp() else 0;
        const chunk_size = 1024;

        while (true) {
            // Check existing buffer for newline
            const unread = self.bytes.items[self.read_pos..];
            if (std.mem.indexOfScalar(u8, unread, '\n')) |nl_pos| {
                const end_pos = if (keep_nl) nl_pos + 1 else nl_pos;
                const result = unread[0..end_pos];
                self.read_pos += nl_pos + 1; // Always consume newline
                return result;
            }

            // Need more data
            if (timeout) |t| {
                const elapsed: i64 = std.time.milliTimestamp() - start_time;
                if (elapsed >= @as(i64, @intCast(t))) return Error.Timeout;
                const remaining = @as(i64, @intCast(t)) - elapsed;
                self.ensureBytes(chunk_size, @intCast(@max(0, remaining))) catch |err| switch (err) {
                    error.EndOfStream => {
                        if (unread.len > 0) {
                            const result = unread[0..];
                            self.read_pos += unread.len;
                            return result;
                        }
                        return err;
                    },
                    else => return err,
                };
            } else {
                self.ensureBytes(chunk_size, null) catch |err| switch (err) {
                    error.EndOfStream => {
                        if (unread.len > 0) {
                            const result = unread[0..];
                            self.read_pos += unread.len;
                            return result;
                        }
                        return err;
                    },
                    else => return err,
                };
            }
        }
    }

    pub fn readAll(self: *Self, timeout: Timeout) ![]const u8 {
        const chunk_size = 4096;

        while (true) {
            self.ensureBytes(chunk_size, timeout) catch |err| switch (err) {
                error.EndOfStream => {
                    const result = self.bytes.items[self.read_pos..];
                    self.read_pos += result.len;
                    return result;
                },
                else => return err,
            };
        }
    }
};
