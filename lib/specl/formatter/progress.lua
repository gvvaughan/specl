-- Short progress-bar style expectation formatter.
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


local color = require "specl.color"
local std   = require "specl.std"
local util  = require "specl.util"

local empty = std.table.empty
local examplename, nop, timesince =
  util.examplename, util.nop, util.timesince


-- Color writing.
local function writc (want_color, ...)
  io.stdout:write (color (want_color, ...))
  io.stdout:flush ()
end


-- Color printing.
local function princ (want_color, ...)
  return print (color (want_color, ...))
end


local function format_failing_expectation (status, i, exp, verbose)
  local fail = "  "
  if verbose then
    fail = fail ..
      color.strong .. status.filename .. ":" .. status.line .. ":" ..
      i .. ": " .. color.reset .. color.fail .. "FAILED expectation " ..
      i .. color.reset .. ":\n" .. exp.message
  else
    fail = fail ..
      color.fail .. "FAILED expectation " .. i .. color.reset .. ": " ..
      exp.message
  end

  return "\n" .. fail:gsub ("\n", "%0  ")
end


local function format_pending_expectation (status, i, exp, verbose)
  local pend = "\n  "
  if verbose then
    pend = pend ..
      color.strong .. status.filename .. ":" .. status.line .. ":" ..
      i .. ": " .. color.reset
  end
  pend = pend ..
    color.pend .. "PENDING expectation " .. i .. color.reset .. ": " ..
    color.warn .. exp.pending .. color.reset

  if exp.status == true then
    pend = pend ..
      color.warn .. ", passed unexpectedly!" .. color.reset .. "\n" ..
      "  " .. color.strong ..
      "You can safely remove the 'pending ()' call from this example." ..
      color.reset
  end

  return pend
end


local function format_pending_example (message)
  return " (" .. color.pend .. "PENDING example" .. color.reset ..
    ": " .. message .. ")"
end


-- Print '.' for passed, 'F' for failed or '*' for pending expectations.
-- Accumulate pending and failure reports for display in footer.
local function display_progress (status, descriptions, opts)
  local reports = { fail = "", pend = "" }

  if empty (status.expectations) then
    if status.ispending then
      reports.pend = reports.pend .. format_pending_example (status.ispending)
      writc (opts.color, color.pend .. "*")
    end
  else
    for i, exp in ipairs (status.expectations) do
      if exp.pending ~= nil then
	reports.pend = reports.pend ..
	  format_pending_expectation (status, i, exp, opts.verbose)
        writc (opts.color,
	  (exp.status == true) and (color.strong .. "?") or (color.pend .. "*"))
      elseif exp.status == false then
	reports.fail = reports.fail ..
	  format_failing_expectation (status, i, exp, opts.verbose)
        writc (opts.color, color.bad .. "F")
      else
        writc (opts.color, color.good .. ".")
      end
    end
  end

  -- Add description titles.
  local title = examplename (descriptions)
  title = color.listpre .. color.subhead .. title .. color.listpost
  if reports.pend ~= "" then
    reports.pend = title .. reports.pend .. "\n"
  end
  if reports.fail ~= "" then
    reports.fail = title .. reports.fail .. "\n"
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
  expectations = display_progress,
  footer       = footer,
}

return M
