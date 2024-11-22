-- Function to determine the type with special handling for callable tables
local function getDetailedType(value)
	local basicType = type(value)
	if basicType == "table" then
		local mt = getmetatable(value)
		if mt and mt.__call then
			return "callable_table"
		end
	end
	return basicType
end

-- Internal recursive inspection function
local function _inspectAPI(tbl, path, result, visited)
	if tbl == nil then
		error("Cannot inspect nil value" .. (path and " at " .. path or ""))
	end

	if type(tbl) ~= "table" then
		error("Expected table, got " .. type(tbl) .. (path and " at " .. path or ""))
	end

	if visited[tbl] then
		return result
	end
	visited[tbl] = true

	local keys = {}
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys)

	for _, key in ipairs(keys) do
		local value = tbl[key]
		local currentPath = path == "" and key or path .. "." .. key
		local valueType = getDetailedType(value)

		result[currentPath] = {
			type = valueType,
			path = currentPath,
			key = key
		}

		if valueType == "table" then
			_inspectAPI(value, currentPath, result, visited)
		end
	end

	return result
end

-- Public entry point that sets up initial state
local function inspectAPI(tbl)
	return _inspectAPI(tbl, "", {}, {})
end

-- Format results as string
local function formatResults(results)
	if not results then return "No results to format" end

	local output = {}
	local paths = {}
	for path in pairs(results) do
		table.insert(paths, path)
	end
	table.sort(paths)

	for _, path in ipairs(paths) do
		local entry = results[path]
		table.insert(output, string.format("%s (%s)", path, entry.type))
	end

	return table.concat(output, "\n")
end

-- Main execution
if not _G.htt then
	error("Global 'htt' table not found")
end

local results = inspectAPI(_G.htt)
print(formatResults(results))

