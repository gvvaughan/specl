-- Lua stdlib, with a few bits missing.
--
-- Copyright (c) 2013 Free Software Foundation, Inc.
-- Written by Gary V. Vaughan, 2013
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

local prog = require "specl.version"

prog.version = prog.program .. " " .. prog.VERSION .. [[

Written by Gary V. Vaughan <gary@gnu.org>, 2013

]] ..  prog.COPYRIGHT_NOTICE

prog.usage   = "Usage: " .. prog.name .. [[ [OPTION]... [FILE]...

Behaviour Driven Development for Lua.

Develop and run BDD specs written in Lua for RSpec style workflow, by
verifying specification expectations read from given FILEs or standard
input, and reporting the results on standard output.

If no FILE is listed, or where '-' is given as a FILE, then read from
standard input.

      --help           print this help, then exit
      --version        print version number, then exit
  -v, --verbose        output using verbose 'report' formatter
      --formatter=FILE use a custom formatter from FILE

]] .. prog.BUGREPORT_NOTICE


local function warn (msg)
  io.stderr:write (prog.name .. ": error: " .. msg .. ".\n")
  io.stderr:write (prog.name .. ": Try '" .. prog.name .. " --help' for help.\n")
  return 2
end


local function process_args ()
  local opts = {}
  local nonopts = nil
  local status = 0
  for _, opt in ipairs (arg) do
    -- Collect non-option arguments to save back into _G.arg later.
    if type (nonopts) == "table" then
      table.insert (nonopts, opt)

    -- Display help message and exit.
    elseif opt == "--help" then
      print (prog.usage)
      os.exit (0)

    -- Display version information and exit.
    elseif opt == "--version" then
      print (prog.version)
      os.exit (0)

    -- Use verbose 'report' formatter.
    elseif opt == "-v" or opt == "--verbose" then
      opts.formatter = opts.formatter or require "specl.formatter.report"

    -- Try to load and use a custom --formatter argument.
    elseif string.sub (opt, 1, 11) == "--formatter" then
      local x = string.find (opt, "=", 1, true)
      if x then
        local ok, formatter = pcall (require, string.sub (opt, x + 1))
	if ok == false then
	  status = warn ("could not load formatter: " .. formatter)
	else
          opts.formatter = formatter
	end
      else
        status = warn "option '--formatter' requires an argument"
      end

    -- End of option arguments.
    elseif opt == "--" then
      nonopts = {}

    -- Diagnose unknown command line options.
    elseif opt ~= "-" and string.sub (opt, 1, 1) == "-" then
      status = warn ("unrecognized option '" .. opt .. "'")

    -- First non-option argument marks the end of options.
    else
      nonopts = { opt }
    end
  end

  if status ~= 0 then os.exit (status) end

  -- put non-option args back into global arg table.
  nonopts = nonopts or {}
  nonopts[0] = arg[0]
  _G.arg = nonopts

  return opts
end


local function process_files (fn)
  if #arg == 0 then
    table.insert (arg,  "-")
  end
  for i, v in ipairs (arg) do
    if v == "-" then
      io.input (io.stdin)
    else
      io.input (v)
    end
    fn (v, i)
  end
end


local function slurp (h)
  if h == nil then
    h = io.input ()
  elseif type (h) == "string" then
    h = io.open (h)
  end
  if h then
    local s = h:read ("*a")
    h:close ()
    return s
  end
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  process_args  = process_args,
  process_files = process_files,
  slurp         = slurp,
  warn          = warn,
}

return M
