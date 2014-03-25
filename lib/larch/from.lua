-- Luamacro implementation of "from table import foo, bar, baz"
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


local macro = require "macro"

-- Call FN with each element of list L.  Return concatenated string
-- of all elements, separated by ", ".
local function mapconcat (fn, l)
  local t = {}
  for i, e in ipairs (l) do
    t[i] = fn (e)
  end
  return table.concat (t, ", ")
end

local function lastelement (dot_delimited)
  return dot_delimited:match "([^%.]+)$"
end

-- Define from syntax as a LuaMacro macro.
macro.define ('from', function (get)
  local type, preamble, prefix = get:peek (1), ""

  if type == "iden" then
    prefix = get:name () .. "."
    while get:peek (1) == "." do
      get ()
      prefix = prefix .. get:name () .. "."
    end
  elseif type == "string" then
    local name = get:string ()
    local suffix = lastelement (name)
    preamble = "local " .. suffix .. ' = require "' .. name .. '"\n'
    prefix = suffix .. "."
  else
    -- Not followed by an identifier, pass through.
    return nil, true
  end

  local args = {}
  repeat
    if #args == 0 then
      get:expecting ("iden", "import")
    else
      get:expecting ","
    end
    args[#args + 1] = get:name ()
    while get:peek (1) == "." do
      get ()
      args[#args] = args[#args] .. "." .. get:name ()
    end
  until get:peek (1) ~= ","

  return preamble .. "local " .. mapconcat (lastelement, args) .. " = " ..
         mapconcat (function (name) return prefix .. name end, args)
end)
