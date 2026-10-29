-- Use the source, Luke!
-- Copyright (C) 2026 Gary V. Vaughan

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

dependencies = {
   'lua >= 5.1, < 5.6',
   'lpeg',
   'lyaml >= 5',
}

source = {
   url = 'https://github.com/gvvaughan/specl/archive/v' .. _MODREV .. '.zip',
   dir = 'specl-' .. _MODREV,
}

if _MODREV == 'dev' then
   source = {
      url = 'git+https://github.com/gvvaughan/specl.git',
   }
end

build = {
   type = 'builtin',

   -- The rock installs a program, and not the modules of lib that it is made
   -- from, which builtin would find in a release for itself.
   modules = {},

   install = {
      bin = {specl = 'build-aux/specl'},
   },

   -- A release commits its man page and LDocs to install.
   copy_directories = {'doc'},
}

if _MODREV == 'dev' then
   -- The rock installs only build-aux/specl as the `specl` command.
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
      'ansicolors',
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

   build.type = 'luke'

   -- Specl is one file with these bundled in, so a development build
   -- needs them only to build it.
   build_dependencies = {
      'ansicolors >= 1',
      'luamacro >= 2.5.1',
      'luarocks-build-luke >= 0.3.1',
      'optparse >= 3',
      'smush >= 0.1',
      'std._debug >= 1.2',
      'std.functional >= 2.1',
      'std.normalize >= 5.0.1',
      'std.prototype >= 2.1',
      'typecheck >= 4',
      -- luarocks.org's ldoc fails on Lua 5.5; gvvaughan's works.
      'gvvaughan/ldoc',
   }

   -- A build without help2man keeps the man page that a release commits.
   build.variables = {
      HELP2MAN = {checkprog = 'HELP2MAN', progs = {'help2man', 'true'}},
      SMUSH    = {checkprog = 'SMUSH', progs = {'smush'}},
   }

   -- The host provides compiled modules.
   --
   -- Each library shares one copy of std.normalize's core.
   local smush = '$SMUSH --main=specl.cli' ..
      ' --external=package --external=lpeg --external=luacov' ..
      ' --external=posix.dirent --external=posix.sys.stat --external=posix.sys.time' ..
      ' --external=yaml' ..
      ' $sources' ..
      ' optparse._normalize::std.normalize._core' ..
      ' typecheck._normalize::std.normalize._core'

   build.bin = {
      {['build-aux/specl'] = {
         command = 'LUA_PATH="$abs_top_srcdir/lib/?.lua;$abs_top_srcdir/lib/?/init.lua;$LUA_PATH;;"' ..
                   ' ' .. smush .. ' > $target',
         sources = bundled,
      }},
      -- ./specl runs bin/specl with the modules in this source tree.
      'specl.in',
   }

   build.ldocs = 'build-aux/config.ld.in'

   -- Document build-aux/specl.
   build.files = {
      {['doc/specl.1'] = {
         command = '$HELP2MAN --output=$target --no-info --name=Specl "$LUA build-aux/specl"',
         sources = 'build-aux/specl',
      }},
   }

   -- Stamp a development build with who made it, and from which commit.
   build.version = '$USER/$gitref'
   build.copy_directories = nil
end

-- The specs run the source in lib, not the build-aux/specl that a release
-- commits, so they need the libraries that it bundles, whether or not a
-- development build needs them.
test_dependencies = {
   'luacov',
   'luamacro >= 2.5.1',
   'optparse >= 3',
   'std._debug >= 1.2',
   'std.functional >= 2.1',
   'std.normalize >= 5.0.1',
   'std.prototype >= 2.1',
   'typecheck >= 4',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}
