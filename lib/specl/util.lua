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

from std import Object

local have_posix, posix = pcall (require, "posix")

-- Use higher resolution timers from luaposix if available.
local function gettimeofday ()
  if not (have_posix and posix.timersub) then
    return os.time ()
  end
  return posix.gettimeofday ()
end

local function timesince (earlier)
  if not (have_posix and posix.timersub) then
    return os.time () - earlier
  end
  local elapsed = posix.timersub (posix.gettimeofday (), earlier)
  return (elapsed.usec / 1000000) + elapsed.sec
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


-- Concatenate elements of table ALTERNATIVES much like `table.concat`
-- except the separator is always ", ".  If INFIX is provided, the
-- final separotor uses that instead of ", ".  If QUOTED is not nil or
-- false, then any elements of ALTERNATIVES with type "string" will be
-- quoted using `string.format ("%q")` before concatenation.
local function concat (alternatives, infix, quoted)
  infix = infix or ", "

  if quoted then
    alternatives = map (function (v)
                          if Object.type (v) ~= "string" then
                            return std.string.tostring (v)
                          else
                            return ("%q"):format (v)
                          end
                        end, alternatives)
  end

  return table.concat (alternatives, ", "):gsub (", ([^,]+)$", infix .. "%1")
end


-- Simplified Object.type, that just returns "object" for non-primitive
-- types, or else the primitive type name.
local function xtype (x)
  if type (x) == "table" and Object.type (x) ~= "table" then
    return "object"
  end
  return type (x)
end


-- Write a function call type error similar to how Lua core does it.
local function type_error (name, i, arglist, typelist)
  local actual = "no value"
  if arglist[i] then actual = Object.type (arglist[i]) end

  local expected = typelist[i]
  if Object.type (expected) ~= "table" then expected = {expected} end
  expected = concat (expected, " or "):gsub ("#table", "non-empty table")

  error ("bad argument #" .. tostring (i) .. " to '" .. name .. "' (" ..
         expected .. " expected, got " .. actual .. ")", 3)
end


-- Check that every parameter in <arglist> matches one of the types
-- from the corresponding slot in <typelist>. Raise a parameter type
-- error if there are any mismatches.
-- There are a few additional strings you can use in <typelist> to
-- match special types in <arglist>:
--
--   #table    accept any non-empty table
--   object    accept any std.Object derived type
--   any       accept any type
local function type_check (name, arglist, typelist)
  for i, v in ipairs (typelist) do
    if v ~= "any" then
      if Object.type (v) ~= "table" then v = {v} end

      if i > #arglist then
        type_error (name, i, arglist, typelist)
      end
      local a = Object.type (arglist[i])

      -- check that argument at `i` has one of the types at typelist[i].
      local ok = false
      for _, check in ipairs (v) do
        if check == "#table" then
          if a == "table" and #arglist[i] > 0 then
            ok = true
            break
          end

        elseif check == "object" then
          if type (arglist[i]) == "table" and Object.type (arglist[i]) ~= "table" then
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

  -- Functions
  concat         = concat,
  gettimeofday   = gettimeofday,
  indent         = indent,
  nop            = nop,
  map            = map,
  princ          = princ,
  strip1st       = strip1st,
  timesince      = timesince,
  type           = xtype,
  type_check     = type_check,
  writc          = writc,
}

return M
