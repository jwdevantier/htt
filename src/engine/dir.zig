const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("luatils.zig").wrapGcFn;

const TypeDir = struct {
    handle: std.fs.Dir,
    cwd_handle: bool = false,
};

fn dir___gc(_: *Lua, self: *TypeDir) c_int {
    if (!self.*.cwd_handle) {
        self.*.handle.close();
    }
    return 0;
}

fn dir_path(lua: *Lua) i32 {
    const self: *TypeDir = lua.toUserdata(TypeDir, 1) catch {
        lua.pushNil();
        _ = lua.pushString("NotADir");
        return 2;
    };
    const a = lua.allocator();

    const result = self.*.handle.realpathAlloc(a, ".") catch null;
    if (result) |path| {
        _ = lua.pushString(path);
        a.free(path);
    } else {
        lua.pushNil();
    }
    return 1;
}

fn dir_makepath(lua: *Lua) i32 {
    const self: *TypeDir = lua.toUserdata(TypeDir, 1) catch {
        lua.pushNil();
        _ = lua.pushString("NotADir");
        return 2;
    };
    const subpath = lua.checkString(2);

    self.*.handle.makePath(subpath) catch |err| {
        _ = lua.pushString(@errorName(err));
        return 1;
    };
    return 0;
}

fn dir_openDir(lua: *Lua) i32 {
    const self: *TypeDir = lua.toUserdata(TypeDir, 1) catch {
        lua.pushNil();
        _ = lua.pushString("NotADir");
        return 2;
    };
    const subpath = lua.checkString(2);

    // TODO: are the open flags something we should propagate ?
    const dir: std.fs.Dir = self.*.handle.openDir(subpath, .{ .iterate = true }) catch |err| {
        lua.pushNil();
        _ = lua.pushString(@errorName(err));
        return 2;
    };

    const inst = lua.newUserdata(TypeDir, @sizeOf(TypeDir));
    inst.*.handle = dir;
    inst.*.cwd_handle = false;
    dir_metatable(lua, -1);
    return 1;
}

fn dir_iterate_start(l: *Lua) i32 {
    const self: *TypeDir = l.toUserdata(TypeDir, 1) catch {
        l.pushNil();
        _ = l.pushString("NotADir");
        return 2;
    };

    const iter = l.allocator().create(std.fs.Dir.Iterator) catch {
        return 0;
    };

    iter.* = self.*.handle.iterate();

    _ = l.getGlobal("htt") catch unreachable;
    _ = l.getField(-1, "fs");

    l.pushValue(1); // dup typedir ref
    _ = l.getField(-2, "ftype");

    l.pushLightUserdata(iter);

    // push closure with 2 upvalues.
    // 1: the TypeDir reference - this is to prevent it being garbage-collected
    //    (thus closed) before time
    // 2: the ftype "enum", cached to limit lookups
    // 3: the actual iterator object
    l.pushClosure(ziglua.wrap(dir_iterate_next), 3);
    return 1;
}

fn dir_iterate_next(l: *Lua) i32 {
    const it: *std.fs.Dir.Iterator = l.toUserdata(std.fs.Dir.Iterator, Lua.upvalueIndex(3)) catch {
        unreachable;
    };
    const ftype_ndx = Lua.upvalueIndex(2);

    const result: ?std.fs.Dir.Entry = it.*.next() catch null;

    if (result) |entry| {
        // return <name>, <ftype>
        _ = l.pushString(entry.name);
        _ = l.getField(ftype_ndx, switch (entry.kind) {
            .block_device => "BLOCK_DEVICE",
            .character_device => "CHARACTER_DEVICE",
            .directory => "DIRECTORY",
            .named_pipe => "NAMED_PIPE",
            .sym_link => "SYM_LINK",
            .file => "FILE",
            .unix_domain_socket => "UNIX_DOMAIN_SOCKET",
            .whiteout => "WHITEOUT",
            .door => "DOOR",
            .event_port => "EVENT_PORT",
            .unknown => "UNKNOWN",
        });
        return 2;
    } else {
        // We are done
        // TODO: more errors than just null/we're done
        l.allocator().destroy(it);
        return 0;
    }
}

