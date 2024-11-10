const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("luatils.zig").wrapGcFn;
const f = @import("file.zig");
const RcRef = @import("rcref.zig").RcRef;
const FileHandle = @import("filehandle.zig").FileHandle;

const ProcResult = struct {
    term: std.process.Child.Term,
};

const PR_ID = "ProcResult";

fn pr_metatable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(PR_ID) catch {
        // stack: [<obj> <obj>], return the obj we got when passed in.
        // TODO: but should we not still assign the metatable ?
        l.setMetatable(-2); //
        return;
    };

    l.pushFunction(ziglua.wrap(prExited));
    l.setField(-2, "exited");

    l.pushFunction(ziglua.wrap(prSignal));
    l.setField(-2, "signal");

    l.pushFunction(ziglua.wrap(prStopped));
    l.setField(-2, "stopped");

    l.pushFunction(ziglua.wrap(prUnknown));
    l.setField(-2, "unknown");

    l.pushFunction(ziglua.wrap(prCode));
    l.setField(-2, "code");

    l.pushValue(-1); // dup <mt>
    // pop <mt> and assoc it to __index of -2 (<mt>)
    l.setField(-2, "__index");

    // assign <mt> as metatable of <obj_tbl>
    l.setMetatable(-2);

    l.setTop(top);
}

const TermTag = std.meta.Tag(std.process.Child.Term);

fn prTermCheck(comptime tag: TermTag) fn (*Lua) i32 {
    return struct {
        fn check(l: *Lua) i32 {
            const self: *ProcResult = l.checkUserdata(ProcResult, 1, "ProcResult");
            l.pushBoolean(@as(TermTag, self.term) == tag);
            return 1;
        }
    }.check;
}

const prExited = prTermCheck(.Exited);
const prSignal = prTermCheck(.Signal);
const prStopped = prTermCheck(.Stopped);
const prUnknown = prTermCheck(.Unknown);

fn prCode(l: *Lua) i32 {
    const self: *ProcResult = l.checkUserdata(ProcResult, 1, "ProcResult");
    l.pushInteger(switch (self.term) {
        .Exited => |code| @as(u32, code),
        inline else => |val| val,
    });
    return 1;
}

fn prInit(l: *Lua, t: std.process.Child.Term) i32 {
    const inst = l.newUserdata(ProcResult, @sizeOf(ProcResult));
    inst.*.term = t;
    pr_metatable(l, -1);
    return 1;
}

const ProcHandle = struct {
    child: std.process.Child,
    spawned: bool,
    rc: ?RcRef,
    stdin: ?FileHandle,
    stdout: ?FileHandle,
    stderr: ?FileHandle,
    arena: std.heap.ArenaAllocator,

    fn ref(self: *@This(), l: *Lua) !void {
        if (self.rc) |*rc| {
            try rc.ref();
        } else {
            self.rc = try RcRef.init(l, self);
        }
    }

    fn unref(self: *@This()) void {
        if (self.rc) |*rc| {
            rc.unref();
            if (rc.refcount == 0) {
                self.rc = null;
            }
        }
    }
};

const PH_ID = "ProcHandle";

// define operations available on process handle
fn ph_metatable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(PH_ID) catch {
        // stack: [<obj> <obj>], return the obj we got when passed in.
        // TODO: but should we not still assign the metatable ?
        l.setMetatable(-2); //
        return;
    };

    l.pushFunction(wrapGcFn(ProcHandle, PH_ID, ph___gc));
    l.setField(-2, "__gc");

    l.pushFunction(ziglua.wrap(phSpawn));
    l.setField(-2, "spawn");

    l.pushFunction(ziglua.wrap(phStdinBehavior));
    l.setField(-2, "stdinBehavior");

    l.pushFunction(ziglua.wrap(phStdoutBehavior));
    l.setField(-2, "stdoutBehavior");

    l.pushFunction(ziglua.wrap(phStderrBehavior));
    l.setField(-2, "stderrBehavior");

    l.pushFunction(ziglua.wrap(phStdin));
    l.setField(-2, "stdin");

    l.pushFunction(ziglua.wrap(phStdout));
    l.setField(-2, "stdout");

    l.pushFunction(ziglua.wrap(phStderr));
    l.setField(-2, "stderr");

    l.pushFunction(ziglua.wrap(phWait));
    l.setField(-2, "wait");

    l.pushFunction(ziglua.wrap(phKill));
    l.setField(-2, "kill");

    l.pushFunction(ziglua.wrap(phTerm));
    l.setField(-2, "term");

    l.pushValue(-1); // dup <mt>
    // pop <mt> and assoc it to __index of -2 (<mt>)
    l.setField(-2, "__index");

    // assign <mt> as metatable of <obj_tbl>
    l.setMetatable(-2);

    l.setTop(top);
}

