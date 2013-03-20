-- Miscellaneous utility functions.
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


local color = require "specl.color"
local prog  = require "specl.version"
local std   = require "specl.std"


-- Return an appropriate indent for last element of DESCRIPTIONS.
local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


-- A null operation function.
local function nop () end


-- Map function F over elements of T and return a table of results.
local function map (f, t)
  local r = {}
  for _, v in pairs (t) do
    local o = f (v)
    if o then
      table.insert (r, o)
    end
  end
  return r
end


-- Color printing.
local function princ (...)
  return print (color (...))
end


-- Print an argument processing error message, and return non-zero exit status.
local function warn (msg)
  io.stderr:write (prog.name .. ": error: " .. msg .. ".\n")
  io.stderr:write (prog.name .. ": Try '" .. prog.name .. " --help' for help.\n")
  return 2
end


-- Process command line options.
local function process_args ()
  local nonopts = nil
  local status = 0
  for _, opt in ipairs (arg) do
    local x, arg
    if opt:sub (2, 2) == "-" then
      x = opt:find ("=", 1, true)
      if x then
        arg = opt:sub (x + 1)
        opt = opt:sub (1, x -1)
      end
    elseif opt:sub (1, 1) == "-" and string.len (opt) > 2 then
      arg = opt:sub (3)
      opt = opt:sub (1,2)
    end

    -- Collect non-option arguments to save back into _G.arg later.
    if type (nonopts) == "table" then
      table.insert (nonopts, opt)

    -- Run user supplied option handler.
    elseif opt:sub (1, 1) == "-" and type (prog[opt]) == "function" then
      local result, key = prog[opt] (opt, arg)
      if result == nil then
        status = warn (key)
      else
        prog.opts [key or opt:gsub ("^%-*", "", 1)] = result
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

  return prog.opts
end


-- Return S with the first word and following whitespace stripped.
local function strip1st (s)
  return s:gsub ("%w+%s*", "", 1)
end


-- Color writing.
local function writc (...)
  return io.write (color (...))
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  indent        = indent,
  nop           = nop,
  map           = map,
  princ         = princ,
  process_args  = process_args,
  process_files = std.processFiles,
  slurp         = std.slurp,
  strip1st      = strip1st,
  tostring      = std.tostring,
  warn          = warn,
  writc         = writc,
}

return M
