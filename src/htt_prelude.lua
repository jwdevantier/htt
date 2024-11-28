htt.tpl.install_loader()

render = (function()
	local out_dir = HTT_OUT_PATH

	return function(component, out_fpath, ctx)
		ctx = ctx or {}

		local fpath = htt.fs.path_join(out_dir, out_fpath)
		local parent = htt.fs.dirname(fpath)
		local _, err = htt.fs.cwd():make_path(parent)
		if err ~= nil then
			error(string.format("cannot create directory '%s'", parent))
		end
		local fh = io.open(fpath, "w")
		if not fh then
			error("failed to open '" .. fpath .. "' for writing")
		end
		htt.tpl.render(function(...) fh:write(...) end, component, ctx)
		fh:close()
	end
end
)()
