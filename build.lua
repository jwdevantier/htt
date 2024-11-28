local function run_htt(script, opts)
	local cmd = htt.env.htt_path()
	if opts.out_dir then
		cmd = cmd .. [[ --out-dir="]] .. opts.out_dir .. [["]]
	end
	cmd = cmd .. [[ "]] .. script .. [["]]
	print(cmd)
	cmd = cmd .. " 2>&1"

	local pipe, err = io.popen(cmd, "r")
	if err ~= nil or pipe == nil then
		-- TODO: figure out what to do here
		error(string.format("failed to build asset (command: %s): %s", cmd, err))
	end

	local output = pipe:read("*a")
	local _, _, exit_code = pipe:close()
	return exit_code == 0, output
end


print("building generated assets...")
run_htt("./api/generate_stubs.lua", { out_dir = "./src" })
