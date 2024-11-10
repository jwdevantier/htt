local tpls = require("//nl_tests.htt")

local outers = {
    { c = tpls.Outer, id = "o"},
    { c = tpls.OuterInline1, id = "oi1"},
    { c = tpls.OuterInline2, id = "oi2"},
}

local children = {
    { c = tpls.L1, id = "l1" },
    { c = tpls.L2, id = "l2" },
    { c = tpls.T1, id = "t1" },
    { c = tpls.T2, id = "t2" },
    { c = tpls.L1T1, id = "l1t1" },
    { c = tpls.L2T2, id = "l2t2" },
}


for _, outer in ipairs(outers) do
    local prefix, ctx
    for _, child in ipairs(children) do
        render(outer.c, outer.id .. "-" .. child.id .. ".txt", { child = child.c })
    end
end