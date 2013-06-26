package = "specl"
version = "8-1"
description = {
  homepage = "http://gvvaughan.github.io/specl",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
  detailed = "Develop and run BDD specs written in Lua for RSpec style workflow.",
}
source = {
  url = "http://github.com/gvvaughan/specl/archive/release-v8.zip",
  dir = "specl-release-v8",
}
dependencies = {
  "ansicolors",
  "luamacro >= 2.0",
  "lua >= 5.1",
  "lyaml",
}
external_dependencies = nil
build = {
  modules = {
    ["specl.std"] = "lib/specl/std.lua",
    ["specl.formatter.tap"] = "lib/specl/formatter/tap.lua",
    ["specl.color"] = "lib/specl/color.lua",
    ["specl.shell"] = "lib/specl/shell.lua",
    specl = "lib/specl.lua",
    ["specl.matchers"] = "lib/specl/matchers.lua",
    ["specl.formatter.progress"] = "lib/specl/formatter/progress.lua",
    ["specl.util"] = "lib/specl/util.lua",
    ["specl.optparse"] = "lib/specl/optparse.lua",
    ["specl.formatter.report"] = "lib/specl/formatter/report.lua",
  },
  type = "builtin",
  copy_directories = {
    "bin",
    "docs",
  },
}
