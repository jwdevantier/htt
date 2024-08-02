pub const TokenType = enum {
    illegal,
    eof,
    fresh_line,
    line_continuation,
    text,
    directive,
    lualine,
    luablock_line,
    luaexpr_open,
    luaexpr,
    luaexpr_close,
    render_open,
    render,
    render_close,
};

pub const LexState = enum {
    toplevel,
    textline_start,
    text,
    lua_expr_open,
    lua_expr,
    lua_expr_close,
    render_open,
    render,
    render_close,
    lua_blk,
    significant_nl,
    line_end,
    eof,
    illegal,
};

pub const TokenData = union(TokenType) {
    illegal: struct { reason: []const u8, state: LexState },
    eof: void,
    fresh_line: struct { indent: []const u8 },
    line_continuation: void,
    text: []const u8,
    directive: struct { tag: []const u8, args: []const u8 },
    lualine: struct { lua: []const u8, indent: []const u8 },
    luablock_line: struct { lua: []const u8, indent: []const u8 },
    luaexpr_open: void,
    luaexpr: []const u8,
    luaexpr_close: void,
    render_open: void,
    render: struct { component: []const u8, luaexpr: []const u8 },
    render_close: void,
};

pub const Token = struct {
    fpath: []const u8,
    lineno: u32,
    col: u32,
    data: TokenData,
};
