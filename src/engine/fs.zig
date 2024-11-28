const std = @import("std");
const ziglua = @import("ziglua");
const Allocator = std.mem.Allocator;
const Lua = ziglua.Lua;

const dir = @import("dir.zig");
const file = @import("file.zig");
const File = file.File;
const F_ID = file.F_ID;
const Error = @import("filehandle.zig").Error;
const FileHandle = @import("filehandle.zig").FileHandle;

const windows = std.os.windows;
const is_windows = @import("builtin").os.tag == .windows;

// constrain implementation to what windows can handle
const MAX_HANDLES = windows.MAXIMUM_WAIT_OBJECTS;

const TimeoutError = error{
    NegativeTimeout,
};

fn getTimeout(l: *Lua, ndx: i32) !i32 {
    const value = try l.toInteger(ndx);
    if (value < 0) return error.NegativeTimeout;
    return @intCast(value);
}

const SelectResult = struct {
    ready: u64, // 1 bit per supported handle
    err: ?Error = null,
};

fn select(handles: []*FileHandle, timeout: ?i32) SelectResult {
    //std.debug.print("select(handles.len: {}, timeout: {?})\n", .{ handles.len, timeout });

    if (handles.len == 0) {
        return .{ .ready = 0 };
    }

    //TODO: remove
    // for (handles, 0..) |handle, i| {
    //     std.debug.print(" select, handles[{d}] fd: {d}\n", .{ i, handle.file.handle });
    // }

    if (is_windows) {
        var win_handles: [MAX_HANDLES]windows.HANDLE = undefined;
        for (handles, 0..) |handle, i| {
            win_handles[i] = handle.file.handle;
        }

        const wait_timeout: windows.DWORD = if (timeout) |t|
            @as(windows.DWORD, @intCast(t))
        else
            windows.INFINITE;
        if (wait_timeout < 0) @panic("invariant broken");

        const wait_result = windows.WaitForMultipleObjectsEx(win_handles[0..handles.len], false, // wait for ANY signal
            wait_timeout, false) catch |err| switch (err) {
            error.WaitTimeOut => return .{ .ready = 0, .err = error.Timeout },
            else => return .{ .ready = 0, .err = error.IoError },
        };

        if (wait_result >= windows.WAIT_OBJECT_0 and wait_result < (windows.WAIT_OBJECT_0 + handles.len)) {
            const ndx = wait_result - windows.WAIT_OBJECT_0;
            return .{ .ready = @as(u64, 1) << @intCast(ndx) };
        } else {
            std.debug.print("select, windows, unhandled signal exit\n", .{});
            return .{ .ready = 0, .err = error.IoError };
        }
    } else { //posix land
        var fds: [MAX_HANDLES]std.posix.pollfd = undefined;
        for (handles, 0..) |handle, i| {
            fds[i] = .{
                .fd = handle.file.handle,
                // what we listen for
                .events = std.posix.POLL.IN | std.posix.POLL.ERR | std.posix.POLL.HUP,
                // what we got (if anything)
                .revents = 0, // TODO: what ?
            };
        }

        // std.debug.print("  select, calling poll\n", .{});
        const poll_timeout: i32 = if (timeout) |t| t else -1;
        const poll_res = std.posix.poll(fds[0..handles.len], poll_timeout) catch {
            // TODO: re-add |err| capture
            //std.debug.print("  select, poll err: {s}\n", .{@errorName(err)});
            return .{ .ready = 0, .err = error.IoError };
        };
        //std.debug.print("  select, poll result: {d}\n", .{poll_res});

        if (poll_res == 0) {
            std.debug.print("  select, poll, timeout\n", .{});
            return .{ .ready = 0, .err = error.Timeout };
        }

        var rdy: u64 = 0;
        // std.debug.print("  select, checking poll fd's\n", .{});
        for (fds[0..handles.len], 0..) |fd, i| {
            //std.debug.print("    fd[{d}]: revents={b}\n", .{ i, fd.revents });

            if (fd.revents != 0) {
                if ((fd.revents & std.posix.POLL.ERR) != 0) {
                    std.debug.print("  select, (err, I/O) fd[{d}]: POLL.ERR\n", .{i});
                    return .{ .ready = 0, .err = Error.IoError };
                }
                if ((fd.revents & std.posix.POLL.HUP) != 0) {
                    std.debug.print("  select, (err, EOS) fd[{d}]: POLL.HUP\n", .{i});
                    return .{ .ready = 0, .err = Error.EndOfStream };
                }
                if ((fd.revents & std.posix.POLL.IN) != 0) {
                    std.debug.print("  select, (OK) fd[{d}]: POLL.IN\n", .{i});
                    rdy |= (@as(u64, 1) << @intCast(i));
                }
            }
        }

        //std.debug.print("  select, unix poll, exit, rdy={b}\n", .{rdy});
        return .{ .ready = rdy };
    }
}

