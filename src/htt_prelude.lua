htt.tpl.install_loader()

function render(component, out_fpath, ctx)
	ctx = ctx or {}
	local fh = io.open(out_fpath, "w")
	if not fh then
		error("failed to open '" .. out_fpath .. "' for writing")
	end
	htt.tpl.render(function(...) fh:write(...) end, component, ctx)
	fh:close()
end
