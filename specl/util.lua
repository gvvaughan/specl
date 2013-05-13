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
local std   = require "specl.std"


local Object = std.Object {_init = {"type"}, type = "object"}

local function typeof (object)
  if type (object) == "table" and object.type ~= nil then
    return object.type
  end
  return type (object)
end


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


local function concat (alternatives, quoted)
  if quoted then
    alternatives = map (function (v)
                          if typeof (v) ~= "string" then
                            return std.tostring (v)
                          else
                            return ("%q"):format (v)
                          end
                        end, alternatives)
  end

  return table.concat (alternatives, ", "):gsub (",( [^,]+)$", " or%1")
end


-- Write a function call type error similar to how Lua core does it.
local function type_error (name, i, arglist, typelist)
  local expected = typelist[i]
  local actual = "no value"

  if arglist[i] then actual = typeof (arglist[i]) end

  if typelist[i] == "#table" then
    error ("bad argument #" .. tostring (i) .. " to '" .. name ..
           "' (non-empty table expected, got {})", 3)
  elseif typeof (typelist[i]) == "table" then
    -- format as, eg: "number, string or table"
    expected = concat (typelist[i])
  end

  error ("bad argument #" .. tostring (i) .. " to '" .. name .. "' (" ..
         expected .. " expected, got " .. actual .. ")", 3)
end


-- Check that every parameter in <arglist> matches one of the types
-- from the corresponding slot in <typelist>. Raise a parameter type
-- error if there are any mismatches.
-- Rather than leave gaps in <typelist> (which breaks ipairs), use
-- the string "any" to accept any type from the corresponding <arglist>
-- slot.
local function type_check (name, arglist, typelist)
  for i, v in ipairs (typelist) do
    if v ~= "any" then
      if typeof (v) ~= "table" then v = {v} end

      if i > #arglist then
        type_error (name, i, arglist, typelist)
      end
      local a = typeof (arglist[i])

      -- check that argument at `i` has one of the types at typelist[i].
      local ok = false
      for _, check in ipairs (v) do
        if check == "#table" then
          if #arglist[i] > 0 and a == "table" then
            ok = true
            break
          end
        elseif a == check then
          ok = true
          break
        end
      end

      if not ok then
        type_error (name, i, arglist, typelist)
      end
    end
  end
end


-- Return an appropriate indent for last element of DESCRIPTIONS.
local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


-- A null operation function.
local function nop () end


-- Color printing.
local function princ (...)
  return print (color (...))
end


-- Return S with the first word and following whitespace stripped,
-- where S contains some whitespace initially (i.e single words are
-- returned unchanged).
local function strip1st (s)
  return s:gsub ("^%s*%w+%s+", "")
end


-- Color writing.
local function writc (...)
  return io.write (color (...))
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  -- Constants
  QUOTED         = true,

  -- Prototypes
  Object         = Object,

  -- Functions
  chomp          = std.chomp,
  concat         = concat,
  indent         = indent,
  nop            = nop,
  map            = map,
  merge          = std.merge,
  escape_pattern = std.escape_pattern,
  prettytostring = std.prettytostring,
  princ          = princ,
  process_files  = std.processFiles,
  slurp          = std.slurp,
  strip1st       = strip1st,
  tostring       = std.tostring,
  type_check     = type_check,
  typeof         = typeof,
  writc          = writc,
}

return M
