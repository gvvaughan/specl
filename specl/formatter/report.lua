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
local util  = require "specl.util"

local indent, map, nop, princ, strip1st =
      util.indent, util.map, util.nop, util.princ, util.strip1st


local function tabulate (descriptions)
  local t   = {}
  local s   = descriptions[#descriptions]
  local key = s:gsub ("%s*(.-)%s+.*$", "%1")

  if color[key] then
    table.insert (t, color[key])
  end
  s = s:gsub ("%w+%s*", "", 1)
  table.insert (t, s)
  return table.concat (t)
end


local function spec (descriptions)
  princ (indent (descriptions) .. tabulate (descriptions))
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
      if expectation.pending ~= nil then
        local pend = "  " .. color.pend ..
              "PENDING expectation " ..  i .. "%{reset}: "
        if type (expectation.pending) == "string" then
          pend = pend .. color.warn .. expectation.pending .. ", "
        end
	if expectation.status == true then
          pend = pend .. color.warn .. "passed unexpectedly!%{reset}"
          reports.pend = reports.pend .. "\n" .. pend .. "\n" ..
	      "  " .. color.strong ..
	      "You can safely remove the 'pending ()' call from this example.%{reset}"
        else
          pend = pend .. "not yet implemented"
          reports.pend = reports.pend .. "\n" .. pend
	end

        if opts.verbose then
          princ (spaces .. pend)
        end

      elseif expectation.status == false then
        local fail = "  " .. color.fail .. "FAILED expectation " ..
                     i .. "%{reset}: " ..  expectation.message
        reports.fail = reports.fail .. "\n" .. fail:gsub ("\n", "%0  ")

        if opts.verbose then
          princ (spaces .. fail:gsub ("\n", "%0  " .. spaces))
        end
      end
    end

  elseif status.ispending then
    -- Otherwise, display only pending examples.
    local pend = " (" .. color.pend .. "PENDING example%{reset}: " ..
                   "not yet implemented)"
    reports.pend = reports.pend .. pend

    princ (spaces ..  tabulate (descriptions) ..  pend)
  end

  -- Add description titles.
  if reports.pend ~= "" then
    reports.pend = color.listpre .. color.subhead ..
                   table.concat (map (strip1st, descriptions), " ") ..
                   color.listpost .. reports.pend .. "\n"
  end
  if reports.fail ~= "" then
    reports.fail = color.listpre .. color.subhead ..
                   table.concat (map (strip1st, descriptions), " ") ..
                   color.listpost .. reports.fail .. "\n"
  end

  return reports
end


-- Report statistics.
local function footer (stats, reports)
  local total   = stats.pass + stats.fail
  local percent = string.format ("%.2f%%", 100 * stats.pass / total)

  print ()
  if reports and reports.pend ~= "" then
    princ (color.summary .. "Summary of pending expectations" ..
           color.summarypost)
    princ (reports.pend)
  end
  if reports and reports.fail ~= "" then
    princ (color.summary .. "Summary of failed expectations" ..
           color.summarypost)
    princ (reports.fail)
  end

  local statcolor = (percent == "100.00%") and color.allpass or color.notallpass
  princ (statcolor .. "Met " .. percent .. " of " .. tostring (total) ..
         " expectations.")

  local passcolor = (stats.pass > 0) and color.good or color.bad
  local failcolor = (stats.fail > 0) and color.bad or ""
  local pendcolor = (stats.pend > 0) and color.bad or ""
  princ (passcolor   .. stats.pass .. " passed%{reset}, " ..
         pendcolor   .. stats.pend .. " pending%{reset} and " ..
         failcolor   .. stats.fail .. " failed%{reset} in " ..
         color.clock .. (os.time () - stats.starttime) .. " seconds%{reset}.")
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
