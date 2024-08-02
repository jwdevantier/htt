const std = @import("std");
const tok = @import("token.zig");
const Allocator = std.mem.Allocator;
const LexState = tok.LexState;

// Very rarely used ASCII character, we will use this to signify the lack of a value
const DC1: u8 = 17; // Device Control 1
const CH_EOF: u8 = DC1;

// Strategy:
//
// Objective: lex and support UTF8 files, but since we rely solely on delimiter characters
//            within the ASCII table set, we can actually iterate over the string as a sequence
//            of bytes.
//            UTF8 doesn't really have a character concept, the closest similarity is a grapheme
//            cluster, which represents a single visual character.
//            A grapheme cluster may be made up of multiple code-points, and code-points may be
//            made up of 1-4 bytes.
//            ASCII characters are encoded as a 1 byte codepoint (and its own grapheme cluster),
//            rarer characters take more space (codepoints using 2, 3 or 4 bytes).
//
//            All this to say that for our usecase, provided delimiters which are also valid
//            ASCII table characters, iterating over the input on a per-byte basis, looking for
//            these delimiters, is OK.

// NOTE: lexer allows text @ top-level pre component, which is wrong
//       enforce at parser level.

// TODO: code to lex until '\n\s*% @end' -- emit single block of lua code

pub const LexErr = struct {
    const DirExpectedAt = "Expected whitespace or '@' sign to signify start of directive";
    const DirectiveTagMissing = "Directive is missing its tag (i.e. @component, @code, @end)";
    const ExpectedWs = "Expected whitespace";
    const UnexpectedNewline = "Unexpected newline";
    const UnexpectedEof = "Unexpected end of file";
    const ComponentIdMissing = "Render expression should start with a component identifier";
    const Illegal = "Illegal state, lexing aborted";
};

// NOTE: IDEA: std.unicode.utf8ByteSequenceLength(b: u8)
//   - COULD use to calculate col of tokens.
//   - For ease of use, this just requires:
//     - token to have a startPos (byte offset)
//     - access to the input file

const Either = enum { left, right };

// TODO: could create a factory function for a more generalized type
const ScanResult = union(Either) { left: tok.Token, right: u64 };
const PosOrErrToken = union(Either) { left: tok.Token, right: u64 };

inline fn skipWhitespace(input: []const u8, pos: u64) u64 {
    var pos_ = pos;
    while (pos_ < input.len) : (pos_ += 1) {
        if (chIsWhitespace(input[pos_])) {} else break;
    }
    return pos_;
}

inline fn peekOrEof(input: []const u8, peek_pos: u64) u8 {
    return (if (input.len > peek_pos) input[peek_pos] else CH_EOF);
}

inline fn chIsLetter(ch: u8) bool {
    return ('a' <= ch and ch <= 'z') or ('A' <= ch and ch <= 'Z');
}

inline fn chIsDigit(ch: u8) bool {
    return ('0' <= ch and ch <= '9');
}

inline fn chIsWhitespace(ch: u8) bool {
    return (ch == ' ' or ch == '\t' or ch == '\r');
}

inline fn cmp1(comptime T: type, a: []const T, b: []const T, b_offset: u64) bool {
    return (a[0] == b[b_offset]);
}

inline fn cmp2(comptime T: type, a: []const T, b: []const T, b_offset: u64) bool {
    return (a[0] == b[b_offset] and a[1] == b[b_offset + 1]);
}

inline fn cmp3(comptime T: type, a: []const T, b: []const T, b_offset: u64) bool {
    return (a[0] == b[b_offset] and a[1] == b[b_offset + 1] and a[2] == b[b_offset + 2]);
}

inline fn cmp4(comptime T: type, a: []const T, b: []const T, b_offset: u64) bool {
    return (a[0] == b[b_offset] and a[1] == b[b_offset + 1] and a[2] == b[b_offset + 2] and a[3] == b[b_offset + 3]);
}

