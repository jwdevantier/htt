const std = @import("std");
const lexer = @import("lexer.zig");
const Lexer = lexer.Lexer;
const Token = @import("token.zig").Token;

fn ppToken(lbl: []const u8, tok: Token) void {
    std.debug.print("{s} Token {{\n\tfpath: \"{s}\",\n\tlineno: {},\n\tcol: {},\n\t<type>: {s},\n\tdata: ", .{ lbl, tok.fpath, tok.lineno, tok.col, @tagName(tok.data) });
    switch (tok.data) {
        .illegal => {
            std.debug.print("illegal(reason: {s}, state: {s})\n", .{ tok.data.illegal.reason, @tagName(tok.data.illegal.state) });
        },
        .fresh_line => {
            std.debug.print("\"{s}\"\n", .{tok.data.fresh_line.indent});
        },
        .text => {
            std.debug.print("\"{s}\"\n", .{tok.data.text});
        },
        .directive => {
            std.debug.print("{{\n\t\ttag: \"{s}\",\n\t\targs: \"{s}\"\n\t}}\n", .{ tok.data.directive.tag, tok.data.directive.args });
        },
        .lualine => {
            std.debug.print("\"{s}{s}\"\n", .{ tok.data.lualine.indent, tok.data.lualine.lua });
        },
        .luablock_line => {
            std.debug.print("\"{s}{s}\"\n", .{ tok.data.luablock_line.indent, tok.data.luablock_line.lua });
        },
        .luaexpr => {
            std.debug.print("\"{s}\"\n", .{tok.data.luaexpr});
        },
        .render => {
            std.debug.print("\"@{s} {s}\"\n", .{ tok.data.render.component, tok.data.render.luaexpr });
        },
        else => {
            std.debug.print("<>\n", .{});
        },
    }
    std.debug.print("}}\n", .{});
}
fn expectToken_(exp: Token, actual: Token) !void {
    if (!std.mem.eql(u8, exp.fpath, actual.fpath)) {
        std.debug.print("!fpath; expected '{s}', got '{s}'\n", .{ exp.fpath, actual.fpath });
        try std.testing.expect(false);
    }

    if (!std.mem.eql(u8, @tagName(exp.data), @tagName(actual.data))) {
        std.debug.print("Token.data type unexpected.\n\tExpected: '{s}'\n\tGot: '{s}'\n", .{ @tagName(exp.data), @tagName(actual.data) });
        try std.testing.expect(false);
    }

    if (exp.lineno != actual.lineno) {
        std.debug.print("Unexpected lineno, Expected: {}, Got: {}\n", .{ exp.lineno, actual.lineno });
        try std.testing.expect(false);
    }

    if (exp.lineno != actual.lineno) {
        std.debug.print("Unexpected col, Expected: {}, Got: {}\n", .{ exp.col, actual.col });
        try std.testing.expect(false);
    }

    try std.testing.expectEqualDeep(exp.data, actual.data);
}

fn expectToken(exp: Token, actual: Token) !void {
    return expectToken_(exp, actual) catch |err| {
        ppToken("expected", exp);
        ppToken("actual", actual);
        return err;
    };
}

fn expectTokens(exp: []const Token, l: *Lexer) !void {
    var ndx: u32 = 0;

    while (ndx < exp.len) : (ndx += 1) {
        expectToken(exp[ndx], l.nextToken()) catch |err| {
            std.debug.print("expectTokens[{}]: tokens do not match\n", .{ndx});
            return err;
        };
    }
}

fn ppTokens(max: u32, l: *Lexer) !void {
    var ndx: u32 = 0;
    while (!l.eof() and ndx < max) : (ndx += 1) {
        ppToken("token", l.nextToken());
    }
    return error.OutOfMemory;
}

test "eof right away" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath, "");
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "eof - last line is empty" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\line 1
        \\
    );
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "eof - right after text ends" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\line 1
        \\
    );
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "eof - right after lualine ends" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\% lua code
        \\
    );
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = .{ .lua = "lua code", .indent = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text-indent" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\line 1
        \\  line 2
        \\
    );
    //try ppTokens(10, &lex);
    try expectTokens(&[_]Token{
        // Text lines and indentation
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .fresh_line = .{ .indent = "  " } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .text = "line 2" } },
        // technically testing something else, that a tpl with an empty line @ end just emits EOF
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, significant WS initial" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\
        \\line 1
        \\line 2
    );
    //try ppTokens(20, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .text = "line 2" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, significant WS middle" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\line 1
        \\
        \\line 2
    );
    //try ppTokens(20, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .text = "" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .text = "line 2" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, significant WS middle (2 lines)" {
    // guards against a bug I had where the toplevel lexing function counted '\n' (skipping first)
    // to enter a state where next NL was deemed significant. This would have required 2 NLs per
    // significant WS line.
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\line 1
        \\
        \\
        \\line 2
    );
    //try ppTokens(20, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .text = "" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .text = "" } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .text = "line 2" } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

