local SITE_PREFIX = os.getenv("SITE_PREFIX") or "/"

-- will be using API descriptions also.
package.path = package.path .. ";../api/?.lua"
local api = require("api_desc")

local time_start = htt.time.timestamp_ms()
local model = require("model")

local cwd = htt.fs.cwd()

local common = require "//common.htt"

-- will hold a map of type definitions, from FQN to definition entry
local type_registry = {}

local render_page = function(page)
	local tpl

	local ctx = page.ctx or {}
	if type(ctx) ~= "table" then
		error(string.format("expected page.ctx to be nil or a table, got:\n%s", htt.str.stringify(ctx, "  ")))
	end

	if page.tpl == nil then
		-- TODO: if fails to require, warn in a nice way
		tpl = require("//" .. page.refid .. ".htt")
	else
		tpl = page.tpl
	end

	-- slug is also the dirpath, so create it in the out dir
	local out_dir = htt.fs.path("out" .. "/" .. string.sub(page.slug, #SITE_PREFIX + 1))
	cwd:make_path(out_dir)
	local out_file = htt.fs.path_join(out_dir, "index.html")

	print("rendering " .. out_file)
	-- TODO: here we pass along page.ctx so the same template can be reused
	--       for various pages.
	render(common.base, out_file, {
		content = tpl.main,
		title = page.title,
		page = page,
		ctx = ctx,
	})
end

local function module_items(module)
	return coroutine.wrap(function()
		for _, item in ipairs(module.content or {}) do
			coroutine.yield(item)
		end
	end)
end

local function register_types(registry, module, prefix)
	prefix = prefix .. "." .. module.name
	for item, _ in module_items(module) do
		if item.type == "type" or item.type == "alias" then
			registry[prefix .. "." .. item.name] = {
				module = prefix,
				kind = item.type,
				def = item.def
			}
		end
		-- Recurse into submodules
		if item.type == "module" then
			register_types(registry, item, prefix .. "." .. item.name)
		end
	end
end

local function resolve_type(type_name, current_module)
	-- If we see a FQN (starts with htt.), use it directly
	if type_name:match("^htt%.") then
		return type_registry[type_name]
	end

	-- Otherwise try as relative to current module first
	local qualified = current_module .. "." .. type_name
	if type_registry[qualified] then
		return type_registry[qualified]
	end

	-- Finally, check if it exists at top level
	return type_registry[type_name]
end


-- --------------------------------------------
-- Computation
-- --------------------------------------------
-- Populate `type_registry`
for item in module_items(api.htt) do
	register_types(type_registry, item, "htt")
end

-- Dynamically add top-level modules as API pages
local api_module_pages = {}

for item in module_items(api.htt) do
	if item.type == "module" then
		-- TODO: only works because we work strictly with top-level modules
		local mod_fqn = "htt." .. item.name
		local page = Page {
			title = mod_fqn,
			refid = "api-htt-" .. item.name,
		}
		page.tpl = require("//api_module.htt")
		page.ctx = {
			lookup = function(type_name)
				return resolve_type(type_name, mod_fqn)
			end,
			module = item,
		}
		table.insert(api_module_pages, page)
	end
end

table.insert(model.site, model.Section {
	"API Documentation",
	table.unpack(api_module_pages),
})

-- THEN do post-processing
-- (creating slugs, cross-referencing data-structures, ...)
model.site_post_process(SITE_PREFIX)

-- then render each page.
for _, entry in ipairs(model.site) do
	if model.is_section(entry) then
		for _, page in ipairs(entry.pages) do
			render_page(page)
		end
	elseif model.is_page(entry) then
		render_page(entry)
	end
end

require("highlight").cleanup()

local time_end = htt.time.timestamp_ms()
print(string.format("Documentation generated in %dms", time_end - time_start))



-- print(htt.str.stringify(api.htt))
print("type registry:")
print(htt.str.stringify(type_registry))
