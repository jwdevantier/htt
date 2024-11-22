local M = {}

-- TODO: would rather know if thing is component
function M.li(args)
	if type(args[1]) == "function" then
		return {
			tag = "li",
			fn = args[1],
			ctx = args[2],
		}
	elseif args[2] ~= nil then
		return {
			tag = "li",
			val = args[1],
			child = args[2],
		}
	else
		return {
			tag = "li",
			val = args[1],
		}
	end
end

local function list(tag, attrs, children)
	return {
		tag = tag,
		attrs = attrs,
		children = children,
	}
end

function M.ol(children)
	return list("ol", { class = { "list-decimal", "list-inside" } }, children)
end

function M.ul(children)
	return list("ul", { class = { "list-disc", "list-inside" } }, children)
end

return M
