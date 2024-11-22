local function capitalize(str)
	return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

local function pascalCase(...)
	local out = ""
	for i, part in ipairs({ ... }) do
		if i ~= 1 then
			out = out .. capitalize(part)
		else
			out = out .. part
		end
	end
	return out
end

local function tblCopy(tbl)
	if type(tbl) ~= "table" then
		error(string.format("expected a table, got %s", type(tbl)))
	end
	local _tbl = {}
	for key, val in pairs(tbl) do
		_tbl[key] = val
	end
	return _tbl
end

local function concat(lst, ...)
	local res = {}
	for i = 1, #lst do
		res[i] = lst[i]
	end

	local args = { ... }
	for i = 1, #args do
		res[#res + 1] = args[i]
	end

	return res
end
