local M = {}

function generate_slug(input)
	-- Replace '&' with 'and'
	local slug = string.gsub(input, "&", "and")

	-- Convert to lowercase
	local slug = string.lower(input)

	-- Replace non-alphanumeric characters with hyphens
	slug = string.gsub(slug, "[^%w%s-]", "-")

	-- Replace spaces with hyphens
	slug = string.gsub(slug, "%s", "-")

	-- Replace consecutive hyphens with a single hyphen
	slug = string.gsub(slug, "%-+", "-")

	-- Remove leading and trailing hyphens
	slug = string.gsub(slug, "^%-+", "")
	slug = string.gsub(slug, "%-+$", "")

	return slug
end

Page = {}
Page.__index = Page

function Page:new(vars)
	local inst = setmetatable({}, self)

	if vars.title == nil then
		error("pages must have a title")
	end
	inst.title = vars.title
	inst.slug = vars.slug or generate_slug(inst.title)
	inst.refid = vars.refid or inst.slug

	return inst
end

setmetatable(Page, {
	-- Make Page callable
	__call = function(cls, ...)
		return cls:new(...)
	end
})

M.is_page = function(inst)
	return type(inst) == "table" and getmetatable(inst) == Page
end

Section = {}
Section.__index = Section

function Section:new(args)
	if type(args) ~= "table" then
		error("Section constructor expects a table argument", 2)
	end

	if type(args[1]) ~= "string" then
		error("First element of Section constructor table must be a string (title)", 2)
	end

	local inst = setmetatable({}, self)
	inst.title = args[1]
	inst.slug = generate_slug(inst.title)
	inst.pages = {}

	-- Process additional arguments
	for i = 2, #args do
		if M.is_page(args[i]) then
			table.insert(inst.pages, args[i])
		else
			error("Argument " .. i .. " is not a Page instance", 2)
		end
	end

	return inst
end

-- Make Section callable
setmetatable(Section, {
	__call = function(cls, ...)
		return cls:new(...)
	end
})

-- Function to check if an instance is a Section
M.is_section = function(instance)
	return type(instance) == "table" and getmetatable(instance) == Section
end


local compute_slug = function(site_prefix, page, section)
	-- compute slugs
	local slug
	if section ~= nil then
		slug = section.slug .. "/" .. page.slug
	else
		slug = page.slug
	end
	page.slug = site_prefix .. slug
end


-- TODO: enforce that all refids are unique
--       and build up a link map


-- TODO: expect a '<refid>.htt', main to correspond to a page
M.site = {
	Page {
		title = "What is HTT?",
		refid = "htt-intro",
		slug = ""
	},
	Page {
		title = "Setup",
		refid = "setup",
	},
	Page {
		title = "Quick Start",
		refid = "quick-start",
	},
	Section {
		"Handbook",
		Page {
			title = "Syntax Recap",
			refid = "syntax-recap",
		},
		Page {
			title = "Debug",
			refid = "debug"
		},
		Page {
			title = "Modules and files",
			refid = "modules-and-files"
		},
	},
	Section {
		"Examples",
		Page {
			title = "Implementing types in Go",
			refid = "ex-go-ast"
		},
	}
}

-- TODO: could import code for preprocessing API here

-- page.refid -> page instance
M.ref2page = {}
-- page.refid -> parent section (if any)
M.ref2section = {}

M.site_post_process = function(site_prefix)
	-- NOTE: run *after* adding all pages and sections to site variable
	for _, entry in ipairs(M.site) do
		if M.is_section(entry) then
			local section = entry
			for _, page in ipairs(section.pages) do
				M.ref2page[page.refid] = entry
				M.ref2section[page.refid] = section
				compute_slug(site_prefix, page, section)
			end
		elseif M.is_page(entry) then
			M.ref2page[entry.refid] = entry
			compute_slug(site_prefix, entry, nil)
		end
	end
end

M.generate_slug = generate_slug
M.Page = Page
M.Section = Section

return M
