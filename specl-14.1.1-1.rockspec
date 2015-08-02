package = "specl"
version = "14.1.1-1"
description = {
  detailed = "Develop and run BDD specs written in Lua for RSpec style workflow.",
  homepage = "http://gvvaughan.github.io/specl",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
}
source = {
  dir = "specl-release-v14.1.1",
  url = "http://github.com/gvvaughan/specl/archive/release-v14.1.1.zip",
}
dependencies = {
  "luamacro >= 2.0",
  "lua >= 5.1, < 5.4",
  "lyaml >= 5",
  "stdlib >= 41",
}
external_dependencies = nil
build = {
  copy_directories = {
    "bin",
    "doc",
  },
  modules = {
    ["specl.badargs"] = "lib/specl/badargs.lua",
    ["specl.color"] = "lib/specl/color.lua",
    ["specl.compat"] = "lib/specl/compat.lua",
    ["specl.formatter.progress"] = "lib/specl/formatter/progress.lua",
    ["specl.formatter.report"] = "lib/specl/formatter/report.lua",
    ["specl.formatter.tap"] = "lib/specl/formatter/tap.lua",
    ["specl.inprocess"] = "lib/specl/inprocess.lua",
    ["specl.loader"] = "lib/specl/loader.lua",
    ["specl.main"] = "lib/specl/main.lua",
    ["specl.matchers"] = "lib/specl/matchers.lua",
    ["specl.runner"] = "lib/specl/runner.lua",
    ["specl.shell"] = "lib/specl/shell.lua",
    ["specl.std"] = "lib/specl/std.lua",
    ["specl.util"] = "lib/specl/util.lua",
    ["specl.version"] = "lib/specl/version.lua",
  },
  type = "builtin",
}