fn ph___gc(l: *Lua, self: *ProcHandle) c_int {
    _ = l;
    std.log.debug("ProcHandle.__gc\n", .{});

    if (self.stdin) |*stdin| stdin.deinit();
    if (self.stdout) |*stdout| stdout.deinit();
    if (self.stderr) |*stderr| stderr.deinit();

    self.*.arena.deinit();
    return 0;
}

fn get_self(l: *Lua, ndx: i32) !*ProcHandle {
    return l.toUserdata(ProcHandle, ndx);
}

fn err(l: *Lua, msg: []const u8) i32 {
    l.pushNil();
    _ = l.pushString(msg);
    return 2;
}

fn phTerm(l: *Lua) i32 {
    const self = l.checkUserdata(ProcHandle, 1, PH_ID);
    const t = if (self.child.term) |term| term catch null else null;

    return if (t) |term| prInit(l, term) else 0;
}

fn phKill_(l: *Lua) !i32 {
    const self = get_self(l, 1) catch {
        return err(l, "not a process");
    };

    if (!self.*.spawned) {
        return err(l, "process not started yet");
    }

    const t = self.*.child.kill() catch {
        return err(l, "failed to kill process");
    };

    const rs = prInit(l, t);
    return rs;
}

fn phKill(l: *Lua) i32 {
    return phKill_(l) catch {
        return 0;
    };
}

fn phWait_(l: *Lua) !i32 {
    const self = get_self(l, 1) catch {
        return err(l, "not a process");
    };

    if (!self.*.spawned) {
        return err(l, "process not started yet");
    }

    const t = self.*.child.wait() catch {
        return err(l, "failed to wait for process");
    };

    const rs = prInit(l, t);
    return rs;
}

fn phWait(l: *Lua) i32 {
    return phWait_(l) catch {
        return 0;
    };
}

fn phSpawn_(l: *Lua) !i32 {
    std.debug.print("spawn start\n", .{});
    const self = get_self(l, 1) catch {
        return err(l, "not a process");
    };

    if (self.*.spawned) {
        return err(l, "process already spawned");
    }

    self.*.child.spawn() catch {
        return err(l, "failed to spawn process");
    };

    if (self.*.child.stdin) |*stdin| {
        self.stdin = FileHandle.init(self.arena.allocator(), stdin, .{ .close = false });
        std.debug.print("-- Handle stdin: fd={}\n", .{self.stdin.?.file.handle});
    } else {
        self.stdin = null;
    }

    if (self.*.child.stdout) |*stdout| {
        self.stdout = FileHandle.init(self.arena.allocator(), stdout, .{ .close = false });
        std.debug.print("-- Handle stdout: fd={}\n", .{self.stdout.?.file.handle});
    } else {
        self.stdout = null;
    }

    if (self.*.child.stderr) |*stderr| {
        self.stderr = FileHandle.init(self.arena.allocator(), stderr, .{ .close = false });
        std.debug.print("-- Handle stderr: fd={}\n", .{self.stderr.?.file.handle});
    } else {
        self.stderr = null;
    }

    self.*.spawned = true;

    std.debug.print("spawn end\n", .{});
    return 0;
}

fn phSpawn(l: *Lua) i32 {
    return phSpawn_(l) catch {
        return 0;
    };
}

const PipePolicyError = error{
    InvalidPolicy,
};

const StdIoType = enum { stdin, stdout, stderr };

