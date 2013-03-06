source = {
  dir = "specl-release-v2-1",
  url = "http://github.com/gvvaughan/specl/archive/release-v2-1.zip",
}
version = "2-1"
external_dependencies = {
  YAML = {
    library = "yaml",
  },
}
package = "specl"
dependencies = {
  "lua >= 5.1",
  "stdlib >= 33",
}
description = {
  homepage = "http://github.com/gvvaughan/specl/",
  license = "GPLv3+",
  summary = "Behaviour Driven Development for Lua",
  detailed = "      Develop and run BDD specs written in Lua for RSpec style workflow.\
     ",
}
build = {
  build_command = "LUA=$(LUA) LUA_INCLUDE=-I$(LUA_INCDIR) ./configure CPPFLAGS=-I$(YAML_INCDIR) LDFLAGS='-L$(YAML_LIBDIR)' --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean && make",
  type = "command",
  copy_directories = {
  },
  install_command = "make install",
}
