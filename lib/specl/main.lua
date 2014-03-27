-- Specification testing framework.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2014 Gary V. Vaughan
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

local loader  = require "specl.loader"
local runner  = require "specl.runner"

from "specl.std"  import Object, table.clone, table.merge
from "specl.util" import files, gettimeofday, map


-- Make a shallow copy of the pristine global environment, so that the
-- future state of the Specl environment is not exposed to spec files.
local global = {}
for k, v in pairs (_G) do global[k] = v end


local optspec = [[
specl (@PACKAGE_NAME@) @VERSION@
Written by Gary V. Vaughan <gary@gnu.org>, 2013

Copyright (C) 2013, Gary V. Vaughan
@PACKAGE_NAME@ comes with ABSOLUTELY NO WARRANTY.
You may redistribute copies of @PACKAGE_NAME@ under the terms of the GNU
General Public License; either version 3, or any later version.
For more information, see <http://www.gnu.org/licenses>.

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

Report bugs to @PACKAGE_BUGREPORT@.]]


-- optparse opt handler for `-f, --formatter=FILE`.
local function formatter_opthandler (parser, opt, optarg)
  local ok, formatter = pcall (require, optarg)
  if not ok then
    ok, formatter = pcall (require, "specl.formatter." ..optarg)
  end
  if not ok then
    parser:opterr ("could not load '" .. optarg .. "' formatter.")
  end
  return formatter
end


-- Return `filename` if it has a specfile-like filename, else nil.
local function specfilter (filename)
  return filename:match "_spec%.yaml$" and filename or nil
end


-- Called by process_args() to concatenate YAML formatted
-- specifications in each <arg>
local function compile (self, arg)
  local s, errmsg = std.string.slurp ()
  if errmsg ~= nil then
    io.stderr:write (errmsg .. "\n")
    os.exit (1)
  end

  -- Add example opts to each spec file to simplify filtering later.
  if self.opts.example ~= nil then
    self.filters = merge (self.filters or {}, {inclusive = self.opts.example})
  end

  table.insert (self.specs, {
    filename = arg,
    examples = loader.load (arg, s, self.opts.unicode),
    filters  = self.filters,
  })

  -- Line filters have been claimed.
  self.filters = nil
end


-- Process files and line filters specified on the command-line.
local function process_args (self, parser)
  if #self.arg == 0 then
    if pcall (require, "posix") then
      return parser:opterr "could not find spec files in './specs/'"
    else
      return parser:opterr "install luaposix to autoload spec files from './specs/'"
    end
  end

  for i, v in ipairs (self.arg) do
    -- Process line filters.
    local filename, line = nil, v:match "^%+(%d+)$"  -- +NN
    if line == nil then
      filename, line = v:match "^(.*):(%d+):%d+"     -- file:NN:MM
    end
    if line == nil then
      filename, line = v:match "^(.*):(%d+)$"        -- file:NN
    end

    -- Fallback to simple `filename`.
    if line == nil then
      filename = v
    end

    -- Accumulate unclaimed filters in the Main object.
    if line ~= nil then
      self.filters = self.filters or {}
      self.filters[line] = true
    end

    -- Process filename.
    if filename == "-" then
      io.input (io.stdin)
      self:compile (filename)

    elseif filename ~= nil then
      h = io.open (filename)
      if h == nil and v:match "^-" then
        return parser:opterr ("unrecognised option '" .. v .. "'")
      end
      io.input (h)
      self:compile (filename)
    end
  end
end


-- Execute this program.
local function execute (self)
  -- Parse command line options.
  local parser = require "specl.optparse" (optspec)

  parser:on ("color", parser.required, parser.boolean)
  parser:on ({"f", "format", "formatter"},
             parser.required, formatter_opthandler)

  self.arg, self.opts = parser:parse (self.arg, self.opts)

  -- When opt.example is non-nil, it must be a table.
  if self.opts.example and type (self.opts.example) ~= "table" then
    self.opts.example = { self.opts.example }
  end

  -- Process all specfiles when none are given explicitly.
  if #self.arg == 0 then
    self.arg = map (specfilter, files "specs")
  end

  self:process_args (parser)

  os.exit (runner.run (self))
end


return Object {
  _type   = "Main",

  inprocess = _G,

  -- Methods.
  __index = {
    compile      = compile,
    execute      = execute,
    process_args = process_args,
  },

  -- Allow test harness to hijack io and os functions so that it can be
  -- safely executed in-process.
  _init = function (self, arg, env)
    self.arg     = arg

    -- Option defaults.
    self.opts    = {
      color      = true,
      formatter  = require "specl.formatter.progress",
    }

    -- Collect compiled specs here.
    self.specs   = {}

    -- Outermost execution environment.
    self.sandbox = merge (clone (global), env or {})

    -- Expectation statistics.
    self.stats = {
      pass = 0, pend = 0, fail = 0, starttime = gettimeofday ()
    }

    return self
  end,
}
