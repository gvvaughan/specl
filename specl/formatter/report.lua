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


local util  = require "specl.util"

local indent, map, nop, princ, strip1st =
      util.indent, util.map, util.nop, util.princ, util.strip1st


local colormap = {
  describe = "%{blue}",
  context  = "%{cyan}",
  when     = "%{cyan}",
}


local function tabulate (descriptions)
  local t   = {}
  local s   = descriptions[#descriptions]
  local key = s:gsub ("%s*(.-)%s+.*$", "%1")

  if #descriptions > 1 then
    table.insert (t, "%{yellow}-%{reset} ")
  end
  if colormap[key] then
    table.insert (t, colormap[key])
  end
  s = s:gsub ("%w+%s*", "", 1)
  table.insert (t, s)
  if colormap[key] then
    table.insert (t, "%{red}:")
  end
  return t
end


local function spec (descriptions)
  princ (indent (descriptions) .. table.concat (tabulate (descriptions)))
end


-- Diagnose any failed expectations in situ, and return failure messages
-- for display at the end.
local function expectations (status, descriptions)
  local spaces = indent (descriptions)
  local reports = { fail = "", pend = "" }

  if next (status.expectations) then
    -- If we have expectations, display the result of each.
    spec (descriptions)

    for i, expectation in ipairs (status.expectations) do
      if expectation.status == "pending" then
        local pend = "  %{yellow}PENDING expectation " ..
	             i .. "%{reset}: %{bright}Not Yet Implemented"

        princ (spaces .. pend)
	reports.pend = reports.pend .. "\n" .. pend

      elseif expectation.status == false then
        local fail = "  %{bright white redbg}FAILED expectation " ..
		     i .. "%{reset}: %{bright}" ..  expectation.message

        princ (spaces .. fail:gsub ("\n", "%0  " .. spaces))
        reports.fail = reports.fail .. "\n" .. fail:gsub ("\n", "%0  ")
      end
    end

  elseif status.ispending then
    -- Otherwise, display only pending examples.
    local pend = " (%{yellow}PENDING example%{reset}: " ..
		   "%{bright}Not Yet Implemented%{reset})"
    princ (spaces ..  table.concat (tabulate (descriptions)) ..  pend)
    reports.pend = reports.pend .. pend
  end

  -- Add description titles.
  if reports.pend ~= "" then
    reports.pend = "%{yellow}-%{reset} %{cyan}" ..
                   table.concat (map (strip1st, descriptions), " ") ..
		   "%{red}:%{reset}" .. reports.pend .. "\n"
  end
  if reports.fail ~= "" then
    reports.fail = "%{yellow}-%{reset} %{cyan}" ..
                   table.concat (map (strip1st, descriptions), " ") ..
                   "%{red}:%{reset}" .. reports.fail .. "\n"
  end

  return reports
end


-- Report statistics.
local function footer (stats, reports)
  local total   = stats.pass + stats.fail
  local percent = 100 * stats.pass / total
  local failcolor = (stats.fail > 0) and "%{bright white redbg}" or "%{green}"

  print ()
  if opts.verbose then
    if reports.pend ~= "" then
      princ "%{blue}Summary of pending expectations%{red}:"
      princ (reports.pend)
    end
    if reports.fail ~= "" then
      princ "%{blue}Summary of failed expectations%{red}:"
      princ (reports.fail)
    end
  end
  princ (string.format ("Met %%{bright}%.2f%%%%{reset} of %d expectations.", percent, total))
  princ ("%{green}" .. stats.pass .. " passed%{reset}, " ..
         "%{yellow}" .. stats.pend .. " pending%{reset} and " ..
         failcolor .. stats.fail .. " failed%{reset} in " ..
	 (os.clock () - stats.starttime) .. " seconds.")
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  header       = nop,
  spec         = spec,
  expectations = expectations,
  footer       = footer,
}

return M
