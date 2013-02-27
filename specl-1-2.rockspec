source = {
  branch = "release-v1-2",
  url = "git://github.com/gvvaughan/specl.git",
}
build = {
  copy_directories = {
  },
  build_command = "LUA=$(LUA) LUA_INCLUDE=-I$(LUA_INCDIR) ./configure --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean all",
  install_command = "make install",
  type = "command",
}
dependencies = {
  "lua >= 5.1",
  "stdlib >= 33",
}
description = {
  homepage = "http://github.com/gvvaughan/specl/",
  summary = "Behaviour Driven Development for Lua",
  detailed = "      Develop and run BDD specs written in Lua for RSpec style workflow.\
     ",
  license = "GPLv3+",
}
version = "1-2"
package = "specl"
