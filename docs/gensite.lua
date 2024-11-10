local time_start = htt.time.timestamp_ms()
local conf = require("conf")

local cwd = htt.fs.cwd()
-- The base directory holding the generated output.
-- This is the finished site
local out_dir = htt.fs.path("out")

local ref2url = {}

local common = require "//common.htt"

-- TODO: break into 2 loops
--
-- 1:
--   * compute slug
--   * populate ref2slug (required for links)
--   * compute menu (yes, because computing slugs...)
-- 2:
--   *

local renderPage = function(page, section)
	-- TODO: if fails to require, warn in a nice way
	local tpl = require("//" .. page.refid .. ".htt")

	-- slug is also the dirpath, so create it in the out dir
	local out_dir = htt.fs.path("out" .. "/" .. page.slug)
	cwd:makePath(out_dir)
	local out_file = htt.fs.path_join(out_dir, "index.html")

	print("rendering " .. out_file)
	--render(tpl.main, out_file)
	render(common.base, out_file, {
		content = tpl.main,
		title = page.title,
		page = page,
	})
end

local preRender = function(page, section)
	-- compute slugs
	local slug
	if section ~= nil then
		slug = section.slug .. "/" .. page.slug
	else
		slug = page.slug
	end
	page.slug = "/" .. slug
end

for _, entry in ipairs(conf.site) do
	if conf.is_section(entry) then
		local section = entry
		for _, entry in ipairs(entry.pages) do
			preRender(entry, section)
		end
	elseif conf.is_page(entry) then
		preRender(entry, nil)
	end
end

for _, entry in ipairs(conf.site) do
	if conf.is_section(entry) then
		local section = entry
		for _, entry in ipairs(entry.pages) do
			renderPage(entry, section)
		end
	elseif conf.is_page(entry) then
		renderPage(entry, nil)
	end
end

for refid, page in pairs(conf.ref2page) do
	print(refid .. " -> " .. page.slug)
end

require("highlight").cleanup()

local time_end = htt.time.timestamp_ms()
print(string.format("Documentation generated in %dms", time_end - time_start))