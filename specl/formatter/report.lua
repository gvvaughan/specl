-- Long report style expectation formatter.
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


local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


local function header () end


local function spec (descriptions)
  print (indent (descriptions) ..
         descriptions[#descriptions]:gsub ("%w+%s*", "", 1))
end


local function example (descriptions)
  spec (descriptions)
end


-- Diagnose any failed expectations in situ.
local function expectations (expectations, descriptions)
  local spaces = indent (descriptions)

  for i, expectation in ipairs (expectations) do
    if expectation.status ~= true then
      print (spaces .. "- FAILED expectation " .. i .. ": " ..
             expectation.message:gsub ("\n", "%0  " .. spaces))
    end
  end
end


-- Report statistics.
local function footer (stats)
  local total   = stats.pass + stats.fail
  local percent = 100 * stats.pass / total

  print ()
  print (string.format ("Met %.2f%% of %d expectations.", percent, total))
  print (stats.pass .. " passed, and " ..
         stats.fail .. " failed in " ..
	 (os.clock () - stats.starttime) .. " seconds.")
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  header       = header,
  spec         = spec,
  example      = example,
  expectations = expectations,
  footer       = footer,
}

return M
