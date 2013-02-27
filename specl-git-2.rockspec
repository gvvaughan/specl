package = "specl"
description = {
  homepage = "http://github.com/gvvaughan/specl/",
  detailed = "      Develop and run BDD specs written in Lua for RSpec style workflow.\
     ",
  summary = "Behaviour Driven Development for Lua",
  license = "GPLv3+",
}
source = {
  url = "git://github.com/gvvaughan/specl.git",
}
dependencies = {
  "lua >= 5.1",
  "stdlib >= 33",
}
version = "git-2"
build = {
  build_command = "./bootstrap && LUA=$(LUA) LUA_INCLUDE=-I$(LUA_INCDIR) ./configure --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean all",
  copy_directories = {
  },
  type = "command",
  install_command = "make install",
}
