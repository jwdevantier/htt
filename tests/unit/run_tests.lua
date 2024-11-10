print("RUN TESTS START")
local tests = {
	"test_json.lua",
	"test_fs.lua",
}

local retcode = 0 -- SUCCESS
for _, testfile in ipairs(tests) do
	local res = htt.test.run_tests(testfile)
	if res ~= 0 and retcode == 0 then
		retcode = 1
	end
end
os.exit(retcode)
