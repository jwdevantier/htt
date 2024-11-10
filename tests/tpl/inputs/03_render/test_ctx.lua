
local tpl = require("//ctx.htt")

render(tpl.Top, "top.ctx", {name = "James"})
render(tpl.Top, "top.no-ctx.1", {})
render(tpl.Top, "top.no-ctx.2") -- implicit empty ctx

render(tpl.CtxPassthrough, "passthrough", {name = "James", profession = "plumber"})
render(tpl.CtxFromComponent, "ctx.from-component")