fn phStdIoBehavior(l: *Lua, t: StdIoType) !i32 {
    const self = get_self(l, 1) catch {
        return err(l, "not a process");
    };

    if (self.*.spawned) {
        return err(l, "process already spawned");
    }

    const val = std.meta.intToEnum(std.process.Child.StdIo, l.checkInteger(2)) catch {
        return PipePolicyError.InvalidPolicy;
    };

    switch (t) {
        .stdin => self.*.child.stdin_behavior = val,
        .stdout => self.*.child.stdout_behavior = val,
        .stderr => self.*.child.stderr_behavior = val,
    }
    return 0;
}

fn phStdoutBehavior(l: *Lua) i32 {
    return phStdIoBehavior(l, .stdout) catch {
        _ = l.pushString("invalid policy");
        return 1;
    };
}

fn phStdinBehavior(l: *Lua) i32 {
    return phStdIoBehavior(l, .stdin) catch {
        _ = l.pushString("invalid policy");
        return 1;
    };
}

fn phStderrBehavior(l: *Lua) i32 {
    return phStdIoBehavior(l, .stderr) catch {
        _ = l.pushString("invalid policy");
        return 1;
    };
}

fn phStream_(
    l: *Lua,
    self: *ProcHandle,
    handle: *?FileHandle,
) !i32 {
    if (!self.spawned) {
        l.raiseErrorStr("cannot ask for stream before process is spawned", .{});
        return; // NO-OP
    }
    if (handle.* == null) {
        // TODO: nicer error, tell which stream to open ?
        l.raiseErrorStr("stream not opened", .{});
    }
    try self.ref(l);
    errdefer self.unref();
    // we already asserted that stream is non-null
    // and `self.ref()` ensures self.rc is non-null
    const fh: *FileHandle = &handle.*.?;
    _ = f.fInit(l, &self.rc.?, fh);
    return 1;
}

fn phStdin(l: *Lua) i32 {
    const self = l.checkUserdata(ProcHandle, 1, PH_ID);
    return phStream_(l, self, &self.stdin) catch {
        return 0;
    };
}

fn phStdout(l: *Lua) i32 {
    const self = l.checkUserdata(ProcHandle, 1, PH_ID);
    return phStream_(l, self, &self.stdout) catch {
        return 0;
    };
}

fn phStderr(l: *Lua) i32 {
    const self = l.checkUserdata(ProcHandle, 1, PH_ID);
    return phStream_(l, self, &self.stderr) catch {
        return 0;
    };
}

fn fs_proc_(l: *Lua) !i32 {
    const tbl_ndx = l.getTop();
    errdefer l.setTop(tbl_ndx);

    const tbl_len = l.rawLen(tbl_ndx);

    var arena = std.heap.ArenaAllocator.init(l.allocator());
    errdefer arena.deinit();

    const aa = arena.allocator();
    var argv = try aa.alloc([]const u8, tbl_len);

    for (0..tbl_len) |i| {
        _ = l.rawGetIndex(tbl_ndx, @intCast(i + 1)); // argsTable[i]
        argv[i] = try aa.dupe(u8, l.checkString(-1));
    }
    l.pop(@intCast(tbl_len)); // discard strings

    const inst = l.newUserdata(ProcHandle, @sizeOf(ProcHandle));
    inst.*.spawned = false;
    // NOTE: assign arena here to copy present state (after allocating strings)
    //       and THEN provide child with an allocator ptr from this newly assigned arena var
    inst.*.arena = arena;
    inst.*.child = std.process.Child.init(argv, inst.*.arena.allocator());

    ph_metatable(l, -1);
    return 1;
}

pub fn fs_proc(l: *Lua) i32 {
    if (!l.isTable(1)) {
        l.pushNil();
        _ = l.pushString("expected a table of strings");
        return 2;
    }
    if (l.rawLen(1) == 0) {
        l.pushNil();
        _ = l.pushString("must provide at least 1 argument in argv");
        return 2;
    }
    return fs_proc_(l) catch {
        l.pushNil();
        _ = l.pushString("unhandled error");
        return 2;
    };
}
