local _MODREV, _SPECREV = 'dev', '-1'

rockspec_format = '3.0'
package = 'specl'
version = _MODREV .. _SPECREV

description = {
   summary = 'Behaviour Driven Development for Lua',
   detailed = [[
      Develop and run BDD specs written in Lua for RSpec style workflow.
   ]],
   homepage = 'https://gvvaughan.github.io/specl',
   license = 'MIT',
}

source = {
   url = 'https://github.com/gvvaughan/specl/archive/v' .. _MODREV .. '.zip',
   dir = 'specl-' .. _MODREV,
}

dependencies = {
   'luamacro >= 2.5.1',
   'lua >= 5.1, < 5.6',
   'lyaml >= 5',
   'optparse',
   'stdlib >= 41.2.0, < 42.0.0',
   'typecheck >= 3.2',
}

build = {
   type = 'command',
   build_command = '$(LUA) build-aux/luke'
      .. ' package="' .. package .. '"'
      .. ' version="' .. _MODREV .. '"'
      .. ' PREFIX="$(PREFIX)"'
      .. ' LUA="$(LUA)"'
      ,
   install_command = '$(LUA) build-aux/luke install --quiet'
      .. ' INST_BINDIR="$(BINDIR)"'
      .. ' INST_LUADIR="$(LUADIR)"'
      ,
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}

if _MODREV == 'dev' then
   -- luarocks.org's ldoc fails on Lua 5.5; gvvaughan's works.
   build_dependencies = {'gvvaughan/ldoc'}

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/gvvaughan/specl.git',
   }
else
   -- A release commits its LDocs, so don't build them again.
   build.build_command = build.build_command .. ' LDOC=true'
end
