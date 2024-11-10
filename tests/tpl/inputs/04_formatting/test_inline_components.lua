local tpls = require("//inline_components.htt")

local outers = {
    { c = tpls.OuterFlat1, id = "of1" },
    { c = tpls.OuterFlat2, id = "of2" },
    { c = tpls.OuterIndent1, id = "oi1" },
    { c = tpls.OuterIndent2, id = "oi2" },
}

local inners = {
    { c = tpls.InnerFlat1, id = "if1" },
    { c = tpls.InnerFlat2, id = "if2" },
    { c = tpls.InnerIndent1, id = "ii1" },
    { c = tpls.InnerIndent2, id = "ii2" },
}

for _, outer in ipairs(outers) do
    for _, inner in ipairs(inners) do
        render(outer.c, outer.id .. "-" .. inner.id .. ".txt", {child = inner.c})
    end
end