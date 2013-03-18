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


local color = require "specl.color"


local colormap = {
  describe = "%{blue}",
  context  = "%{cyan}",
  when     = "%{cyan}",
}


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


local function indent (descriptions)
  return string.rep ("  ", #descriptions - 1)
end


local function header () end


local function spec (descriptions)
  local s    = descriptions[#descriptions]
  local key  = s:gsub ("%s*(.-)%s+.*$", "%1")
  local pre  = (#descriptions > 1) and "%{yellow}-%{reset} " or ""
  local post = colormap[key] and "%{red}:" or ""
  print (color (indent (descriptions) .. pre ..
                (colormap[key] or "") .. s:gsub ("%w+%s*", "", 1) .. post))
end


local function example (descriptions)
  spec (descriptions)
end


-- Diagnose any failed expectations in situ, and return failure messages
-- for display at the end.
local function expectations (expectations, descriptions)
  local spaces = indent (descriptions)
  local failreports = ""

  for i, expectation in ipairs (expectations) do
    if expectation.status ~= true then
      local fail = "  %{bright white redbg}FAILED expectation " ..
		   i .. "%{reset}: %{bright}" ..  expectation.message

      print (color (spaces .. fail:gsub ("\n", "%0  " .. spaces)))
      failreports = failreports .. "\n" .. fail:gsub ("\n", "%0  ") .. "\n"
    end
  end

  if failreports ~= "" then
    failreports = "%{yellow}-%{reset} %{cyan}" ..
                  table.concat (map (strip1st, descriptions), " ") ..
                  "%{red}:%{reset}" .. failreports
  end

  return failreports
end


-- Report statistics.
local function footer (stats, failreports)
  local total   = stats.pass + stats.fail
  local percent = 100 * stats.pass / total
  local failcolor = (stats.fail > 0) and "%{bright white redbg}" or "%{green}"

  print ()
  if failreports ~= "" then
    print (color ("%{red}Summary of failed expectations:"))
    print (color (failreports))
  end
  print (color (string.format ("Met %%{bright}%.2f%%%%{reset} of %d expectations.", percent, total)))
  print (color ("%{green}" .. stats.pass .. " passed%{reset}, and " ..
                failcolor .. stats.fail .. " failed%{reset} in " ..
	        (os.clock () - stats.starttime) .. " seconds."))
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  name         = "report",
  header       = header,
  spec         = spec,
  example      = example,
  expectations = expectations,
  footer       = footer,
}

return M
