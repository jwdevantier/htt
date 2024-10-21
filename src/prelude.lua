--- HTT Prelude Library
--
-- For programming languages, the automatically imported code is sometimes
-- referred to as the prelude.
-- This module defines the prelude to htt, serving as an extension to
-- what the lua standard library provides.
--
-- @module htt


htt = {}
htt.str = {}
htt.fs = {}
htt.tpl = {}
htt.is = {}
htt.json = {}

-- STR Functions
-- ------------------------------------------------------------
function htt.str.join(sep, list)
	if #list == 0 then return "" end

	local res = list[1]

	for i = 2, #list do
		res = res .. sep .. list[i]
	end

	return res
end

function htt.str.stringify(value, indentation)
	indentation = indentation or ""
	if type(value) == "table" then
		local buf = { "{" }
		local nextIndent = indentation .. '  '
		local first = true
		for k, v in pairs(value) do
			if first then
				first = false
			else
				buf[#buf + 1] = ","
			end
			buf[#buf + 1] = "\n" .. nextIndent
			if type(k) == "string" then
				buf[#buf + 1] = string.format("%q = ", k)
			else
				buf[#buf + 1] = "["
				buf[#buf + 1] = htt.str.stringify(k, nextIndent)
				buf[#buf + 1] = "] = "
			end
			buf[#buf + 1] = htt.str.stringify(v, nextIndent)
		end
		if not first then -- if not empty, add newline and current indentation
			buf[#buf + 1] = '\n' .. indentation
		end
		buf[#buf + 1] = "}"
		return table.concat(buf)
	elseif type(value) == "string" then
		return string.format("%q", value)
	else
		return tostring(value)
	end
end

function htt.str.starts_with(str, prefix)
	return string.sub(str, 1, #prefix) == prefix
end

-- Utilities
-- ------------------------------------------------------------
function htt.enum(tbl)
	local inst = {}
	local mt = {
		__index = function(t, k) return t.values[k] end,
		__newindex = function() error("cannot modify enum values") end,
		__tostring = function(t) return t.label end,
	}

	local keys = {}
	for _, key in ipairs(tbl) do
		local enumValue = { label = key }
		setmetatable(enumValue, mt)
		inst[key] = enumValue
		table.insert(keys, key)
	end

	setmetatable(inst, {
		__tostring = function(t)
			return "enum{" .. htt.str.join(", ", keys) .. "}"
		end,
		__newindex = function() error("cannot add values to enum") end,
	})

	return inst
end

function htt.dofile_with_tb(script_fpath)
	-- Attempt to load the file
	local chunk, loadError = loadfile(script_fpath)
	if not chunk then
		-- If the file could not be loaded, print the load error and stop.
		return nil, "Error loading script: " .. loadError
	end

	local function err_handler(err)
		-- rewrite error output so [string "xxxx"] becomes xxxx
		-- This means [string "HTT Library"] shows up as HTT Library
		-- 2 => remove 2 innermost frames (this and dofile_with_tb)
		--      from call stack
		local tb = debug.traceback(err, 3)
		tb = tb:gsub('%[string "(.-)"%]', '[%1]')
		return tb
	end

	local ok, result = xpcall(chunk, err_handler)
	if not ok then
		-- If an error occurs during execution, print the traceback from the error handler
		return nil, "\nError during execution: " .. result
	end
	return result, nil
end

-- FS
-- ------------------------------------------------------------
htt.fs.ftype = htt.enum {
	"BLOCK_DEVICE",
	"CHARACTER_DEVICE",
	"DIRECTORY",
	"NAMED_PIPE",
	"SYM_LINK",
	"FILE",
	"UNIX_DOMAIN_SOCKET",
	"WHITEOUT",
	"DOOR",
	"EVENT_PORT",
	"UNKNOWN",
}

--- Get a directory handle to the current working directory
-- @return a directory handle to the current working directory
-- @usage dir = cwd()
function htt.fs.cwd()
	-- STUB
end

function htt.fs.path(s)
	return string.gsub(s, "/", htt.fs.sep)
end

function htt.fs.path_join(...)
	return table.concat({ ... }, htt.fs.sep)
end

function htt.fs.dirname(path)
	return string.match(path, "^(.*)/.*$") or "."
end

function htt.fs.basename(path)
	local res = string.match(path, "^.*/(.*)$") or path
	if res ~= "" then
		return res
	end
	local nxt = string.sub(path, 1, -2)
	if nxt == "" then
		return ""
	end
	return htt.fs.basename(nxt)
end

-- Validation
-- ------------------------------------------------------------
-- @section Validation
function htt.is.null(value)
	if type(value) ~= "nil" then
		return false, "Expected nil, got " .. type(value)
	end
	return true, nil
end

function htt.is.boolean(value)
	if type(value) ~= "boolean" then
		return false, "Expected boolean, got " .. type(value)
	end
	return true, nil
end

function htt.is.number(value)
	if type(value) ~= "number" then
		return false, "Expected number, got " .. type(value)
	end
	return true, nil
end

function htt.is.string(value)
	if type(value) ~= "string" then
		return false, "Expected string, got " .. type(value)
	end
	return true, nil
end

function htt.is.userdata(value)
	if type(value) == "userdata" then
		return false, "Expected userdata object, got " .. type(value)
	end
	return true, nil
end

function htt.is.fn(value)
	if type(value) ~= "function" then
		return false, "Expected function, got " .. type(value)
	end
	return true, nil
end

function htt.is.table(value)
	if type(value) ~= "table" then
		return false, "Expected table, got " .. type(value)
	end
	return true, nil
end

function htt.is.optional(validator)
	return function(value)
		if value == nil then
			return true, nil
		else
			local valid, err = validator(value)
			if valid then
				return true, nil
			else
				return false, err
			end
		end
	end
end

function htt.is.pred(pred, label)
	return function(value)
		local err = pred(value)
		if err ~= nil then
			return false, "Failed predicate '" .. label .. "'"
		end
		return true, nil
	end
end

function htt.is.any(...)
	local validators = { ... }
	return function(value)
		local errs = {}
		for _, validator in ipairs(validators) do
			local valid, err = validator(value)
			if valid then
				return true, nil
			else
				table.insert(errs, err)
			end
		end
		return false, errs
	end
end

function htt.is.all(...)
	local validators = { ... }
	return function(value)
		local errs = {}
		local has_errors = false
		for _, validator in ipairs(validators) do
			local valid, err = validator(value)
			if not valid then
				table.insert(errs, err)
				has_errors = true
			end
		end
		if has_errors then
			return false, errs
		else
			return true, nil
		end
	end
end

function htt.is.list_of(validator)
	return function(value)
		if type(value) ~= "table" then
			return false, "Expected a list table, got " .. type(value)
		end
		local errs = {}
		for ndx, val in ipairs(value) do
			local valid, err = validator(val)
			if err == nil then
				err = "<no details>"
			end
			if not valid then
				errs[ndx] = err
			end
		end
		if next(errs) == nil then
			return true, nil
		else
			return false, errs
		end
	end
end

function htt.is.table_with(spec)
	return function(value)
		if type(value) ~= "table" then
			return false, "Expected a table, got " .. type(value)
		end
		local errs = {}
		for key, validator in pairs(spec) do
			local valid, err = validator(value[key])
			if not valid then
				if err == nil then
					err = "<no details>"
				end
				errs[key] = err
			end
		end
		if next(errs) == nil then
			return true, nil
		else
			return false, errs
		end
	end
end

function htt.is.table_of(keyValidator, valValidator)
	return function(value)
		if type(value) ~= "table" then
			return false, "Expected a table, got " .. type(value)
		end
		local errs = {}
		for key, val in pairs(value) do
			local pair_errs = {}
			local valid, err = keyValidator(key)
			if not valid then
				pair_errs["key"] = err
			end
			valid, err = valValidator(val)
			if not valid then
				pair_errs["value"] = err
			end
			if next(pair_errs) ~= nil then
				errs[key] = pair_errs
			end
		end
		if next(errs) == nil then
			return true, nil
		else
			return false, errs
		end
	end
end

-- Template
---------------------------------------------------------------
-- @section debug
--- Compile template to lua module
-- @usage err = compile(template_path, output_path)
function htt.tpl.compile(tpl_fpath, mod_fpath)
	print("STUB: htt.tpl.compile")
end

function htt.tpl.render(writeFn, c_, ctx_)
	local stack = {}
	-- TODO: determine how come we write an initial newline whether fresh_line is true or false
	local fresh_line = false

	local function render_(component, context)
		local parent = stack[#stack]

		-- define starting state
		local rctx = {
			_base_indent = parent._base_indent .. parent._line_indent,
			_line_indent = ""
		}

		local ignore = true

		-- define API
		rctx.fl = function(indent)
			if not ignore then
				fresh_line = true
				rctx._line_indent = indent
			else
				ignore = false
			end
		end

		rctx.cont = function()
			fresh_line = false
		end

		rctx.write = function(...)
			if fresh_line then
				writeFn("\n", rctx._base_indent, rctx._line_indent, ...)
				fresh_line = false
			else
				writeFn(...)
			end
		end

		rctx.render = render_

		-- render
		table.insert(stack, rctx)
		component(rctx, context)
		table.remove(stack, #stack)
	end

	-- define top-level starting state
	table.insert(stack, {
		_base_indent = "",
		_line_indent = "",
	})

	-- render top-level component
	render_(c_, ctx_)
end

function htt.tpl.install_loader()
	local loader = function(module_name)
		if string.match(module_name, "^//.*%.htt$") == nil then
			return nil
		end
		-- strip leading //
		local mod_path = string.sub(module_name, 3)
		local fh = io.open(mod_path, "r")
		if fh == nil then
			return nil
		else
			fh:close()
		end

		local out_path = mod_path:gsub("%.lua?", ""):gsub("%.htt$", "") .. ".out.lua"
		local err = htt.tpl.compile(mod_path, out_path);
		if err ~= nil then
			local msg = {
				"Error compiling '" .. module_name .. "'"
			}
			if type(err) == "string" then
				table.insert(msg, err)
			elseif type(err) == "table" then
				table.insert(msg, "\tFile: '" .. mod_path .. "'")
				table.insert(msg, "\tLine: " .. err.lineno)
				table.insert(msg, "\tColumn: " .. err.column)
				table.insert(msg, "\tType: " .. err.type)
				if err.type == "lex_err" then
					table.insert(msg, "\tReason: " .. err.lex_reason)
					table.insert(msg, "\tState: " .. err.lex_state)
				else
					table.insert(msg, "\tReason: " .. err.reason)
				end
			end

			error(table.concat(msg, "\n"))
		end

		local chunk, err = loadfile(out_path)
		if chunk then
			return chunk
		else
			local msg = "\nError evaluating '" .. module_name .. "'"
			error(msg .. ":\n\t" .. err)
		end
	end

	table.insert(package.searchers, 1, loader)
end

-- @section Testing
htt.test = {}
htt.test.TestCtx = {}

function htt.test.eql(a, b)
	if getmetatable(a) ~= getmetatable(b) then
		return false
	end

	if a == b then
		-- numbers, bools, nil, two refs to same table
		return true
	end

	-- TODO string

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	local alen = 0
	for _ in pairs(a) do
		alen = alen + 1
	end
	local blen = 0
	for _ in pairs(b) do
		blen = blen + 1
	end

	if alen ~= blen then
		return false
	end


	-- deep/recursive equality checking
	local eql = htt.test.eql
	for k, v in pairs(a) do
		if not eql(v, b[k]) then
			return false
		end
	end

	for k, v in pairs(b) do
		if not eql(v, a[k]) then
			return false
		end
	end

	return true
end

function htt.test.TestCtx:new()
	local inst = { directive = nil, directive_msg = nil, descr = nil, defers = {} }
	self.__index = self
	return setmetatable(inst, self)
end

function htt.test.TestCtx:mark(directive, directive_msg)
	self.directive = directive
	self.directive_msg = directive_msg
end

function htt.test.TestCtx:describe(descr)
	self.descr = descr
end

function htt.test.TestCtx:skip(reason)
	self:mark("SKIP", reason)
	assert(false, "") -- stop further execution
end

function htt.test.TestCtx:fail(reason)
	self:mark("FAIL", reason)
	assert(false, "")
end

function htt.test.TestCtx:expect(expected, actual, msg)
	if not htt.test.eql(expected, actual) then
		if msg == nil then
			msg = ""
		end
		print("expected (" .. htt.str.stringify(expected) .. "), got: (" .. htt.str.stringify(actual) .. ")")
		self:fail(msg)
	end
end

function htt.test.TestCtx:defer(fn)
	table.insert(self.defers, fn)
end

function htt.test.run_tests(testfile_fpath)
	local test_env = {} -- TODO: do I care ?
	for k, v in pairs(_G) do
		test_env[k] = v
	end

	-- load module code
	local load_success, loaded_test_module = pcall(loadfile, testfile_fpath, "t", test_env)
	if not load_success then
		print("Failed to load test file '" .. testfile_fpath .. "'")
		print("---")
		print(loaded_test_module) -- on error, this holds the error message
		print("---")
		return 1
	end

	-- evaluate top-level code
	local exec_success, module = pcall(loaded_test_module)
	if not exec_success then
		print("Failed to evaluate test file '" .. testfile_fpath .. "'")
		print("")
		print("This happens when evaluating the top-level code of the test file causes")
		print("an error. See details of the error for more information:")
		print("Error ---")
		print(module) -- on error, holds the error message
		print("---")
		return 1
	end

	if type(module) ~= "table" then
		print("Expect test file to return a table containing test functions, got " .. type(module))
		return 1
	end

	local num_tests = 0
	local tests = {}
	for name, func in pairs(module) do
		if type(func) == "function" and name:sub(1, 4) == "test" then
			table.insert(tests, name)
			num_tests = num_tests + 1
		end
	end
	if os.getenv("TESTS_SORT") == "1" then
		table.sort(tests)
	end

	print("KTAP version 1")
	print("1.." .. num_tests)
	print("")

	-- evaluate tests
	local num_failed = 0
	local num_skipped = 0

	local recordTestStatus = function(name, test_id, success, testctx)
		local msg = {}
		if success or testctx.directive == "SKIP" then
			table.insert(msg, "ok")
		else
			table.insert(msg, "not ok")
			num_failed = num_failed + 1
		end

		table.insert(msg, test_id)
		table.insert(msg, "-")
		table.insert(msg, name)
		if (testctx.descr) then
			table.insert(msg, table.concat({ "(", testctx.descr, ")" }, ""))
		end
		if testctx.directive ~= nil then
			table.insert(msg, "# " .. testctx.directive)
			if testctx.directive == "SKIP" then
				num_skipped = num_skipped + 1
			end
			if testctx.directive_msg ~= nil then
				table.insert(msg, testctx.directive_msg)
			end
		end
		return table.concat(msg, " ")
	end

	local test_id = 0
	for _, name in ipairs(tests) do
		test_id = test_id + 1
		local func = module[name]
		local testctx = htt.test.TestCtx:new()
		local fh = io.open(".test-output", "w")

		test_env.print = function(...)
			local args = { ... }
			for i, v in ipairs(args) do
				args[i] = tostring(v)
			end
			fh:write(table.concat(args, "\t"), "\n")
			fh:flush()
		end

		-- test_env is a shallow copy of our own execution environment
		-- hence setting io.output(fh), thus redirecting output from
		-- `io.write(...)` to the file `fh` will affect both us and the
		-- test execution environment.
		local _, _ = pcall(function() io.output(fh) end, testctx)
		local success, ret = pcall(func, testctx)
		if not success then
			print("Error in test:")
			print(ret)
			print("Traceback:")
			print(debug.traceback())
		end
		local msg = recordTestStatus(name, test_id, success, testctx)

		-- run defers in reverse order of registration
		for i = 1, #testctx.defers do
			local d_num = #testctx.defers + 1 - i
			local d_func = testctx.defers[d_num]
			local d_success, d_ret = pcall(d_func)
			if not d_success then
				test_env.print(d_ret)
			end
		end

		-- test execution done, restore `io.write(...)` to stdout
		local _, _ = pcall(function() io.output(io.stdout) end, testctx)
		fh:close()
		if not success and testctx.directive ~= "SKIP" then
			if success ~= true then
				for line in io.lines(".test-output") do
					io.write("# ", line, "\n")
				end
			end
		end
		print(msg)
		print("")
	end

	print("")
	print("Skipped: " .. num_skipped)
	print("Failed:  " .. num_failed)
	if num_failed == 0 then
		return 0
	else
		return 1
	end
end
