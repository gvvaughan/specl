-- Long report style expectation formatter.
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


local color = require "specl.color"
local util  = require "specl.util"

from util import indent, map, nop, strip1st, timesince


-- Color printing.
local function princ (want_color, ...)
  return print (color (want_color, ...))
end


local function tabulate (descriptions)
  local t   = {}
  local s   = descriptions[#descriptions]
  local key = s:gsub ("%s*(.-)%s+.*$", "%1")

  if color[key] then
    table.insert (t, color[key])
  end
  s = strip1st (s)
  table.insert (t, s)
  if color[key] then
    table.insert (t, color.reset)
  end
  return table.concat (t)
end


local function spec (descriptions, opts)
  princ (opts.color, indent (descriptions) .. tabulate (descriptions))
end


-- Diagnose any failed expectations in situ, and return failure messages
-- for display at the end.
local function expectations (status, descriptions, opts)
  local spaces  = indent (descriptions)
  local reports = { fail = "", pend = "" }
  local counts  = { fail = 0, pend = 0, unexpected = 0 }

  local fileline = color.strong .. status.filename .. ":" .. status.line .. ":"

  if next (status.expectations) then
    local details = ""

    -- If we have expectations, display the result of each.
    for i, expectation in ipairs (status.expectations) do
      if expectation.pending ~= nil then
        local pend = "  "
	if opts.verbose then
	  pend = pend .. fileline .. i .. ": " .. color.reset
        end
        pend = pend .. color.pend ..
              "PENDING expectation " ..  i .. color.reset .. ": " ..
              color.warn .. expectation.pending

        if expectation.status == true then
          counts.unexpected = counts.unexpected + 1

          if prefix ~= color.fail then prefix = color.warn end

          pend = pend .. color.warn .. " passed unexpectedly!" .. color.reset
          reports.pend = reports.pend .. "\n" .. pend .. "\n" ..
              "  " .. color.strong ..
              "You can safely remove the 'pending ()' call from this example." ..
              color.reset
        else
          counts.pend = counts.pend + 1
          reports.pend = reports.pend .. "\n" .. pend
        end

        if opts.verbose then
          details = details .. "\n" .. spaces .. pend
        end

      elseif expectation.status == false then
        counts.fail = counts.fail + 1

        local fail
	if opts.verbose then
	  fail = "  " .. fileline .. i.. ": " .. color.reset .. color.fail ..
		 "FAILED expectation " .. i .. color.reset .. ":\n" ..
	         expectation.message
	else
          fail = "  " .. color.fail .. "FAILED expectation " .. i ..
	         color.reset .. ": " .. expectation.message
	end

        reports.fail = reports.fail .. "\n" .. fail:gsub ("\n", "%0  ")
        if opts.verbose then
          details = details .. "\n" .. spaces .. fail:gsub ("\n", "%0  " .. spaces)
        end
      end
    end

    -- One line summary of abnormal expectations, for non-verbose report format.
    if not opts.verbose then
      details = {}
      if counts.pend > 0 then
        table.insert (details, color.pend .. tostring (counts.pend) .. " pending")
      end
      if counts.unexpected > 0 then
        table.insert (details, color.warn .. tostring (counts.unexpected) .. " unexpectedly passing")
      end
      if counts.fail > 0 then
        table.insert (details, color.fail .. tostring (counts.fail) .. " failing")
      end
      if next (details) then
        details = " (" .. table.concat (details, color.reset .. ", ") .. color.reset .. ")"
      else
        details = ""
      end
    end

    princ (opts.color, spaces .. tabulate (descriptions) ..details)

  elseif status.ispending then
    -- Otherwise, display only pending examples.
    local pend = " (" .. color.pend .. "PENDING example" .. color.reset ..
                 ": " .. status.ispending .. ")"
    reports.pend = reports.pend .. pend

    princ (opts.color, spaces ..  tabulate (descriptions) ..  pend)
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
local function footer (stats, reports, opts)
  local total   = stats.pass + stats.fail
  local percent = string.format ("%.2f%%", 100 * stats.pass / total)

  print ()
  if reports and reports.pend ~= "" then
    princ (opts.color, color.summary .. "Summary of pending expectations" ..
           color.summarypost)
    princ (opts.color, reports.pend)
  end
  if reports and reports.fail ~= "" then
    princ (opts.color, color.summary .. "Summary of failed expectations" ..
           color.summarypost)
    princ (opts.color, reports.fail)
  end

  if total > 0 then
    local statcolor = (percent == "100.00%") and color.allpass or color.notallpass
    princ (opts.color, statcolor .. "Met " .. percent .. " of " .. tostring (total) ..
           " expectations.")
  else
    princ (opts.color, color.notallpass .. "No expectations met.")
  end

  local passcolor = (stats.pass > 0) and color.good or color.bad
  local failcolor = (stats.fail > 0) and color.bad or ""
  local pendcolor = (stats.pend > 0) and color.bad or ""
  princ (opts.color, passcolor   .. stats.pass .. " passed" .. color.reset .. ", " ..
         pendcolor   .. stats.pend .. " pending" .. color.reset .. " and " ..
         failcolor   .. stats.fail .. " failed%{reset} in " ..
         color.clock .. tostring (timesince (stats.starttime)) ..
         " seconds" .. color.reset .. ".")
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
