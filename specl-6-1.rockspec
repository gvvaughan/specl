package = "specl"
version = "6-1"
description = {
  homepage = "http://gvvaughan.github.io/specl",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
  detailed = "Develop and run BDD specs written in Lua for RSpec style workflow.",
}
source = {
  url = "http://github.com/gvvaughan/specl/archive/release-v6.zip",
  dir = "specl-release-v6",
}
dependencies = {
  "ansicolors",
  "luamacro >= 2.0",
  "lua >= 5.1",
  "lyaml",
}
external_dependencies = nil
build = {
  build_command = "./configure LUA='$(LUA)' LUA_INCLUDE='-I$(LUA_INCDIR)' --prefix='$(PREFIX)' --libdir='$(LIBDIR)' --datadir='$(LUADIR)' && make clean all",
  type = "command",
  copy_directories = {},
  install_command = "make install luadir='$(LUADIR)'",
}
