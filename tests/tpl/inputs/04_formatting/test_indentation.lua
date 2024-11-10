local tpls = require("//indentation.htt")

local nodes = {
    { c = nil, prefix = nil},
    { c = tpls.NodeFlat1, id = "nf1"},
    { c = tpls.NodeFlat2, id = "nf2"},
    { c = tpls.NodeIndent1, id = "ni1"},
    { c = tpls.NodeIndent2, id = "ni2"},
    { c = tpls.NodeIndentBoth, id = "nib"},
}

local leaves = {
    { c = tpls.LeafFlat1, id = "lf1" },
    { c = tpls.LeafFlat2, id = "lf2" },
    { c = tpls.LeafIndent1, id = "li1" },
    { c = tpls.LeafIndent2, id = "li2" },
    { c = tpls.LeafIndentBoth, id = "lib" },
}

for _, node in ipairs(nodes) do
    local prefix, ctx
    for _, leaf in ipairs(leaves) do
        if node.c ~= nil then
            render(node.c, node.id .. "-" .. leaf.id .. ".txt", { child = leaf.c })
        else
            render(leaf.c, leaf.id .. ".txt", {})
        end
    end
end