// TODO case with significant LEADING ws
// (prolly start in significant WS mode, whic exits to toplevel)

test "text and lualines, interleaved" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\%if c1 then
        \\line 1
        \\% if c2 then
        \\%  if c3 then
        \\   %if c4 then
        \\line 2
        \\
    );
    // try ppTokens(10, &lex);
    try expectTokens(&[_]Token{
        // Notice how freshline tags (and thus actual, printed lines) are only advanced right before each text/*-expr token
        // TODO: insert renderexpr and luaexpr tags or create more tests
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c1 then" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .text = "line 1" } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c2 then" } } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c3 then" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .lualine = .{ .indent = "   ", .lua = "if c4 then" } } },
        .{ .fpath = fpath, .lineno = 6, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 6, .col = 0, .data = .{ .text = "line 2" } },
        .{ .fpath = fpath, .lineno = 7, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

// TODO: test "text, significant WS, end"

test "lualine indent" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\%if c1 then
        \\% if c2 then
        \\%  if c3 then
        \\   %if c4 then
        \\
    );
    try expectTokens(&[_]Token{
        // Lua line
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c1 then" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c2 then" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "if c3 then" } } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .lualine = .{ .indent = "   ", .lua = "if c4 then" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, luaexpr double-quoted }}" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\hello {{ " }}!" }}
    );
    try expectTokens(&[_]Token{
        // Lua line
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr = "\" }}!\"" } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, luaexpr single-quoted }}" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\hello {{ ' }}!' }}
    );
    try expectTokens(&[_]Token{
        // Lua line
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr = "' }}!'" } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "text, luaexpr esc close w multiline string }}" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\hello {{ [[ }}!]] }}
    );
    try expectTokens(&[_]Token{
        // Lua line
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr = "[[ }}!]]" } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "render, stand-alone" {
    const fpath = "z.tpl";
    var lex = Lexer.init(fpath,
        \\{{@ hello_world {} }}
    );
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render = .{ .component = "hello_world", .luaexpr = "{}" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_close = {} } },
    }, &lex);
}

test "render, back-2-back" {
    const fpath = "z.tpl";
    var lex = Lexer.init(fpath,
        \\{{@ component_a {} }}{{@ component_b {} }}
    );
    //try ppTokens(10, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render = .{ .component = "component_a", .luaexpr = "{}" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_close = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render = .{ .component = "component_b", .luaexpr = "{}" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_close = {} } },
    }, &lex);
}

test "render, line w expr" {
    const fpath = "z.tpl";
    var lex = Lexer.init(fpath,
        \\  {{ field }}: {{@  hello_world {} }}
    );
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .fresh_line = .{ .indent = "  " } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr = "field" } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = ": " } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_open = {} } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render = .{ .component = "hello_world", .luaexpr = "{}" } } },
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .render_close = {} } },
    }, &lex);
}

test "code block" {
    const fpath = "y.tpl";
    var lex = Lexer.init(fpath,
        \\% @code
        \\for ndx, val in ipairs({1, 2, 3}) do
        \\  print(tostring(ndx) .. ": " .. tostring(val))
        \\done
        \\% @end
    );
    //try ppTokens(20, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .directive = .{ .tag = "code", .args = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "for ndx, val in ipairs({1, 2, 3}) do" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .luablock_line = .{ .indent = "  ", .lua = "print(tostring(ndx) .. \": \" .. tostring(val))" } } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "done" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .directive = .{ .tag = "end", .args = "" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

// TODO: atm not supported - return and implement escaping support
// test "code block -- multiline string esc test" {
//     const fpath = "y.tpl";
//     var lex = Lexer.init(fpath,
//         \\% @code
//         \\for ndx, val in ipairs({1, 2, 3}) do
//         \\  print(tostring(ndx) .. ": " .. tostring(val))
//         \\done
//         \\[[
//         \\% @end
//         \\]]
//         \\% @end
//     );
//     try ppTokens(20, &lex);
//     try expectTokens(&[_]Token{
//         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .directive = .{ .tag = "code", .args = "" } } },
//         .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "for ndx, val in ipairs({1, 2, 3}) do" } } },
//         .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .luablock_line = .{ .indent = "  ", .lua = "print(tostring(ndx) .. \": \" .. tostring(val))" } } },
//         .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "done" } } },
//         .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "[[" } } },
//         .{ .fpath = fpath, .lineno = 6, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "% @end" } } },
//         .{ .fpath = fpath, .lineno = 7, .col = 0, .data = .{ .luablock_line = .{ .indent = "", .lua = "]]" } } },
//         .{ .fpath = fpath, .lineno = 8, .col = 0, .data = .{ .directive = .{ .tag = "end", .args = "" } } },
//         .{ .fpath = fpath, .lineno = 8, .col = 0, .data = .{ .eof = {} } },
//     }, &lex);
// }

test "component start -- sudden EOF" {
    const fpath = "x.tpl";
    var lex = Lexer.init(fpath,
        \\% @component thing
    );

    try expectTokens(&[_]Token{
        Token{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .directive = .{ .tag = "component", .args = "thing" } } },
    }, &lex);
}

