const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const FileHandle = @import("filehandle.zig").FileHandle;
const RcRef = @import("rcref.zig").RcRef;
const wrapGcFn = @import("luatils.zig").wrapGcFn;

pub const File = struct {
    handle: *FileHandle,
    parent: ?*RcRef,
};

pub const F_ID = "File";

const ERR_TIMEOUT = "TIMEOUT";
const ERR_EOF = "EOF";

const TimeoutError = error{
    NegativeTimeout,
};

fn getTimeout(l: *Lua, index: i32) !?u64 {
    const value = try l.toInteger(index);
    if (value < 0) return error.NegativeTimeout;
    return @intCast(value);
}

fn fMetaTable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(F_ID) catch {
        l.setMetatable(-2);
        return;
    };

    l.pushFunction(wrapGcFn(File, F_ID, f_Gc));
    l.setField(-2, "__gc");

    l.pushFunction(ziglua.wrap(fRead));
    l.setField(-2, "read");

    l.pushFunction(ziglua.wrap(fWrite));
    l.setField(-2, "write");

    l.pushValue(-1); // => [<o> <mt> <mt>]
    l.setField(-2, "__index"); // => [<o> <mt>]
    l.setMetatable(-2); // => [<o>];

    l.setTop(top);
}

fn f_Gc(l: *Lua, self: *File) c_int {
    std.debug.print("f_Gc start\n", .{});
    _ = l;
    self.handle.deinit();
    if (self.parent) |rc| {
        rc.unref();
    }
    std.debug.print("f_Gc end\n", .{});
    return 0;
}

fn readAll(l: *Lua, f: *File) i32 {
    const timeout_ms = if (l.getTop() >= 3)
        getTimeout(l, 3) catch {
            l.pushNil();
            _ = l.pushString("timeout cannot be negative");
            return 2;
        }
    else
        null;

    const result = f.handle.readAll(timeout_ms) catch |err| switch (err) {
        error.Timeout => {
            l.pushNil();
            _ = l.pushString(ERR_TIMEOUT);
            return 2;
        },
        else => {
            l.pushNil();
            _ = l.pushString(@errorName(err));
            return 2;
        },
    };

    _ = l.pushString(result);
    l.pushNil();
    return 2;
}

fn readBytes(l: *Lua, f: *File, num: i64) i32 {
    if (num <= 0) {
        l.pushNil();
        _ = l.pushString("invalid number of bytes");
        return 2;
    }

    const timeout_ms = if (l.getTop() >= 3)
        getTimeout(l, 3) catch {
            l.pushNil();
            _ = l.pushString("timeout cannot be negative");
            return 2;
        }
    else
        null;

    const result = f.handle.readBytes(@intCast(num), timeout_ms) catch |err| switch (err) {
        error.Timeout => {
            l.pushNil();
            _ = l.pushString(ERR_TIMEOUT);
            return 2;
        },
        error.EndOfStream => {
            l.pushNil();
            _ = l.pushString(ERR_EOF);
            return 2;
        },
        else => {
            l.pushNil();
            _ = l.pushString(@errorName(err));
            return 2;
        },
    };

    _ = l.pushString(result);
    l.pushNil();
    return 2;
}

fn readLine(l: *Lua, f: *File, keep_nl: bool) i32 {
    const timeout_ms = if (l.getTop() >= 3)
        getTimeout(l, 3) catch {
            l.pushNil();
            _ = l.pushString("timeout cannot be negative");
            return 2;
        }
    else
        null;

    const result = f.handle.readLine(keep_nl, timeout_ms) catch |err| switch (err) {
        error.Timeout => {
            l.pushNil();
            _ = l.pushString(ERR_TIMEOUT);
            return 2;
        },
        error.EndOfStream => {
            l.pushNil();
            _ = l.pushString(ERR_EOF);
            return 2;
        },
        else => {
            l.pushNil();
            _ = l.pushString(@errorName(err));
            return 2;
        },
    };

    _ = l.pushString(result);
    l.pushNil();
    return 2;
}

fn fRead(l: *Lua) i32 {
    //std.debug.print("read call\n", .{});
    const self = l.checkUserdata(File, 1, F_ID);

    if (l.getTop() == 1) {
        // no args, read all of file
        return readAll(l, self);
    }

    switch (l.typeOf(2)) {
        .number => {
            const num = l.toInteger(2) catch {
                l.pushNil();
                _ = l.pushString("invalid number, only positive integers accepted");
                return 2;
            };
            if (num <= 0) {
                l.pushNil();
                _ = l.pushString("invalid number, only positive integers accepted");
                return 2;
            }

            return readBytes(l, self, num);
        },
        .string => {
            const fmt = l.toString(2) catch unreachable;
            if (fmt.len == 0) {
                l.pushNil();
                _ = l.pushString("format string cannot be empty");
                return 2;
            }

            if (fmt.len != 2 or fmt[0] != '*') {
                l.pushNil();
                _ = l.pushString("invalid format, '*a', '*l' or '*L' supported");
                return 2;
            }

            return switch (fmt[1]) {
                'a' => readAll(l, self),
                'l', 'L' => readLine(l, self, fmt[1] == 'L'),
                else => {
                    l.pushNil();
                    _ = l.pushString("invalid format");
                    return 2;
                },
            };
        },
        else => {
            l.pushNil();
            _ = l.pushString("format must be a positive integer or string");
            return 2;
        },
    }
}

fn doWrite(fh: *FileHandle, data: []const u8) !void {
    var written: usize = 0;
    while (written < data.len) {
        const n = try fh.file.write(data[written..]);
        if (n == 0) {
            // TODO: better error?
            return error.IoError;
        }
        written += n;
    }
}

fn fWrite(l: *Lua) i32 {
    const self = l.checkUserdata(File, 1, F_ID);

    // Skip first arg since that's the File userdata itself
    var ndx: i32 = 2;
    const nargs = l.getTop();

    while (ndx <= nargs) : (ndx += 1) {
        const str = l.toString(ndx) catch {
            l.pushNil();
            _ = l.pushFString("argument #%d must be a string", .{ndx - 1});
            return 2;
        };

        doWrite(self.handle, str) catch |err| {
            l.pushNil();
            _ = l.pushFString("argument #%d: %s", .{ ndx - 1, @errorName(err).ptr });
            return 2;
        };
    }

    // Success - return true
    l.pushBoolean(true);
    return 1;
}

pub fn fInit(l: *Lua, parent: ?*RcRef, handle: *FileHandle) *File {
    std.debug.print("fInit start\n", .{});
    const inst = l.newUserdata(File, @sizeOf(File));

    inst.*.handle = handle;
    inst.*.parent = parent;

    fMetaTable(l, -1);
    std.debug.print("fInit end\n", .{});
    return inst;
}
