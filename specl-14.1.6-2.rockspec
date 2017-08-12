local _MODREV, _SPECREV = '14.1.6', '-2'

package = 'specl'
version = _MODREV .. _SPECREV

description = {
  summary = 'Behaviour Driven Development for Lua',
  detailed = 'Develop and run BDD specs written in Lua for RSpec style workflow.',
  homepage = 'http://gvvaughan.github.io/specl',
  license = 'GPLv3+',
}

source = {
  url = 'http://github.com/gvvaughan/specl/archive/release-v' .. _MODREV .. '.zip',
  dir = 'specl-release-v' .. _MODREV,
}

dependencies = {
  'luamacro >= 2.0',
  'lua >= 5.1, < 5.4',
  'lyaml >= 5',
  'optparse',
  'stdlib >= 41.2.0',
}

build = {
  copy_directories = {
    'bin',
    'doc',
  },
  type = 'builtin',
  modules = {
    ['specl.badargs'] = 'lib/specl/badargs.lua',
    ['specl.color'] = 'lib/specl/color.lua',
    ['specl.compat'] = 'lib/specl/compat.lua',
    ['specl.formatter.progress'] = 'lib/specl/formatter/progress.lua',
    ['specl.formatter.report'] = 'lib/specl/formatter/report.lua',
    ['specl.formatter.tap'] = 'lib/specl/formatter/tap.lua',
    ['specl.inprocess'] = 'lib/specl/inprocess.lua',
    ['specl.loader'] = 'lib/specl/loader.lua',
    ['specl.main'] = 'lib/specl/main.lua',
    ['specl.matchers'] = 'lib/specl/matchers.lua',
    ['specl.runner'] = 'lib/specl/runner.lua',
    ['specl.shell'] = 'lib/specl/shell.lua',
    ['specl.std'] = 'lib/specl/std.lua',
    ['specl.util'] = 'lib/specl/util.lua',
    ['specl.version'] = 'lib/specl/version.lua',
  },
}
