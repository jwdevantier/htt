const std = @import("std");
const tpl = @import("../tpl.zig");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

pub fn compile(l: *Lua) i32 {
    const tpl_fpath = l.checkString(1);
    const out_fpath = l.checkString(2);

    const res = tpl.compile(l.allocator(), tpl_fpath, out_fpath) catch |err| {
        _ = l.pushString(@errorName(err));
        return 1;
    };

    if (res) |cerr| {
        l.createTable(0, 3);

        _ = l.pushString("lineno");
        _ = l.pushInteger(cerr.lineno);
        _ = l.setTable(-3);

        _ = l.pushString("column");
        _ = l.pushInteger(cerr.column);
        _ = l.setTable(-3);

        _ = l.pushString("reason");
        _ = l.pushString(cerr.reason);
        _ = l.setTable(-3);

        _ = l.pushString("type");
        _ = l.pushString(@tagName(cerr.type));
        _ = l.setTable(-3);

        switch (cerr.type) {
            .lex_err => |lerr| {
                _ = l.pushString("lex_reason");
                _ = l.pushString(lerr.reason);
                _ = l.setTable(-3);

                _ = l.pushString("lex_state");
                _ = l.pushString(lerr.state);
                _ = l.setTable(-3);
            },
            .illegal_toplevel_content => |e| {
                _ = l.pushString("content_type");
                _ = l.pushString(e.content_type);
                _ = l.setTable(-3);
            },
            .directive_unknown => |du| {
                _ = l.pushString("directive_tag");
                _ = l.pushString(du.tag);
                _ = l.setTable(-3);
            },
            else => {},
        }

        return 1;
    } else {
        l.pushNil();
        return 1;
    }

    l.pushNil();
    return 1;
}
