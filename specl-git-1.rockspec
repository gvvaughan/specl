package = "specl"
version = "git-1"
description = {
  detailed = "Develop and run BDD specs written in Lua for RSpec style workflow.",
  homepage = "http://gvvaughan.github.io/specl",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
}
source = {
  url = "git://github.com/gvvaughan/specl.git",
}
dependencies = {
  "luamacro >= 2.0",
  "lua >= 5.1, < 5.4",
  "lyaml >= 5",
  "stdlib >= 41",
}
external_dependencies = nil
build = {
  build_command = "LUA='$(LUA)' ./bootstrap && ./configure LUA='$(LUA)' LUA_INCLUDE='-I$(LUA_INCDIR)' --prefix='$(PREFIX)' --libdir='$(LIBDIR)' --datadir='$(LUADIR)' --datarootdir='$(PREFIX)' && make clean all",
  copy_directories = {
    "bin",
    "doc",
  },
  install_command = "make install luadir='$(LUADIR)' luaexecdir='$(LIBDIR)'",
  type = "command",
}