fn dir_walk_start_(l: *Lua) !i32 {
    const self: *TypeDir = l.toUserdata(TypeDir, 1) catch {
        l.pushNil();
        _ = l.pushString("NotADir");
        return 2;
    };

    const a = l.allocator();

    const aalloc = try a.create(std.heap.ArenaAllocator);
    errdefer a.destroy(aalloc);
    aalloc.* = std.heap.ArenaAllocator.init(a);
    errdefer aalloc.deinit();

    const aa = aalloc.allocator();
    const iter = try aa.create(std.fs.Dir.Walker);
    errdefer aa.destroy(iter);

    iter.* = try self.*.handle.walk(aa);

    _ = l.getGlobal("htt") catch unreachable;
    _ = l.getField(-1, "fs");

    l.pushValue(1); // dup typedir ref
    _ = l.getField(-2, "ftype");

    l.pushLightUserdata(aalloc);
    l.pushLightUserdata(iter);

    // push closure with 3 upvalues.
    // 1: the TypeDir reference - this is to prevent it being garbage-collected
    //    (thus closed) before time
    // 2: the htt.fs.ftype enum, cached to limit lookups
    // 3: The allocator used for walking recursively down the directory
    //    (We need this to properly deinit the allocator and free its memory)
    // 4: the actual iterator object
    l.pushClosure(ziglua.wrap(walk_iterate_next), 4);
    return 1;
}

fn dir_walk_start(l: *Lua) i32 {
    const ret = dir_walk_start_(l) catch {
        return 0;
    };
    return ret;
}

fn walk_iterate_next(l: *Lua) i32 {
    const it = l.toUserdata(std.fs.Dir.Walker, Lua.upvalueIndex(4)) catch {
        // we defined the upvalues and their order in `dir_walk_start`
        unreachable;
    };

    const result: ?std.fs.Dir.Walker.Entry = it.*.next() catch null;
    const ftype_ndx = Lua.upvalueIndex(2);

    if (result) |entry| {
        // TODO: push more than name, see std.fs.Dir.Walker.Entry definition
        _ = l.pushString(entry.path);
        _ = l.getField(ftype_ndx, switch (entry.kind) {
            .block_device => "BLOCK_DEVICE",
            .character_device => "CHARACTER_DEVICE",
            .directory => "DIRECTORY",
            .named_pipe => "NAMED_PIPE",
            .sym_link => "SYM_LINK",
            .file => "FILE",
            .unix_domain_socket => "UNIX_DOMAIN_SOCKET",
            .whiteout => "WHITEOUT",
            .door => "DOOR",
            .event_port => "EVENT_PORT",
            .unknown => "UNKNOWN",
        });
        return 2;
    } else {
        const aalloc = l.toUserdata(std.heap.ArenaAllocator, Lua.upvalueIndex(3)) catch {
            // we defined the upvalues and their order in `dir_walk_start`
            unreachable;
        };
        const aa = aalloc.allocator();
        it.deinit();
        aa.destroy(it);
        aalloc.deinit();
        l.allocator().destroy(aalloc);
        return 0;
    }
}

/// return `Dir` handle to the current working directory.
///
/// This, like the actual Zig std.fs API, is the way to get an initial `Dir`
/// handle, from which one may resolve other paths to other directories and `File`s.
pub fn fs_cwd(l: *Lua) i32 {
    const inst = l.newUserdata(TypeDir, @sizeOf(TypeDir));
    dir_metatable(l, -1);

    inst.*.handle = std.fs.cwd();
    inst.*.cwd_handle = true;
    return 1;
}

fn dir_metatable(l: *Lua, ndx_dir_tbl: i32) void {
    const top = l.getTop();
    l.pushValue(ndx_dir_tbl);

    l.newMetatable("Dir") catch {
        l.setMetatable(-2);
        return;
    };

    l.pushFunction(wrapGcFn(TypeDir, "Dir", dir___gc));
    // stack: [<udata>, <mt>, <gc func>]
    // assoc '__gc' with the value at -1 for table at index (here -2)
    l.setField(-2, "__gc");

    l.pushFunction(ziglua.wrap(dir_path));
    // stack: [<udata>, <mt>, <dir_path func>]
    l.setField(-2, "path");

    l.pushFunction(ziglua.wrap(dir_makepath));
    l.setField(-2, "makePath");

    l.pushFunction(ziglua.wrap(dir_openDir));
    l.setField(-2, "openDir");

    l.pushFunction(ziglua.wrap(dir_iterate_start));
    l.setField(-2, "iterate");

    l.pushFunction(ziglua.wrap(dir_walk_start));
    l.setField(-2, "walk");

    l.pushValue(-1); // dup
    // stack: [<udata>, <mt>, <mt>]
    // here, we pop -1 (mt) and associate it to the __index key of -2 (mt, itself).
    l.setField(-2, "__index");

    l.setMetatable(-2);
    l.setTop(top);
}
