package = "specl"
version = "9-1"
description = {
  detailed = "Develop and run BDD specs written in Lua for RSpec style workflow.",
  homepage = "http://gvvaughan.github.io/specl",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
}
source = {
  dir = "specl-release-v9",
  url = "http://github.com/gvvaughan/specl/archive/release-v9.zip",
}
dependencies = {
  "luamacro >= 2.0",
  "lua >= 5.1",
  "lyaml >= 4",
}
external_dependencies = nil
build = {
  copy_directories = {
    "bin",
    "doc",
  },
  modules = {},
  type = "builtin",
}
