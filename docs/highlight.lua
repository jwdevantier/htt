local RESPONSE_MARKER = '>>RSP>>'
local server = nil
local srv_stdout = nil
local srv_stdin = nil

local request_id = 0

local function write(...)
	local _, err = srv_stdin:write(...)
	if err ~= nil then
		print(string.format("error writing '%s' to stdin: %s\n", ..., err))
	end
end

local function read(fmt, timeout)
	local out, err = srv_stdout:read(fmt, timeout)
	if err ~= nil and err ~= "TIMEOUT" then
		local msg = string.format("failed to read: %s\n", err)
		print("CRASH TIME")
		error(msg)
	elseif err ~= nil then -- TIMEOUT
		return nil
	end
	return out
end

local function read_line(timeout, incr)
	local t = 0
	local ti = incr or 10
	timeout = timeout or 10000
	while t < timeout do
		local res = read("*l", ti)
		if res ~= nil then
			return res
		else
			t = t + ti
		end
	end
	error("read_line timeout")
end

local function read_until_response()
	-- Read and discard lines until we see the response marker
	while true do
		local line = read_line()
		if line == RESPONSE_MARKER then
			print("  @rur - got RSP start")
			return
		elseif line ~= nil then
			print(string.format("  @rur - got line '%s'\n", line))
		else
			print("  @rur - got nil on read")
		end
	end
end

local function make_request(request, headers, body)
	-- Check if $length was incorrectly provided in headers
	if headers["$length"] then
		error("$length header cannot be set explicitly")
	end

	-- First the $rq header
	write("$rq: ", request, "\r\n")

	-- If body present, calculate length and add $length header
	if body then
		write("$length: ", tostring(#body), "\r\n")
	end

	-- Write all other headers
	for k, v in pairs(headers) do
		write(k, ": ", tostring(v), "\r\n")
	end

	-- Empty line separating headers from body
	write("\r\n")

	-- If body present, write it
	if body then
		write(body)
	end
end

local function read_request(timeout)
	local function split_header(line)
		local key, value = line:match("^([^:]+):%s*(.+)\r$") -- Note: changed pattern to expect \r
		if not key then
			error("malformed header: " .. line)
		end
		return key, value
	end

	-- Read first line, must be $rq header
	local first_line = read_line(timeout)
	if not first_line then
		return nil -- timeout
	end

	local rq_header, request = split_header(first_line)
	if rq_header ~= "$rq" then
		error("first header must be $rq")
	end

	-- Read headers until empty line
	local headers = {}
	local content_length = nil

	while true do
		local line = read_line(timeout)
		if not line then
			return nil -- timeout
		end

		-- Empty line (just \r) marks end of headers
		if line == "\r" then
			break
		end

		local key, value = split_header(line)
		if key == "$length" then
			content_length = tonumber(value)
			if not content_length then
				error("$length must be a number")
			end
		end
		headers[key] = value
	end

	-- Read body if content-length present
	local body = nil
	if content_length then
		body = read(content_length, timeout)
		if not body then
			return nil -- timeout
		end
		if #body ~= content_length then
			error("incomplete body read")
		end
	end

	return {
		request = request,
		headers = headers,
		body = body
	}
end

local function ensure_server()
	if server then return end
	print("--------- starting server")

	server = htt.proc.new({ "node", "highlighter.js" })
	if server == nil then
		error("failed to start server")
	end

	err = server:stdinBehavior(2)
	if err ~= nil then
		error(string.format("failed to set stdin behavior: %s\n", err))
	end
	server:stdoutBehavior(2)
	if err ~= nil then
		error(string.format("failed to set stdout behavior: %s\n", err))
	end

	server:spawn()
	srv_stdout = server:stdout()
	srv_stdin = server:stdin()

	-- Wait for server ready message
	print("-/listen time")
	while true do
		local line = read_line()
		if line and line:match("Ready for requests") then
			print("GOTCHA")
			break
		end
	end
end


local function highlight_code(code, language)
	ensure_server()

	-- Create request
	request_id = request_id + 1

	-- Send request
	make_request("/highlight", {
		lang = language,
		rid = request_id,
	}, code)

	local rq = read_request(5000)
	if rq == nil then
		error("failed to read response after making rq")
	end
	return rq.body;
end

local function cleanup()
	print("server cleanup routine called")
	print("TODO -- server:close is not implemented yet, NO-OP")
	-- if server then
	-- 	-- TODO: non-sense until streams freed, too
	-- 	server:close()
	-- 	server = nil
	-- end
end

return {
	highlight_code = highlight_code,
	cleanup = cleanup
}
