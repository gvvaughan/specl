--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2014-2023 Gary V. Vaughan
]]

return {
  PACKAGE = 'specl',
  PACKAGE_NAME = 'Specl',
  PACKAGE_BUGREPORT = 'https://github.com/gvvaughan/specl/issues',
  VERSION = 'git',
  optspec = [[
specl (Specl) git
Written by Gary V. Vaughan <gary@gnu.org>, 2013

Copyright (C) 2023, Gary V. Vaughan
Specl comes with ABSOLUTELY NO WARRANTY.
You may redistribute copies of Specl under the terms of the MIT license;
it may be used for any purpose at absolutely no cost, without permission.
See <https://mit-license.org> for details.

Usage: specl [OPTION]... [FILE]...

Behaviour Driven Development for Lua.

Develop and run BDD specs written in Lua for RSpec style workflow, by verifying
specification expectations read from given FILEs or standard input, and
reporting the results on standard output.

If no FILE is listed, then run specifications for all files from the 'specs/'
directory with names ending in '.yaml'.

Where '-' is given as a FILE, then read from standard input.

      --help             print this help, then exit
      --version          print version number, then exit
      --color=WHEN       request colorized formatter output [default=yes]
      --coverage         generate coverage report, if luacov is installed
  -1, --fail-fast        exit immediately on first failed example
  -f, --formatter=FILE   use a specific formatter [default=progress]
      --unicode          allow unicode in spec files
  -v, --verbose          request verbose formatter output

Filtering:

  -e, --example=PATTERN  check only the examples matching PATTERN
  +NN                    check only the example at line NN in next FILE
  FILE:NN[:MM]           check only the example at line NN in this FILE

When filtering by PATTERN, an example is considered a match if PATTERN matches
the concatenation of nested YAML descriptions leading directly to that example
in its spec file.

You can specify +NN (where NN is a line number) multiple times for the next
specified FILE, or interspersed to specify different line filters for different
FILEs. Specifying any number of +NN will prevent all specifications in that
file except those selected by a +NN filter from being checked. If +NN is not
the first line of an example (as would be displayed by a failing example in
verbose mode), the option selects no examples.

The alternative FILE:NN:MM syntax makes it easy to cut and paste from Specl
failure output, but allows only a single line NN to be filtered (except when
combined with +NN filters).  The optional :MM suffix is ignored -- and merely
represents the ordinal number of an `expect` statement in a particular example
in verbose Specl formatter outputs.

Due to a shortcoming in libYAML, unicode characters in any passed FILE prevent
Specl from working. The '--unicode' option works around that shortcoming, but
any error messages caused by Lua code in FILE will usually report line-numbers
incorrectly.  By default, errors report accurate line-numbers, and unicode
characters are not supported.

Report bugs to https://github.com/gvvaughan/specl/issues.]]
}