test "component start, then end (immediate EOF)" {
    const fpath = "x.tpl";
    var lex = Lexer.init(fpath,
        \\% @component thing
        \\% @end
    );

    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .directive = .{ .tag = "component", .args = "thing" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .directive = .{ .tag = "end", .args = "" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

test "component start, then end (newline)" {
    const fpath = "x.tpl";
    var lex = Lexer.init(fpath,
        \\% @component thing
        \\% @end
        \\
    );

    //try ppTokens(10, &lex);
    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .directive = .{ .tag = "component", .args = "thing" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .directive = .{ .tag = "end", .args = "" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}

// // test "lua block, single-quote escape " {
// //     // don't interpret '%>' (lua block close) when in escaped context
// //     const fpath = "x.tpl";
// //     var lex = Lexer.init(fpath,
// //         \\hello <% local x = 'close tag %>'.. "!" %>
// //     );
// //
// //     try expectTokens(&[_]Token{
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_open = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = " local x = 'close tag %>'.. \"!\" " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_close = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
// //     }, &lex);
// // }
// //
// // test "lua block, double-quote escape " {
// //     // don't interpret '%>' (lua block close) when in escaped context
// //     const fpath = "x.tpl";
// //     var lex = Lexer.init(fpath,
// //         \\hello <% local x = "close tag %>".. "!" %>
// //     );
// //
// //     try expectTokens(&[_]Token{
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_open = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = " local x = \"close tag %>\".. \"!\" " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_close = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
// //     }, &lex);
// // }
// //
// // test "lua block, multiline-str escape " {
// //     // don't interpret '%>' (lua block close) when in escaped context
// //     const fpath = "x.tpl";
// //     var lex = Lexer.init(fpath,
// //         \\hello <% local x = [[close tag %>]].. "!" %>
// //     );
// //
// //     try expectTokens(&[_]Token{
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .text = "hello " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_open = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = " local x = [[close tag %>]].. \"!\" " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_close = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
// //     }, &lex);
// // }
// //
// // test "lua block, single-line comment escape " {
// //     // don't interpret '%>' (lua block close) when in escaped context
// //     const fpath = "x.tpl";
// //     var lex = Lexer.init(fpath,
// //         \\<% --ignore all %>
// //         \\local x = 1 %>
// //     );
// //
// //     try expectTokens(&[_]Token{
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_open = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = " --ignore all %>" } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .newline = {} } },
// //         .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .lualine = "local x = 1 " } },
// //         .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .luablk_close = {} } },
// //         .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .eof = {} } },
// //     }, &lex);
// // }
// //
// // test "lua block, multiline-comment escape " {
// //     // don't interpret '%>' (lua block close) when in escaped context
// //     const fpath = "x.tpl";
// //     var lex = Lexer.init(fpath,
// //         \\<% local x = --[[close tag
// //         \\ %>]]-- 4 %>
// //     );
// //
// //     try expectTokens(&[_]Token{
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_open = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = " local x = --[[close tag\n %>]]-- 4 " } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .luablk_close = {} } },
// //         .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .eof = {} } },
// //     }, &lex);
// // }

test "prog1" {
    const fpath = "x.tpl";
    var lex = Lexer.init(fpath,
        \\% require "hello"
        \\% @component struct
        \\typedef struct {
        \\%for typ, lbl in ctx.members do
        \\{{ typ }} {{ lbl}};
        \\%end
        \\}
        \\% @end
    );

    try expectTokens(&[_]Token{
        .{ .fpath = fpath, .lineno = 1, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "require \"hello\"" } } },
        .{ .fpath = fpath, .lineno = 2, .col = 0, .data = .{ .directive = .{ .tag = "component", .args = "struct" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 3, .col = 0, .data = .{ .text = "typedef struct {" } },
        .{ .fpath = fpath, .lineno = 4, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "for typ, lbl in ctx.members do" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr = "typ" } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .text = " " } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr_open = {} } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr = "lbl" } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .luaexpr_close = {} } },
        .{ .fpath = fpath, .lineno = 5, .col = 0, .data = .{ .text = ";" } },
        .{ .fpath = fpath, .lineno = 6, .col = 0, .data = .{ .lualine = .{ .indent = "", .lua = "end" } } },
        .{ .fpath = fpath, .lineno = 7, .col = 0, .data = .{ .fresh_line = .{ .indent = "" } } },
        .{ .fpath = fpath, .lineno = 7, .col = 0, .data = .{ .text = "}" } },
        .{ .fpath = fpath, .lineno = 8, .col = 0, .data = .{ .directive = .{ .tag = "end", .args = "" } } },
        .{ .fpath = fpath, .lineno = 8, .col = 0, .data = .{ .eof = {} } },
    }, &lex);
}
