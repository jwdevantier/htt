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

local renderPage = function (page, section)
    local slug
    if section ~= nil then
        slug = section.slug .. "/" .. page.slug
    else
        slug = page.slug
    end
    -- store url, can be used for links later
    ref2url[page.refid] = "/" .. slug

    -- TODO: if fails to require, warn in a nice way
    local tpl = require("//" .. page.refid .. ".htt")

    -- slug is also the dirpath, so create it in the out dir
    local out_dir = htt.fs.path("out" .. "/" .. slug)
    cwd:makePath(out_dir)
    local out_file = htt.fs.path_join(out_dir, "index.html")

    print("rendering " .. out_file)
    --render(tpl.main, out_file)
    render(common.base, out_file, {
        content = tpl.main,
        -- TODO break renderPage in two, compute slugs and ref2slug first
        title = page.title,
    })
end

for _, entry in ipairs(conf.site) do    
    if is_section(entry) then
        local section = entry
        print("# " .. entry.title)
        for _, entry in ipairs(entry.pages) do
            renderPage(entry, section)
        end

    elseif is_page(entry) then
        renderPage(entry, nil)
    end
end

-- for refid, url in pairs(ref2url) do
--     print(refid .. " -> " .. url)
-- end