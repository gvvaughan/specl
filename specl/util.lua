-- Formatter utility functions.
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


-- Return S with the first word and following whitespace stripped.
local function strip1st (s)
  return s:gsub ("%w+%s*", "", 1)
end


-- Return an appropriate indent for last element of DESCRIPTIONS.
local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


-- A null operation function.
local function nop () end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  map      = map,
  strip1st = strip1st,
  indent   = indent,
  nop      = nop,
}

return M
