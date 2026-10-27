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
   'lua >= 5.1, < 5.6',
   'lpeg',
   'lyaml >= 5',
}

-- Specl is one file with these bundled in, so installing it needs them
-- only to build it.
build_dependencies = {
   'luamacro >= 2.5.1',
   'luarocks-build-luke >= 0.2',
   'optparse >= 2',
   'smush',
   'std._debug >= 1',
   'std.functional >= 2',
   'std.normalize >= 4',
   'std.prototype >= 2',
   'typecheck >= 4',
}

-- The rock installs only build-aux/specl, as the `specl` command: smush
-- bundles it from this source tree, and the libraries that it finds on the
-- Lua path, as `luarocks path` sets it, or else the default path.
local bundled = {
   'lib/specl/badargs.lua',
   'lib/specl/cli.lua',
   'lib/specl/color.lua',
   'lib/specl/expect.lua',
   'lib/specl/formatter/progress.lua',
   'lib/specl/formatter/report.lua',
   'lib/specl/formatter/tap.lua',
   'lib/specl/inprocess.lua',
   'lib/specl/loader.lua',
   'lib/specl/main.lua',
   'lib/specl/matchers.lua',
   'lib/specl/runner.lua',
   'lib/specl/sandbox.lua',
   'lib/specl/shell.lua',
   'lib/specl/std.lua',
   'lib/specl/util.lua',
   'lib/specl/version.lua.in',
   -- Spec files are macro-expanded at run time, with the macro package.
   'macro',
   'macro.Getter',
   'macro.TokenList',
   'macro.clexer',
   'macro.lexer',
   'optparse',
   'std._debug',
   'std.functional._base',
   'std.functional.init',
   'std.normalize',
   'std.normalize._core',
   'std.prototype._base',
   'std.prototype.container',
   'std.prototype.object',
   'typecheck',
}

-- The host provides the modules that are C, or that the specs of a project
-- have to share with specl, or that only some runs need, and the `package`
-- that specl searches the paths of its examples with.
local externals = {
   'package',
   'lpeg',
   'luacov',
   'posix.dirent',
   'posix.sys.stat',
   'posix.sys.time',
   'yaml',
}

-- Each library has the one copy of std.normalize's core that it was
-- released with as a file of its own, so use the bundled std.normalize's.
local aliases = {
   'optparse._normalize::std.normalize._core',
   'typecheck._normalize::std.normalize._core',
}

local smush = {'$SMUSH --main=specl.cli'}
for _, name in ipairs(externals) do
   smush[#smush + 1] = '--external=' .. name
end
smush[#smush + 1] = '$sources'
smush[#smush + 1] = table.concat(aliases, ' ')

build = {
   type = 'luke',

   -- A build without help2man keeps the man page that a release commits.
   variables = {
      HELP2MAN = {checkprog = 'HELP2MAN', progs = {'help2man', 'true'}},
      SMUSH    = {checkprog = 'SMUSH', progs = {'smush'}},
   },

   bin = {
      {['build-aux/specl'] = {
         command = 'LUA_PATH="$abs_top_srcdir/lib/?.lua;$abs_top_srcdir/lib/?/init.lua;$LUA_PATH;;"' ..
                   ' ' .. table.concat(smush, ' ') .. ' > $target',
         sources = bundled,
      }},
      -- ./specl runs bin/specl with the modules in this source tree.
      'specl.in',
   },

   ldocs = 'build-aux/config.ld.in',

   -- Document build-aux/specl.
   files = {
      {['doc/specl.1'] = {
         command = '$HELP2MAN --output=$target --no-info --name=Specl "$LUA build-aux/specl"',
         sources = 'build-aux/specl',
      }},
   },

   install = {
      bin = {specl = 'build-aux/specl'},
   },

   copy_directories = {'doc'},
}

if _MODREV == 'dev' then
   -- Stamp a development build with who made it, and from which commit.
   build.version = '$USER/$gitref'
   build.copy_directories = nil
end

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
   build_dependencies[#build_dependencies + 1] = 'gvvaughan/ldoc'

   source = {
      url = 'git+https://github.com/gvvaughan/specl.git',
   }
end