inline fn peekMatch(input: []const u8, pos: u64, comptime slice: []const u8) bool {
    const cmpFn = comptime switch (slice.len) {
        1 => cmp1,
        2 => cmp2,
        3 => cmp3,
        4 => cmp4,
        else => @compileError("no support for slices of this length"),
    };
    return ((pos + 1 + slice.len) < input.len and cmpFn(u8, slice, input, pos + 1));
}

pub const Lexer = struct {
    fpath: []const u8,
    input: []const u8,
    lineno: u32 = 1,
    last_nl_pos: u64 = 0, // with this, we can calculate the
    pos: u64 = 0,
    state: LexState = LexState.toplevel,
    lex_err: ?tok.Token = null,

    //NOTE: input must outlive the lexer
    pub fn init(fpath: []const u8, input: []const u8) Lexer {
        const inst = .{ .fpath = fpath, .input = input };
        return inst;
    }

    pub fn eof(self: *@This()) bool {
        return self.state == LexState.eof;
    }

    fn consumeNewline(self: *@This(), pos: u64) void {
        if (self.input[pos] != '\n') {
            std.debug.panic("expected to be at newline\n (pos: {}, ch {})", .{ pos, self.input[pos] });
        }
        self.pos = pos + 1; // consume \n
        self.lineno += 1;
        self.last_nl_pos = pos;
    }

    inline fn lexUntilChNoNewline(self: *@This(), input: []const u8, pos_: u64, comptime ch: u8) ScanResult {
        var pos = pos_;
        while (pos < input.len) {
            if (input[pos] == ch) {
                return .{ .right = pos };
            } else if (input[pos] == '\n') {
                const t = self.setIllegalState(pos, LexErr.UnexpectedNewline);
                return .{ .left = t };
            }
            pos += 1;
        }

        const t = self.setIllegalState(pos, LexErr.UnexpectedEof);
        return .{ .left = t };
    }

    inline fn lexUntilCh(self: *@This(), input: []const u8, pos_: u64, comptime ch: u8) ScanResult {
        var pos = pos_;
        while (pos < input.len) : (pos += 1) {
            if (input[pos] == ch) {
                return .{ .right = pos };
            }
        }

        const t = self.setIllegalState(pos, LexErr.UnexpectedEof);
        return .{ .left = t };
    }

    inline fn lexUntilSliceNoNewline(self: *@This(), input: []const u8, pos_: u64, comptime slice: []const u8) ScanResult {
        var pos = pos_;
        const cmpFn = comptime switch (slice.len) {
            1 => cmp1,
            2 => cmp2,
            3 => cmp3,
            4 => cmp4,
            else => @compileError("no support for slices of this length"),
        };
        // NOTE: deliberately not checking that the slice isn't longer than the input string
        const end = input.len - slice.len;
        while (pos < end) : (pos += 1) {
            if (cmpFn(u8, slice, input, pos)) {
                return .{ .right = pos };
            } else if (input[pos] == '\n') {
                const t = self.setIllegalState(pos, LexErr.UnexpectedNewline);
                return .{ .left = t };
            }
        }

        while (pos < input.len) : (pos += 1) {
            if (input[pos] == '\n') {
                const t = self.setIllegalState(pos, LexErr.UnexpectedNewline);
                return .{ .left = t };
            }
        }

        // TODO: could perhaps impove, issue is we're in quoted context
        const t = self.setIllegalState(pos, LexErr.UnexpectedEof);
        return .{ .left = t };
    }

    inline fn lexUntilSlice(self: *@This(), input: []const u8, pos_: u64, comptime slice: []const u8) ScanResult {
        var pos = pos_;
        const cmpFn = comptime switch (slice.len) {
            1 => cmp1,
            2 => cmp2,
            3 => cmp3,
            4 => cmp4,
            else => @compileError("no support for slices of this length"),
        };
        // NOTE: deliberately not checking that the slice isn't longer than the input string
        const end = input.len - slice.len + 1;
        while (pos < end) : (pos += 1) {
            if (cmpFn(u8, slice, input, pos)) {
                return .{ .right = pos };
            }
        }

        // could perhaps impove, issue is we're in quoted context
        // remaining chars cannot solve the issue
        const t = self.setIllegalState(pos, LexErr.UnexpectedEof);
        return .{ .left = t };
    }

    fn newToken(self: *@This()) tok.Token {
        return tok.Token{
            .fpath = self.fpath,
            .lineno = self.lineno,
            .col = @intCast(self.pos - self.last_nl_pos),
            .data = .{ .illegal = .{ .reason = "<unset>", .state = self.state } },
        };
    }

    fn setIllegalState(self: *@This(), pos: u64, reason: []const u8) tok.Token {
        self.pos = pos;
        var t = self.newToken();
        t.data = .{ .illegal = .{ .reason = reason, .state = self.state } };
        self.state = LexState.illegal;
        self.lex_err = t;
        return t;
    }

    fn _lexDirective(self: *@This()) tok.Token {
        const input = self.input;
        var pos = self.pos;

        // position of the start of the directive tag
        if (pos == input.len) {
            return self.setIllegalState(pos, LexErr.UnexpectedEof);
        } else if (input[pos] == '\n') {
            return self.setIllegalState(pos, LexErr.UnexpectedNewline);
        }

        const dtag_start_pos = pos;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            if (chIsLetter(ch) or chIsDigit(ch) or ch == '_') {} else {
                break;
            }
        }
        const dtag_end_pos = pos;
        if (dtag_start_pos == dtag_end_pos) {
            return self.setIllegalState(dtag_start_pos, LexErr.DirectiveTagMissing);
        }

        var t = self.newToken();
        t.data = .{ .directive = .{ .tag = input[dtag_start_pos..dtag_end_pos], .args = "" } };

        if (pos == input.len) {
            self.pos = pos;
            self.state = LexState.eof;
            return t;
        } else if (input[pos] == '\n') {
            self.pos = pos;
            self.state = .line_end;
            return t;
        }

        // ensure what followed the tag is a whitespace character
        if (!chIsWhitespace(input[pos])) {
            return self.setIllegalState(pos, LexErr.ExpectedWs);
        }
        // skip any additional whitespace
        pos = skipWhitespace(input, pos);

        const darg_start_pos = pos;
        while (pos < input.len) : (pos += 1) {
            if (input[pos] == '\n') {
                break;
            }
        }

        self.pos = pos;
        if (pos == input.len) {
            self.state = .eof;
        } else if (input[pos] == '\n') {
            self.state = .line_end;
        }

        t.data.directive.args = input[darg_start_pos..pos];
        return t;
    }

    fn lexDirective(self: *@This()) tok.Token {
        const t = self._lexDirective();
        if (std.mem.eql(u8, t.data.directive.tag, "code")) {
            // skipping past .line_end state, so must register newline
            self.consumeNewline(self.pos);
            self.state = LexState.lua_blk;
        }
        // TODO: could check more here, such as if not @end at EOF, then ERROR
        return t;
    }

    fn lexLuaLine(self: *@This(), indent: []const u8) tok.Token {
        const input = self.input;
        var pos = self.pos;

        if (pos == input.len) {
            return self.setIllegalState(pos, LexErr.UnexpectedEof);
        } else if (input[pos] == '\n') {
            return self.setIllegalState(pos, LexErr.UnexpectedNewline);
        }

        // capture characters until newline verbatim, assume regular lua
        while (pos < input.len) {
            if (input[pos] == '\n') {
                var t = self.newToken();
                t.data = .{
                    .lualine = .{
                        .lua = std.mem.trimRight(u8, input[self.pos..pos], " \t"),
                        .indent = indent,
                    },
                };
                self.pos = pos;
                self.state = .line_end;
                return t;
            }
            pos += 1;
        }

        // EOF
        self.state = LexState.eof;
        if (self.pos < pos) {
            // pack up what we have as a lua line
            var t = self.newToken();
            t.data = .{ .lualine = .{ .lua = input[self.pos..pos], .indent = indent } };
            self.pos = pos;
            return t;
        }
        return self.lexEof();
    }

    fn lexTextLineStart(self: *@This()) tok.Token {
        const input = self.input;
        const pos = self.pos;
        self.state = .text;

        const ch = peekOrEof(input, pos);
        const ch1 = peekOrEof(input, pos + 1);
        if (ch == '~' and ch1 == '>') {
            var t = self.newToken();
            t.data = .{ .line_continuation = {} };
            self.pos += 2;
            return t;
        } else {
            return self.lexText();
        }
    }

    fn lexText(self: *@This()) tok.Token {
        const input = self.input;
        var pos = self.pos;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            if (ch == '\n') {
                if (self.pos == pos) {
                    // no text, proceed directly to line end
                    // (example: empty lines, lines ending in luaexpr or render)
                    return self.lexLineEnd();
                }

                self.state = .line_end;
                var t = self.newToken();
                t.data = .{ .text = input[self.pos..pos] };
                self.pos = pos;
                return t;
            } else if (ch == '{') {
                // peek next ch, iff '{', found a delimiter
                const ch1 = peekOrEof(input, pos + 1);
                if (ch1 != '{') {
                    // not a delimiter, treat as character, continue
                    continue;
                }
                const ch2 = peekOrEof(input, pos + 2);
                if (ch2 == '@') {
                    // render component
                    if (self.pos < pos) {
                        var t = self.newToken();
                        t.data = .{ .text = input[self.pos..pos] };
                        self.pos = pos;
                        self.state = LexState.render_open;
                        return t;
                    }
                    return self.lexRenderOpen();
                } else {
                    // lua expression
                    if (self.pos < pos) {
                        var t = self.newToken();
                        t.data = .{ .text = input[self.pos..pos] };
                        self.pos = pos;
                        self.state = LexState.lua_expr_open;
                        return t;
                    }
                    return self.lexLuaExprOpen();
                }
            }
        }
        // out of characters, EOF
        self.state = LexState.eof;
        if (self.pos < pos) {
            // emit text up until EOF
            var t = self.newToken();
            t.data = .{ .text = input[self.pos..pos] };
            self.pos = pos;
            return t;
        }
        return self.lexEof();
    }

    fn lexRenderOpen(self: *@This()) tok.Token {
        var t = self.newToken();
        t.data = .{ .render_open = {} };
        self.pos += 3; // '{{@'
        self.state = LexState.render;
        return t;
    }

    fn lexRender(self: *@This()) tok.Token {
        // I would parse the component identifier
        // Then refactor lexLuaExpr loop to be usable from both fns
        // Then fix up the loop itself, I think it needs to balance squiggly brackets
        var pos = self.pos;
        const input = self.input;

        // skip ws after '{{@' opening
        pos = skipWhitespace(input, pos);

        // position of the start of the component identifier
        if (pos == input.len) {
            return self.setIllegalState(pos, LexErr.UnexpectedEof);
        } else if (input[pos] == '\n') {
            return self.setIllegalState(pos, LexErr.UnexpectedNewline);
        }

        const id_start = pos;
        const ch1 = peekOrEof(input, pos);
        if (!chIsLetter(ch1) and ch1 != '_') {
            // error
        }
        pos += 1;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            if (chIsLetter(ch) or chIsDigit(ch) or ch == '_' or ch == '.') {} else break;
        }

        if (id_start == pos) {
            return self.setIllegalState(pos, LexErr.ComponentIdMissing);
        }

        const component = input[id_start..pos];

        if (!chIsWhitespace(peekOrEof(input, pos))) {
            return self.setIllegalState(pos, LexErr.ExpectedWs);
        }
        pos = skipWhitespace(input, pos);

        const luaexpr_start = pos;
        switch (self.lexUntilExprClose(pos)) {
            .left => |token| {
                return token;
            },
            .right => |newPos| {
                pos = newPos;
            },
        }

        var t = self.newToken();
        t.data = .{ .render = .{ .component = component, .luaexpr = std.mem.trimRight(u8, input[luaexpr_start..pos], " \t\r") } };
        self.pos = pos; // '}}'
        self.state = LexState.render_close;
        return t;
    }

    fn lexRenderClose(self: *@This()) tok.Token {
        // called from lexRender where pos @ '}' and pos+1 is '}'
        var t = self.newToken();
        t.data = .{ .render_close = {} };
        self.pos += 2; // '}}'
        self.state = LexState.text;
        return t;
    }

    fn lexLuaExprOpen(self: *@This()) tok.Token {
        // called from lexText where pos @ '{' and next chr is '{'
        var t = self.newToken();
        t.data = .{ .luaexpr_open = {} };
        self.pos += 2; // '{{'
        self.state = LexState.lua_expr;
        return t;
    }

    fn lexLuaExpr(self: *@This()) tok.Token {
        var pos = self.pos;
        // TODO: either improve to handle {{@ c {}}} or demand ending in ' }}'
        switch (self.lexUntilExprClose(self.pos)) {
            .left => |token| {
                return token;
            },
            .right => |newPos| {
                pos = newPos;
            },
        }

        var t = self.newToken();
        t.data = .{ .luaexpr = std.mem.trim(u8, self.input[self.pos..pos], " \t") };
        self.pos = pos;
        self.state = LexState.lua_expr_close;
        return t;
    }

    fn lexUntilExprClose(self: *@This(), pos_: u64) PosOrErrToken {
        const input = self.input;
        var pos = pos_;
        var lvl: i32 = 1;
        while (pos < input.len) : (pos += 1) {
            switch (input[pos]) {
                '{' => { // new opening squiggly
                    lvl += 1;
                },
                '}' => {
                    lvl -= 1;
                    if (lvl == 0 and peekOrEof(input, pos + 1) == '}') {
                        // returns with pos @ first '}'
                        return .{ .right = pos };
                    }
                    // else, not a closing delimiter, continue
                },
                '\'' => { // single-quoted string escaping
                    switch (self.lexUntilChNoNewline(input, pos + 1, '\'')) {
                        .left => |token| {
                            return .{ .left = token };
                        },
                        .right => |newPos| {
                            pos = newPos;
                        },
                    }
                },
                '"' => { // double-quoted string escaping
                    switch (self.lexUntilChNoNewline(input, pos + 1, '"')) {
                        .left => |token| {
                            return .{ .left = token };
                        },
                        .right => |newPos| {
                            pos = newPos;
                        },
                    }
                },
                '[' => { // [[-string escaping
                    if (peekOrEof(input, pos + 1) == '[') {
                        switch (self.lexUntilSliceNoNewline(input, pos, "]]")) {
                            .left => |token| {
                                return .{ .left = token };
                            },
                            .right => |newPos| {
                                // consume chars also
                                pos = newPos + "]]".len;
                            },
                        }
                    }
                    // else, not a multiline string, continue
                    // TODO: support [=*[ strings?
                },
                '\n' => { // illegal newline inside expr
                    return .{ .left = self.setIllegalState(pos, LexErr.UnexpectedNewline) };
                },
                else => {},
            }
        }
        // EOF, would always expect '}}' first
        return .{ .left = self.setIllegalState(pos, LexErr.UnexpectedEof) };
    }

    fn lexLuaExprClose(self: *@This()) tok.Token {
        // called from lexLuaExpr where pos @ '}' and pos+1 is '}'
        var t = self.newToken();
        t.data = .{ .luaexpr_close = {} };
        self.pos += 2; // '}}'
        self.state = LexState.text;
        return t;
    }

    fn lexLuaBlock(self: *@This()) tok.Token {
        const input = self.input;
        var pos = self.pos;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            switch (ch) {
                ' ', '\t', '\r' => {},
                '\n' => {
                    // empty line
                    var t = self.newToken();
                    t.data = .{ .luablock_line = .{ .indent = input[self.pos..pos], .lua = "" } };
                    self.consumeNewline(pos);
                    return t;
                },
                '%' => {
                    const pct_pos = pos;
                    // skip WS after '%'
                    pos = skipWhitespace(input, pos + 1);

                    // check if we have the start of a directive line
                    if (input.len == pos or input[pos] != '@') {
                        // will probably be an illegal lua line, but that possibility
                        // should be allowed for, generally.
                        pos = pct_pos;
                        break;
                    }
                    pos += 1; // consume '@'

                    self.pos = pos; // update so lexDirective starts at proper offset
                    const t = self._lexDirective();
                    if (!std.mem.eql(u8, t.data.directive.tag, "end")) {
                        return self.setIllegalState(pos, LexErr.Illegal); // TODO: describe issue. Require end directive
                    }
                    return t;
                },
                else => {
                    break;
                },
            }
        }

        if (pos == input.len) {
            return self.setIllegalState(pos, LexErr.UnexpectedEof);
        }

        const lua_start = pos;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            switch (ch) {
                '\n' => {
                    var t = self.newToken();
                    t.data = .{ .luablock_line = .{ .indent = input[self.pos..lua_start], .lua = input[lua_start..pos] } };
                    self.consumeNewline(pos);
                    return t;
                },
                else => {},
            }
        }
        // only possible if pos == input.len
        return self.setIllegalState(pos, LexErr.UnexpectedEof);
    }

    fn lexLineEnd(self: *@This()) tok.Token {
        self.consumeNewline(self.pos);
        self.state = .toplevel;
        return self.lexToplevel();
    }

    fn lexSignificantNl(self: *@This()) tok.Token {
        // misnomer.. MAY become significant WL.. iff. NL
        self.state = .toplevel;
        var t = self.newToken();
        t.data = .{ .text = "" };
        self.pos += 1; //consume '\n'
        self.lineno += 1;
        return t;
    }

    // TODO: lexStart is needed, lexSignificantNl but with else branch OK
    //       optional way to add significant leading whitespace lines

    fn lexToplevel(self: *@This()) tok.Token {
        const input = self.input;
        var pos = self.pos;
        while (pos < input.len) : (pos += 1) {
            const ch = input[pos];
            switch (ch) {
                ' ', '\t', '\r' => {},
                '\n' => {
                    // stand-alone (significant) whitespace line
                    var t = self.newToken();

                    // in this case, we'll interpret any non-nl whitespace as the contents of the text line
                    // so given that we ONLY loop past WS in this loop, we don't need to advance the position
                    t.data = .{ .fresh_line = .{ .indent = input[self.pos..pos] } };
                    self.pos = pos;
                    self.state = .significant_nl;
                    return t;
                },
                '%' => {
                    const indent = input[self.pos..pos];

                    // skip '%' (+1) and then any ws after
                    pos = skipWhitespace(input, pos + 1);

                    if (input[pos] == '\n') {
                        return self.setIllegalState(pos, LexErr.UnexpectedNewline);
                    } else if (pos == input.len) {
                        return self.setIllegalState(pos, LexErr.UnexpectedEof);
                    }

                    if (input[pos] == '@') {
                        self.pos = pos + 1; // discard other chrs, skip '@'
                        return self.lexDirective();
                    } else {
                        self.pos = pos; // skip leading ws up to lua code
                        return self.lexLuaLine(indent);
                    }
                },
                else => {
                    var t = self.newToken();
                    t.data = .{ .fresh_line = .{ .indent = input[self.pos..pos] } };
                    self.pos = pos;
                    self.state = LexState.textline_start;
                    return t;
                },
            }
        }
        return self.lexEof();
    }

    fn lexEof(self: *@This()) tok.Token {
        var t = self.newToken();
        t.data = .{ .eof = {} };
        self.state = LexState.eof;
        return t;
    }

    pub fn nextToken(self: *@This()) tok.Token {
        return switch (self.state) {
            .toplevel => self.lexToplevel(),
            .textline_start => self.lexTextLineStart(),
            .text => self.lexText(),
            .lua_expr_open => self.lexLuaExprOpen(),
            .lua_expr => self.lexLuaExpr(),
            .lua_expr_close => self.lexLuaExprClose(),
            .render_open => self.lexRenderOpen(),
            .render => self.lexRender(),
            .render_close => self.lexRenderClose(),
            .lua_blk => self.lexLuaBlock(),
            .significant_nl => self.lexSignificantNl(),
            .line_end => self.lexLineEnd(),
            .eof => self.lexEof(),
            .illegal => {
                if (self.lex_err) |err| {
                    return err;
                } else {
                    std.debug.panic("in illegal state, but lex_err not set\n", .{});
                }
            },
        };
    }
};
