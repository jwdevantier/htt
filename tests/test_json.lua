M = {}

function M.test_load_string(t)
	local tests = {
		["hello, world"] = [["hello, world"]],
		["xyz"] = [["xyz"]],
	}
	for expected, input in pairs(tests) do
		local actual, err = htt.json.loads(input)
		t:expect(nil, err, "failed to load JSON without error")
		t:expect(expected, actual)
	end
end

function M.test_load_number(t)
	local tests = {
		[1] = "1",
		[-2] = "-2",
		[3.15] = "3.15"
	}
	for expected, input in pairs(tests) do
		local actual, err = htt.json.loads(input)
		t:expect(nil, err, "failed to load JSON without error")
		t:expect(expected, actual)
	end
end

function M.test_load_boolean(t)
	local tests = {
		[true] = "true",
		[false] = "false",
	}
	for expected, input in pairs(tests) do
		local actual, err = htt.json.loads(input)
		t:expect(nil, err, "failed to load JSON without error")
		t:expect(expected, actual)
	end
end

function M.test_load_null(t)
	local actual, err = htt.json.loads("null")
	t:expect(nil, err, "failed to load JSON without error")
	t:expect(nil, actual)
end

function M.test_load_array(t)
	local tests = {
		[{ 1, 2, 3 }] = "[1, 2, 3]",
		[{ "xyz", "foo" }] = [=[["xyz", "foo"]]=],
		[{ true, false }] = [=[[true, false]]=],
		[{ 1, "xyz", true }] = [=[[1, "xyz", true]]=],
		[{ { 1, 2 }, 3 }] = [=[[[1, 2], 3]]=],
		[{ { 1, 2 }, { one = 1, two = 2 } }] = [=[[[1, 2], {"one": 1, "two": 2}]]=],
		[{ 1, nil, "xyz" }] = [=[[1, null, "xyz"]]=]
	}
	for expected, input in pairs(tests) do
		local actual, err = htt.json.loads(input)
		t:expect(nil, err, "failed to load JSON without error")
		t:expect(expected, actual)
	end
end

function M.test_load_object(t)
	local tests = {
		[{ one = 1, two = 2 }] = [[{"one": 1, "two": 2}]],
		-- this is tricky, this only works because the JSON is loaded
		-- in and entries in associative tables where the value is nil
		-- are considered UNSET in lua.
		[{ str = "hello", num = 2, bool = false }] =
		[[{"str": "hello", "num": 2, "bool": false, "null": null}]],
	}
	for expected, input in pairs(tests) do
		local actual, err = htt.json.loads(input)
		t:expect(nil, err, "failed to load JSON without error")
		t:expect(expected, actual)
	end
end

function M.test_dumps(t)
	local tests = {
		{ [["hello, world"]],    "hello, world" },
		{ [[3e0]],               3 },
		{ [[false]],             false },
		{ "[1e0,2e0,3e0]",       { 1, 2, 3 } },
		-- iteration order in tables is unknown, hence cannot test
		-- against tables with multiple keys here
		{ [[{"one":1e0}]],       { one = 1 } },
		{ [[{"hello":"world"}]], { hello = "world" } },
		{ [[{"isDone":false}]],  { isDone = false } },
		{ [[null]],              nil },
		{ [[3.14e0]],            3.14 },
	}
	for _, data in ipairs(tests) do
		local expected, input = table.unpack(data)
		local val, err = htt.json.dumps(input)
		t:expect(nil, err, "failed to dump to JSON with error")
		t:expect(expected, val)
	end
end

function M.test_table_roundtrip(t)
	local tests = {
		-- { one = 1, two = 2 },
		{ one = 1 },

	}

	for _, tbl in ipairs(tests) do
		local str, err = htt.json.dumps(tbl)
		print("RT1 (err: " .. tostring(err) .. ")")
		t:expect(nil, err, "failed to dump to JSON with error")
		print("RT2")
		local actual
		actual, err = htt.json.loads(str)
		print("RT3")
		t:expect(nil, err, "unexpected error reading JSON back into Lua types")
		print("RT4")
		t:expect(tbl, actual)
		print("RT5")
	end
end

return M
