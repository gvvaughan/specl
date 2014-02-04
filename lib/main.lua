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

local loader = require "specl.loader"
local runner = require "specl.runner"
local std    = require "specl.std"
local util   = require "specl.util"

local have_color = pcall (require, "ansicolors")


-- Make a shallow copy of the pristine global environment, so that the
-- state of the Specl Lua environment is not exposed to spec files.
local sandbox = {}
for k, v in pairs (_G) do sandbox[k] = v end


-- Parse command line options.
local OptionParser = require "specl.optparse"

local parser = OptionParser [[
specl (@PACKAGE_NAME@) @VERSION@
Written by Gary V. Vaughan <gary@gnu.org>, 2013

Copyright (C) 2013, Gary V. Vaughan
@PACKAGE_NAME@ comes with ABSOLUTELY NO WARRANTY.
You may redistribute copies of @PACKAGE_NAME@ under the terms of the GNU
General Public License; either version 3, or any later version.
For more information, see <http://www.gnu.org/licenses>.

Usage: specl [OPTION]... [FILE]...

Behaviour Driven Development for Lua.

Develop and run BDD specs written in Lua for RSpec style workflow, by
verifying specification expectations read from given FILEs or standard
input, and reporting the results on standard output.

If no FILE is listed, then run specifications for all files from the
'specs/' directory with names ending in '.yaml'.

Where '-' is given as a FILE, then read from standard input.

      --help            print this help, then exit
      --version         print version number, then exit
      --color=WHEN      request colorized formatter output [default=yes]
  -f, --formatter=FILE  use a specific formatter [default=progress]
      --unicode         allow unicode in spec files
  -v, --verbose         request verbose formatter output

Filtering:

  +NN                   check only the example at line NN in next FILE
  FILE:NN[:MM]          check only the example at line NN in this FILE

You can specify +NN (where NN is a line number) multiple times for the
next specified FILE, or interspersed to specify different line filters
for different FILEs. Specifying any number of +NN will prevent all
specifications in that file except those selected by a +NN filter from
being checked. If +NN is not the first line of an example (as would be
displayed by a failing example in verbose mode), the option selects no
examples.

The alternative FILE:NN:MM syntax makes it easy to cut and paste from
Specl failure output, but allows only a single line NN to be filtered
(except when combined with +NN filters).  The optional :MM suffix is
ignored -- and merely represents the ordinal number of an `expect`
statement in a particular example in verbose Specl formatter outputs.

Due to a shortcoming in libYAML, unicode characters in any passed FILE
prevent Specl from working. The '--unicode' option works around that
shortcoming, but any error messages caused by Lua code in FILE will
usually report line-numbers incorrectly.  By default, errors report
accurate line-numbers, and unicode characters are not supported.

Report bugs to @PACKAGE_BUGREPORT@.]]

parser:on ("color", parser.required, parser.boolean)
parser:on ({"f", "format", "formatter"}, parser.required,
           function (parser, opt, optarg)
             local ok, formatter = pcall (require, optarg)
	     if not ok then
	       ok, formatter = pcall (require, "specl.formatter." ..optarg)
	     end
	     if not ok then
	       parser:opterr ("could not load '" .. optarg .. "' formatter.")
	     end
	     return formatter
           end)

_G.arg, opts = parser:parse (_G.arg)

-- Option defaults.
if not have_color then
  opts.color = nil
elseif opts.color == nil then
  opts.color = true
end

if #_G.arg == 0 then
  _G.arg = util.map (function (f) return f:match "_spec%.yaml$" and f or nil end,
                     util.files "specs")
end

if #_G.arg == 0 then
  if pcall (require, "posix") then
    return parser:opterr "could not find spec files in './specs/'"
  else
    return parser:opterr "install luaposix to autoload spec files from './specs/'"
  end
end


-- Collect compiles specs here.
local specs = {}

-- Accumulate line filters (+NN/:NN args) here.
local filters


-- Process files and line filters specified on the command-line.
local function process_args (fn)
  for i, v in ipairs (arg) do
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

    -- Store filters.
    if line ~= nil then
      filters = filters or {}
      filters[line] = true
    end

    -- Process filename.
    if filename == "-" then
      io.input (io.stdin)
      fn (filename, i)

    elseif filename ~= nil then
      io.input (filename)
      fn (filename, i)
    end
  end
end


-- Called by process_args() to concatenate YAML formatted
-- specifications in each <arg>
local function compile (arg)
  local s, errmsg = std.string.slurp ()
  if errmsg ~= nil then
    io.stderr:write (errmsg .. "\n")
    os.exit (1)
  end
  specs[#specs + 1] = {
    filename = arg,
    examples = loader.load (arg, s),
    filters  = filters,
  }
  filters = nil
end


process_args (compile)

os.exit (runner.run (specs, sandbox))
