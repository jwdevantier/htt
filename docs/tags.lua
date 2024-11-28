local M = {}

M.code = function(txt)
	return [[<code class="bg-stone-100 text-gray-700 text-sm font-mono px-1 py-0.5 rounded">]] .. txt .. [[</code>]]
end

M.raw = function(txt)
	return txt
end

M.h1 = function(txt)
	return [[<h1 class="text-4xl font-bold mt-6 mb-5">]] .. txt .. [[</h1>]]
end

M.h2 = function(txt)
	return [[<h2 class="text-2xl font-bold mt-6 mb-2">]] .. txt .. [[</h2>]]
end

M.h3 = function(txt)
	return [[<h3 class="text-lg font-bold mt-6 mb-2 text-slate-700">]] .. txt .. [[</h3>]]
end

M.h4 = function(txt)
	return [[<h4 class="text-base mt-6 mb-2 font-bold text-slate-500  decoration-dotted">]] .. txt .. [[</h4>]]
end


M.i = function(txt)
	return [[<em>]] .. txt .. [[</em>]]
end


M.todo = function(txt)
	local info = debug.getinfo(2, "Sl")
	if not info then
		error("unable to get caller info")
	end

	print("TODO [" .. info.short_src .. ":" .. info.currentline .. "]: " .. txt)
	return [[<span class="bg-purple-200 text-purple-900 rounded px-2 text-sm"><span class="font-bold pr-2">TODO:</span>]] ..
		 txt .. [[</span>]]
end

M.bookmark = function(id)
	return [[<span id="]] .. id .. [["></span>]]
end

return M
