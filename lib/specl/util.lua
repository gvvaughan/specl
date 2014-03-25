-- Miscellaneous utility functions.
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


from "specl.std" import Object

local have_posix, posix = pcall (require, "posix")


local files -- forward declaration

if have_posix then

  files = function (root)
    local t = {}
    for _, file in ipairs (posix.dir (root) or {}) do
      if file ~= "." and file ~= ".." then
        local path = std.io.catfile (root, file)
        if posix.stat (path).type == "directory" then
          t = std.table.merge (t, files (path))
        else
          t[#t + 1] = path
        end
      end
    end
    return t
  end

else

  files = function () return {} end

end


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


-- Return a complete copy of T, along with copied metatables.
local function deepcopy (t)
  local copied = {} -- references to tables already copied

  local function makecopy (orig)
    local copy
    if type (orig) ~= "table" then
      copy = orig
    elseif copied[orig] then
      copy = copied[orig]
    else
      copied[orig] = {}
      for k, v in next, orig, nil do  -- don't trigger __pairs metamethod
        rawset (copied[orig], makecopy (k), makecopy (v))
      end
      setmetatable (copied[orig], makecopy (getmetatable (orig)))
      copy = copied[orig]
    end
    return copy
  end

  return makecopy (t)
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

  if quoted ~= nil then
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

  error ("bad argument #" .. tostring (i) .. " to '" .. name ..
         "' (" .. expected .. " expected, got " .. actual .. ")\n" ..
	 "received: '" .. tostring (arglist[i]) .. "'", 3)
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


-- Return S with the first word and following whitespace stripped,
-- where S contains some whitespace initially (i.e single words are
-- returned unchanged).
local function strip1st (s)
  return s:gsub ("^%s*%w+%s+", "")
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  -- Functions
  concat         = concat,
  deepcopy       = deepcopy,
  files          = files,
  gettimeofday   = gettimeofday,
  indent         = indent,
  nop            = nop,
  map            = map,
  strip1st       = strip1st,
  timesince      = timesince,
  type           = xtype,
  type_check     = type_check,
}

return M
