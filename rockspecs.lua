-- Specl rockspec data

-- Variables to be interpolated:
--
-- package
-- version

local default = {
  package = package_name,
  version = version.."-1",
  source = {
    url = "http://github.com/gvvaughan/"..package_name.."/archive/release-v"..version..".zip",
    dir = package_name.."-release-v"..version,
  },
  description = {
    summary = "Behaviour Driven Development for Lua",
    detailed = [[
      Develop and run BDD specs written in Lua for RSpec style workflow.
     ]],
    homepage = "http://github.com/gvvaughan/"..package_name.."/",
    license = "GPLv3+",
  },
  dependencies = {
    "ansicolors",
    "luamacro >= 2.0",
    "lua >= 5.1",
    "lyaml",
  },
  build = {
    type = "command",
    build_command = "./configure " ..
      "LUA_INCLUDE=$(LUA_INCDIR) LUA=$(LUA) " ..
      "--prefix=$(PREFIX) --libdir=$(LIBDIR) --datadir=$(LUADIR) " ..
      "&& make clean all",
    install_command = "make install luadir=$(LUADIR)",
    copy_directories = {},
  },
}

if version ~= "git" then
  default.source.branch = "release-v"..version_dashed
else
  default.build.build_command = "./bootstrap && " .. default.build.build_command
end

return {default=default, [""]={}}
