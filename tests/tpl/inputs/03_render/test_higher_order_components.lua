-- A higher-order component in HTT is a component which takes as its input order component(s), which it then renders (or passes on to still other higher-order components).

local tpls = require("//hoc.htt")
render(tpls.HocComponent, "out", {
    child = tpls.MdH1,
    text = "Something Inspiring"
})
