local config = {
	update_mode = false,
	output_dir = nil,
	quiet = false,
	max_failures = math.huge, -- default to no limit
	using_temp_dir = false
}

local HTT_OUT_DIR_MARKER = ".htt_test_output_dir"

local HTT = htt.env.htt_path() -- path to HTT binary
local TESTS_TPL_ROOT_PATH = htt.fs.cwd():path()
local TESTS_INPUTS_PATH = htt.fs.path_join(TESTS_TPL_ROOT_PATH, "inputs")
local TESTS_EXPECTED_PATH = htt.fs.path_join(TESTS_TPL_ROOT_PATH, "expected")


local function reset_output_dir()
	-- used on non-temporary output dirs
	--
	-- first remove directory, then re-create and re-add the
	-- HTT_OUT_DIR_MARKER marker file.
	--
	-- We do this to avoid lingering files from earlier runs.
	local dirname = htt.fs.basename(config.output_dir)
	local parent, err = htt.fs.cwd():openDir(htt.fs.dirname(config.output_dir))
	if err ~= nil then
		return "failed to open parent directory (?!)"
	end

	local out_kind = parent:exists(dirname)
	if out_kind == "DIRECTORY" then
		local d, err = parent:openDir(dirname)
		if err ~= nil then
			return "failed to open config dir, but it exists"
		end
		if d:exists(HTT_OUT_DIR_MARKER) == nil then
			if config.update_mode then
				for relpath, kind in d:list() do
					print(string.format("%s (%s)", relpath, kind))
					d:remove(relpath)
				end
			else
				return string.format("'%s' is missing the '%s' file, I dare not remove all its contents, aborting!",
					config.output_dir, HTT_OUT_DIR_MARKER)
			end
		end
		d = nil

		_, err = parent:remove(dirname)
		if err ~= nil then
			return "failed to remove old output directory"
		end
	elseif out_kind ~= nil then
		return strint.format("object at '%s' identified as '%s', expected 'DIRECTORY'", config.output_dir, out_kind)
	end

	_, err = parent:makePath(dirname)
	if err ~= nil then
		return "failed to re-create output directory"
	end

	d, err = parent:openDir(dirname)
	if err ~= nil then
		return "failed to open newly re-created output directory"
	end

	_, err = d:touch(HTT_OUT_DIR_MARKER)
	if err ~= nil then
		return string.format("failed to create '%s' file", HTT_OUT_DIR_MARKER)
	end
end

local function cleanup_temp_dir()
	if config.using_temp_dir and config.output_dir then
		local parent, err = htt.fs.cwd():openDir(htt.fs.dirname(config.output_dir))
		if err ~= nil then
			error("could not open parent of tmp dir")
		end
		local tmpdir_name = htt.fs.basename(config.output_dir)

		local _, err = parent:remove(tmpdir_name)
		if err ~= nil then
			error(string.format("failed to remove '%s', aborting...\n", config.output_dir))
		end
	end
end

local function parse_env()
	-- Check for update mode
	config.update_mode = os.getenv("UPDATE_TESTS") == "1"

	-- Check for quiet mode
	config.quiet = os.getenv("QUIET") == "1"

	-- Check for failure limit
	local maxfail = os.getenv("MAXFAIL")
	if maxfail then
		config.max_failures = tonumber(maxfail)
		if not config.max_failures then
			error("MAXFAIL must be a number")
		end
	end

	-- Get output directory
	config.output_dir = os.getenv("HTT_OUT")

	if config.update_mode and config.output_dir then
		error(
			"cannot specify output_dir AND update mode (overwriting expected tests output) - options are mutually exclusive.")
	end

	-- Create temp dir if needed in normal mode and no output dir specified
	if not config.update_mode and not config.output_dir then
		config.output_dir = os.tmpname()
		config.using_temp_dir = true
		os.remove(config.output_dir) -- tmpname creates empty file, remove it
		if not config.quiet then
			print("Using temporary directory: " .. config.output_dir)
		end
	end

	if config.update_mode then
		config.output_dir = TESTS_EXPECTED_PATH
	end
end

-- Rest of the script remains largely the same
local function check_prerequisites()
	-- Check git availability
	local git_check = os.execute("git --version")
	if git_check ~= true then
		error("git must be available to run tests")
	end
end

local function ensure_test_output_dir()
	-- For temp dir, we already created it in parse_env
	local err = reset_output_dir()
	if err ~= nil then
		error(string.format("failed to reset output directory: %s", err))
	end
end

