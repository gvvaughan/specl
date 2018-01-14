local _MODREV, _SPECREV = 'git', '-1'

package = 'specl'
version = _MODREV .. _SPECREV

description = {
   summary = 'Behaviour Driven Development for Lua',
   detailed = [[
      Develop and run BDD specs written in Lua for RSpec style workflow.
   ]],
   homepage = 'http://gvvaughan.github.io/specl',
   license = 'GPLv3+',
}

source = {
   url = 'http://github.com/gvvaughan/specl/archive/v' .. _MODREV .. '.zip',
   dir = 'specl-' .. _MODREV,
}

dependencies = {
   'luamacro >= 2.5.1',
   'lua >= 5.1, < 5.4',
   'lyaml >= 5',
   'optparse',
   'stdlib >= 41.2.0, < 42.0.0',
}

build = {
   type = 'builtin',
   install = {
      bin = {
         specl = 'bin/specl',
      }
   },
   modules = {
      ['specl.badargs']            = 'lib/specl/badargs.lua',
      ['specl.color']              = 'lib/specl/color.lua',
      ['specl.compat']             = 'lib/specl/compat.lua',
      ['specl.expect']             = 'lib/specl/expect.lua',
      ['specl.formatter.progress'] = 'lib/specl/formatter/progress.lua',
      ['specl.formatter.report']   = 'lib/specl/formatter/report.lua',
      ['specl.formatter.tap']      = 'lib/specl/formatter/tap.lua',
      ['specl.inprocess']          = 'lib/specl/inprocess.lua',
      ['specl.loader']             = 'lib/specl/loader.lua',
      ['specl.main']               = 'lib/specl/main.lua',
      ['specl.matchers']           = 'lib/specl/matchers.lua',
      ['specl.runner']             = 'lib/specl/runner.lua',
      ['specl.sandbox']            = 'lib/specl/sandbox.lua',
      ['specl.shell']              = 'lib/specl/shell.lua',
      ['specl.std']                = 'lib/specl/std.lua',
      ['specl.util']               = 'lib/specl/util.lua',
      ['specl.version']            = 'lib/specl/version.lua',
   }
}

if _MODREV == 'git' then
   dependencies[#dependencies + 1] = 'ldoc'

   source = {
      url = 'git://github.com/gvvaughan/specl.git',
   }

   build.modules['specl.version'] = 'lib/specl/version-git.lua'
end

