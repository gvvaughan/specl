-- Miscellaneous utility functions.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2015 Gary V. Vaughan
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


local std = require "specl.std"
local have_posix, posix = pcall (require, "posix")

local ielems, map = std.ielems, std.functional.map
local object = std.object


-- A null operation function.
local function nop () end


local files, timersub -- forward declarations

if have_posix then

  files = function (root, t)
    t = t or {}
    for _, file in ipairs (posix.dir (root) or {}) do
      if file ~= "." and file ~= ".." then
        local path = std.io.catfile (root, file)
        if posix.stat (path).type == "directory" then
          t = files (path, t)
        else
          t[#t + 1] = path
        end
      end
    end
    return t
  end

  timersub = posix.sys and posix.sys.timersub or posix.timersub

else

  files = function (root, t)
    return nil, "install luaposix to autoload spec files from '" .. tostring (root) .. "/'"
  end

end


-- Use higher resolution timers from luaposix if available.
local function gettimeofday ()
  if not (have_posix and timersub) then
    return os.time ()
  end
  return posix.gettimeofday ()
end

local function timesince (earlier)
  if not (have_posix and timersub) then
    return os.time () - earlier
  end
  local elapsed = timersub (posix.gettimeofday (), earlier)
  return (elapsed.usec / 1000000) + elapsed.sec
end


-- Return a complete copy of T, along with copied metatables.
local function deepcopy (t)
  local copied = {} -- references to tables already copied

  local function tablecopy (orig)
    local mt = getmetatable (orig)
    local copy = mt and setmetatable ({}, copied[mt] or tablecopy (mt)) or {}
    copied[orig] = copy
    for k, v in next, orig, nil do  -- don't trigger __pairs metamethod
      if type (k) == "table" then k = copied[k] or tablecopy (k) end
      if type (v) == "table" then v = copied[v] or tablecopy (v) end
      rawset (copy, k, v)
    end
    return copy
  end

  return tablecopy (t)
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
                          if object.type (v) ~= "string" then
                            return std.tostring (v)
                          else
                            return ("%q"):format (v)
                          end
                        end, ielems, alternatives)
  end

  return table.concat (alternatives, ", "):gsub (", ([^,]+)$", infix .. "%1")
end


-- Simplified object.type, that just returns "object" for non-primitive
-- types, or else the primitive type name.
local function xtype (x)
  if type (x) == "table" and object.type (x) ~= "table" then
    return "object"
  end
  return type (x)
end


-- Return an appropriate indent for last element of DESCRIPTIONS.
local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


-- Return S with the first word and following whitespace stripped,
-- where S contains some whitespace initially (i.e single words are
-- returned unchanged).
local function strip1st (s)
  return (s:gsub ("^%s*%w+%s+", ""))
end


-- Return elements of DESCRIPTIONS concatenated after removing the
-- first word of each item.
local function examplename (descriptions)
  return table.concat (map (strip1st, ielems, descriptions), " ")
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


-- Don't prevent examples from loading a different luaposix.
for k in pairs (package.loaded) do
  if k == "posix" or k == "posix_c" or k:match "^posix%." then
    package.loaded[k] = nil
  end
end


local M = {
  -- Functions
  concat         = concat,
  deepcopy       = deepcopy,
  examplename    = examplename,
  files          = files,
  gettimeofday   = gettimeofday,
  have_posix     = have_posix,
  indent         = indent,
  nop            = nop,
  strip1st       = strip1st,
  timesince      = timesince,
  type           = xtype,
}

return M
