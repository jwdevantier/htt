-- tests ability to pass context to top-level component
render(require("//context.htt").Child, "out_unset.1")
render(require("//context.htt").Child, "out_unset.2")

render(require("//context.htt").Child, "out.john", {name = "john"})
render(require("//context.htt").Child, "out.jane", {name = "jane"})



render(require("//context.htt").Parent, "out.parent.john", {name = "john"})