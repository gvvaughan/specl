-- Luamacro implementation of "from table import foo, bar, baz"
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


local macro = require "macro"

-- Prepend PREFIX to each element of list L.  Return concatenated
-- string of all element, separated by SEP.
local function mapconcat (prefix, l, sep)
  local sep = sep or ""
  local t = {}
  for i, e in ipairs (l) do
    t[i] = prefix .. e
  end
  return table.concat (t, sep)
end

-- Define from syntax as a LuaMacro macro.
macro.define ('from', function (get)
  local prefix = get:name () .. "."
  while get:peek (1) == "." do
    get ()
    prefix = prefix .. get:name () .. "."
  end

  local args = {}
  repeat
    get () -- "import" or ","
    get () -- space
    args[#args + 1] = get:name ()
  until get:peek (1) ~= ","

  return "local "..table.concat (args, ", ").." = " ..
         mapconcat (prefix, args, ", ")
end)
