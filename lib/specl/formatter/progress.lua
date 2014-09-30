-- Short progress-bar style expectation formatter.
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

local map, nop, strip1st, timesince =
  util.map, util.nop, util.strip1st, util.timesince


-- Color writing.
local function writc (want_color, ...)
  io.stdout:write (color (want_color, ...))
  io.stdout:flush ()
end


-- Color printing.
local function princ (want_color, ...)
  return print (color (want_color, ...))
end


-- Print '.' for passed, or 'F' for failed expectation.
-- Update '>' position.
local function expectations (status, descriptions, opts)
  reports = { fail = "", pend = "" }

  local fileline = color.strong .. status.filename .. ":" .. status.line .. ":"

  if next (status.expectations) then
    -- If we have expectations, display the result of each.
    for i, expectation in ipairs (status.expectations) do
      if expectation.pending ~= nil then
        reports.pend = reports.pend .. "\n  "
	if opts.verbose then
	  reports.pend = reports.pend .. fileline .. i .. ": " .. color.reset
	end
        reports.pend = reports.pend ..
	  color.pend .. "PENDING expectation " ..  i .. color.reset .. ": "

        reports.pend = reports.pend .. color.warn .. expectation.pending

        if expectation.status == true then
          writc (opts.color, color.strong .. "?")
          reports.pend = reports.pend ..
              color.warn .. ", passed unexpectedly!" .. color.reset .. "\n" ..
              "  " .. color.strong ..
              "You can safely remove the 'pending ()' call from this example." ..
              color.reset
        else
          writc (opts.color, color.pend .. "*")
        end

      elseif expectation.status == true then
        writc (opts.color, color.good .. ".")

      else
        writc (opts.color, color.bad .. "F")

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
      end
    end

  elseif status.ispending then
    -- Otherwise, display only pending examples.
    writc (opts.color, color.pend .. "*")
    local pend = " (" .. color.pend .. "PENDING example" .. color.reset ..
                 ": " .. status.ispending .. ")"
    reports.pend = reports.pend .. pend
  end
  io.stdout:flush ()

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
  local total = stats.pass + stats.fail

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

  local passcolor = (stats.pass > 0) and color.good or color.bad
  local failcolor = (stats.fail > 0) and color.bad or ""
  local pendcolor = (stats.pend > 0) and color.bad or ""
  local prefix    = (total > 0) and (color.allpass .. "All") or (color.bad .. "No")

  if stats.fail == 0 then
    writc (opts.color, prefix .. " expectations met" .. color.reset)

    if stats.pend ~= 0 then
      writc (opts.color, ", but " .. color.bad .. stats.pend ..
             " still pending" .. color.reset .. ",")
    end
  else
    writc (opts.color, passcolor .. stats.pass .. " passed" ..
           color.reset .. ", " .. pendcolor .. stats.pend .. " pending" ..
           color.reset .. ", " .. "and " .. failcolor .. stats.fail ..
	   " failed" .. color.reset)
  end
  princ (opts.color, " in " .. color.clock ..
         tostring (timesince (stats.starttime)) ..
         " seconds" .. color.reset .. ".")
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  header       = nop,
  spec         = nop,
  expectations = expectations,
  footer       = footer,
}

return M
