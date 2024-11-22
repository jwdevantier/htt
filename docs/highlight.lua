local BUFSIZ = 16384
local PORT = 2456
local CMD_HIGHLIGHT = 1
local CMD_SHUTDOWN = 0
local MSG_LEN_BYTES = 4
local CMD_BYTES = 2

local server = nil
--- @type htt.tcp.Stream
local stream = nil
--- @type htt.tcp.Buffer
local buf = nil
local rq_id = 0

local function ensure_server()
	if server then return end

	local err = nil

	buf, err = htt.tcp.buffer(BUFSIZ);
	if err ~= nil then
		error(string.format("failed to allocate buffer: %s", err))
	end

	local addr, err = htt.tcp.addr("127.0.0.1", PORT)
	if err ~= nil then
		error(string.format("failed to resolve address: %s", err))
	end

	print("--------- starting server")
	-- TODO: use own process wrapper, Lua's abstraction has limitations
	-- (cannot get process handle, so cannot reliably kill the process)
	-- (cannot both read from and write to streams....)
	server = io.popen(string.format("node highlighter.js %d", PORT), "w")

	-- TODO: given own abstraction, listen to 'ready for messages'
	print("connecting client...")
	local retry = 3
	while retry > 0 do
		htt.time.sleep(200 * htt.time.ns_per_ms)
		retry = retry - 1

		stream, err = htt.tcp.connect(addr)
		if err == nil then
			break
		end
		print("ERR, RECONNECTING")
	end

	if err ~= nil then
		error(string.format("failed to connect to endpoint: %s", err))
	end
end

local function highlight_code(code, language)
	ensure_server()

	if buf == nil or stream == nil then
		error(string.format("invariant broken: buf and/or stream is nil"))
	end

	rq_id = rq_id + 1
	if language == nil then
		language = "htt"
	end

	local msg = string.format("lang:%s;%s", language, code)
	buf:seek(0)
	local msg_len = CMD_BYTES + #msg -- msg length is: msg_len + cmd + message
	buf:write_u32le(msg_len)
	buf:write_u16le(CMD_HIGHLIGHT)
	buf:write_string(msg)
	local rq_len = buf:tell()

	buf:seek(0)
	err = stream:send(buf, rq_len)
	if err ~= nil then
		error(string.format("failed to send highlight request[%d]: %s", rq_id, err))
	end

	-- NOW, read rsp msg_len, then msg itself, which is HTML to send back verbatim
	buf:seek(0)
	_, err = stream:recv(buf, MSG_LEN_BYTES)
	if err ~= nil then
		error(string.format("failed to read request[%d] response length: %s", rq_id, err))
	end

	buf:seek(0)
	local rsp_len = buf:read_u32le()
	buf:seek(0)
	_, err = stream:recv_at_least(buf, rsp_len)
	if err ~= nil then
		error(string.format("failed to read request[%d] response length: %s", rq_id, err))
	end

	buf:seek(0)
	return buf:read_string(rsp_len)
end

local function cleanup()
	if server ~= nil and buf ~= nil and stream ~= nil then
		print("Shutting Down Highlight Server")
		buf:seek(0)
		buf:write_u32le(CMD_BYTES)
		buf:write_u16le(CMD_SHUTDOWN)
		local rq_len = buf:tell()
		buf:seek(0)
		err = stream:send(buf, rq_len)
		if err ~= nil then
			print(string.format("failed to shut down server: %s", err))
		end
		server = nil
	else
		print("Highlight Server Already Dead")
	end
end

return {
	highlight_code = highlight_code,
	cleanup = cleanup,
}
