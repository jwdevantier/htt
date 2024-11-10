render(require("//lua_lines.htt").Main, "out")

render(require("//lua_lines.htt").LuaLineLoop, "out.loop")

render(require("//lua_lines.htt").ConditionalRender, "out.true", {show = true})
render(require("//lua_lines.htt").ConditionalRender, "out.false", {show = false})