pub fn fsSelect(l: *Lua) i32 {
    const num_args = l.getTop();
    const tbl_ndx = 1;
    if (!l.isTable(tbl_ndx)) {
        std.debug.print("expect a table of File\n", .{});
        l.pushNil();
        _ = l.pushString("expect a table of File handles\n");
        return 2;
    }

    var handles: [MAX_HANDLES]*FileHandle = undefined;
    var num_handles: usize = 0;

    l.pushValue(1); // table to top of stack
    l.pushNil(); // space for key
    while (l.next(tbl_ndx)) : (num_handles += 1) {
        // stack: (top) [<value>, <key>, ...]
        if (num_handles > MAX_HANDLES) {
            l.pushNil();
            _ = l.pushString("too many handles");
            return 2;
        }
        const fh = l.checkUserdata(File, -1, file.F_ID);
        handles[num_handles] = fh.handle;
        //std.debug.print("fsSelect, handle iter[{}]: {}\n", .{ num_handles, fh.handle.file.handle });
        l.pop(1);
    }

    //std.debug.print("fsSelect, collected {} handles\n", .{num_handles});

    const timeout_ms = if (num_args > 1)
        getTimeout(l, 2) catch {
            l.pushNil();
            _ = l.pushString("error with timeout value");
            return 2;
        }
    else
        null;

    // TODO: remove
    // if (timeout_ms) |tms| {
    //     std.debug.print("fsSelect, timeout: {}\n", .{tms});
    // } else {
    //     std.debug.print("fsSelect, timeout: no val/err reading\n", .{});
    // }

    //std.debug.print("fsSelect, calling select\n", .{});
    const res: SelectResult = select(handles[0..num_handles], timeout_ms);

    //std.debug.print("fsSelect, rdy={b}, err={?}\n", .{ res.ready, res.err });

    if (res.err) |err| {
        std.debug.print("fsSelect, select err: {s}\n", .{@errorName(err)});
        l.pushNil();
        _ = l.pushString(@errorName(err));
        return 2;
    }

    l.createTable(0, 0);
    const tbl_res_ndx = l.getTop();

    {
        var ndx: i32 = 1; // result tbl ndx

        var rdy = res.ready;
        while (rdy != 0) {
            const pos = @ctz(rdy);
            _ = l.getIndex(tbl_ndx, pos);
            // stack[-1] is FileHandle[i] of input
            // => assign to result tbl[ndx]
            l.rawSetIndex(tbl_res_ndx, ndx);
            ndx += 1;
            // clear bit to proceed
            rdy &= ~(@as(u64, 1) << @intCast(pos));
        }
    }

    if (l.getTop() != tbl_res_ndx) {
        std.debug.print("l.getTop({}), wanted {}\n", .{ l.getTop(), tbl_res_ndx });
        @panic("error in offsets ahead of return");
    }

    l.pushNil(); // no error
    return 2;
}

fn dirname(l: *Lua) i32 {
    const str = l.checkString(1);
    _ = l.pushString(std.fs.path.dirname(str) orelse "");
    return 1;
}

fn basename(l: *Lua) i32 {
    const str = l.checkString(1);
    _ = l.pushString(std.fs.path.basename(str));
    return 1;
}

fn path_join(l: *Lua) i32 {
    const a = l.allocator();
    var start: usize = 0;

    // get number of arguments
    const nargs: usize = @intCast(l.getTop());
    if (nargs == 0) return 0;

    // create array to hold path segments
    var paths = a.alloc([]const u8, nargs) catch {
        l.pushNil();
        _ = l.pushString("out of memory");
        return 2;
    };
    defer a.free(paths);

    // collect path segments
    for (0..nargs) |i| {
        paths[i] = l.checkString(@intCast(i + 1));
        if (std.fs.path.isAbsolute(paths[i])) {
            start = i;
        }
    }

    const joined = std.fs.path.join(a, paths[start..]) catch {
        l.pushNil();
        _ = l.pushString("failed to join paths");
        return 2;
    };

    defer a.free(joined);

    _ = l.pushString(joined);
    return 1;
}

pub fn registerFuncs(lua: *Lua, htt_tbl_ndx: i32) !void {
    const top = lua.getTop();
    _ = lua.getField(htt_tbl_ndx, "fs");

    lua.pushFunction(ziglua.wrap(dir.fs_cwd));
    lua.setField(-2, "cwd");

    lua.pushFunction(ziglua.wrap(fsSelect));
    lua.setField(-2, "select");

    _ = lua.pushString(std.fs.path.sep_str);
    lua.setField(-2, "sep");

    lua.pushFunction(ziglua.wrap(dirname));
    lua.setField(-2, "dirname");

    lua.pushFunction(ziglua.wrap(basename));
    lua.setField(-2, "basename");

    lua.pushFunction(ziglua.wrap(path_join));
    lua.setField(-2, "path_join");

    lua.setTop(top);
}
