M = {}

function M.test_dirname(t)
	local tests = {
		{ "/path/to/hello.lua",  "/path/to" },
		{ "./path/to/hello.lua", "./path/to" },
		{ "hello.lua",           "" },
		{ "../path/to/../smth",  "../path/to/.." }
	}
	for _, data in ipairs(tests) do
		local input, expected = table.unpack(data)
		local actual = htt.fs.dirname(input)
		t:expect(expected, actual)
	end
end

function M.test_basename(t)
	local tests = {
		{ "/path/to/hello.lua", "hello.lua" },
		{ "hello.lua",          "hello.lua" },
		{ "./path/to/smth",     "smth" },
		{ "/path/to/smth/",     "smth" },
	}
	for _, data in ipairs(tests) do
		local input, expected = table.unpack(data)
		local actual = htt.fs.basename(input)
		t:expect(expected, actual)
	end
end

return M
