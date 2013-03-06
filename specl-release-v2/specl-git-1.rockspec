source = {
  dir = "specl-release-vgit-1",
  url = "http://github.com/gvvaughan/specl/archive/release-vgit-1.zip",
}
version = "git-1"
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
  build_command = "./bootstrap && LUA=$(LUA) LUA_INCLUDE=-I$(LUA_INCDIR) ./configure CPPFLAGS=-I$(YAML_INCDIR) LDFLAGS='-L$(YAML_LIBDIR)' --prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) && make clean && make",
  type = "command",
  copy_directories = {
  },
  install_command = "make install",
}
