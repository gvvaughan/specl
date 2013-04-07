version = "4-1"
source = {
  dir = "specl-release-v4",
  url = "http://github.com/gvvaughan/specl/archive/release-v4.zip",
}
package = "specl"
dependencies = {
  "ansicolors",
  "lua >= 5.1",
  "lyaml",
}
description = {
  homepage = "http://github.com/gvvaughan/specl/",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
  detailed = "      Develop and run BDD specs written in Lua for RSpec style workflow.\
     ",
}
build = {
  build_command = "LUA_INCLUDE=-I$(LUA_INCDIR) ./configure LUA=$(LUA) --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean && make",
  type = "command",
  copy_directories = {
  },
  install_command = "make install",
}