local function collect_tests()
	local tdir, err = htt.fs.cwd():openDir(TESTS_INPUTS_PATH)

	if err ~= nil then
		error(string.format("cannot open HTT tests directory '%s': %s", tinput_root, err))
	end

	local tests = {}
	local out_path = config.output_dir

	for relpath, kind in tdir:walk() do
		fname = htt.fs.basename(relpath)

		if fname:match("^test_[%w%s-_]+%.lua$") ~= nil then
			-- each test gets a similarly named directory
			local test_fname = fname:gsub("%.lua$", "")
			local test_id = htt.fs.path_join(htt.fs.dirname(relpath), test_fname)
			table.insert(tests, {
				name = test_id,
				script_path = htt.fs.path_join(TESTS_INPUTS_PATH, relpath),
				expected_path = htt.fs.path_join(TESTS_EXPECTED_PATH, test_id),
				out_path = htt.fs.path_join(out_path, test_id)
			})
		end
	end

	return tests
end

local function run_test(test)
	local cmd = string.format([[%s --out-dir="%s" "%s" 2>&1]], HTT, test.out_path, test.script_path)
	--print(string.format("$ %s", cmd))

	local pipe, err = io.popen(cmd, "r")
	if err ~= nil then
		-- TODO: figure out what to do here
		error(string.format("failed to execute test '%s': %s", test.script_path, err))
	end

	local output = pipe:read("*a")
	local _, _, exit_code = pipe:close()
	return exit_code == 0, output
end

local function test_diff(test)
	local cmd = string.format([[git diff --no-index --no-prefix "%s" "%s"]], test.expected_path, test.out_path)
	--print(string.format("$ %s", cmd))

	local pipe, err = io.popen(cmd, "r")
	if err ~= nil then
		-- TODO: figure out what to do here
		error(string.format("failed to get diff (%s)", cmd))
	end

	local diff = pipe:read("*a")
	local _, _, exit_code = pipe:close()
	return exit_code == 0, diff
end

function pp_err(test, htt_output, diff)
	print(string.format("\n________ %s ________", test.name))
	print("-- HTT Output:")
	print(htt_output)
	if diff ~= "" then
		print("-- Diff:")
		print(diff)
	end
end

function run_tests(tests)
	local stats = {
		fail = 0,
		ok = 0,
		tests = #tests,
	}

	if not config.quiet then
		print("\n")
	end

	for _, test in ipairs(tests) do
		ok, htt_output = run_test(test)
		if not ok then
			stats.fail = stats.fail + 1
		else
			ok, diff = test_diff(test)
			if not ok then
				stats.fail = stats.fail + 1
				pp_err(test, htt_output, diff)
			else
				print(string.format("%-90s[OK]", test.name))
				stats.ok = stats.ok + 1
			end
		end
		if stats.fail > config.max_failures then
			print("Maximum failures exceeded, exiting")
			os.exit(1)
		end
	end

	return stats, nil
end

function update_tests(tests)
	local is_ok = true
	for _, test in ipairs(tests) do
		ok, htt_output = run_test(test)
		if not ok then
			print(string.format("________ %s ________", test.name))
			print("HTT returned error when trying to run the test script:")
			print("HTT output:")
			print(htt_output)
			is_ok = false
		else
			print(string.format("%-90s[OK]", test.name))
		end
	end

	if not is_ok then
		error("\nOne or more tests failed to run, see above")
	end
end

local function main()
	parse_env()

	if not config.quiet then
		print("The following environment variables can change test execution:")
		print("")
		print("- HTT_OUT=PATH")
		print("\tspecify directory into which test outputs are written. The directory is not removed after execution")
		print("\tDefault: write to a temporary directory")
		print("- MAXFAIL=NUM")
		print("\tabort testing after more than NUM test failures")
		print("\tDefault: disabled (all tests are run)")
		print("- QUIET=1/0")
		print("\tset to '1' to operate in quiet mode. testing generates less output")
		print("\tDefault: 0 (disabled)")
		print("- UPDATE_TESTS=1/0")
		print("\tif set to 1 to write test outputs into the 'expected' folder")
		print("\tDefault: 0 (disabled)")
	end

	if not config.quiet then
		print("\nConfiguration:")
		for k, v in pairs(config) do
			print(string.format("  %s: %s", k, tostring(v)))
		end
	end

	check_prerequisites()
	ensure_test_output_dir()
	local tests = collect_tests()
	if not config.quiet then
		print(string.format("\nCollected %d tests", #tests))
	end

	if not config.update_mode then
		local stats, err = run_tests(tests)
		print(string.format("== %d failed, %d ok", stats.fail, stats.ok))
	else
		update_tests(tests)
		print("re-wrote tests/expected directory, examine changes before committing")
	end
end

-- Main program
local ok, err = pcall(function()
	main()
end)

if config.using_temp_dir then
	cleanup_temp_dir()
end

if not ok then
	print("Error: " .. err)
	os.exit(1)
end
