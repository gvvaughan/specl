-- Short progress-bar style expectation formatter.
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

local map, nop, princ, strip1st, writc =
      util.map, util.nop, util.princ, util.strip1st, util.writc


-- Use '>' as a marker for currently executing expectation.
local function header ()
  io.write (">")
  io.flush ()
end


-- Print '.' for passed, or 'F' for failed expectation.
-- Update '>' position.
local function expectations (status, descriptions)
  reports = { fail = "", pend = "" }

  io.write ("\08")

  if next (status.expectations) then
    -- If we have expectations, display the result of each.
    for i, expectation in ipairs (status.expectations) do
      if expectation.status == "pending" then
        writc "%{yellow}*"
        reports.pend = reports.pend .. "\n  %{yellow}PENDING expectation " ..
                       i .. "%{reset}: %{bright}Not Yet Implemented"

      elseif expectation.status == true then
        writc "%{green}."

      else
        writc "%{bright white redbg}F"

        local fail = "  %{bright white redbg}FAILED expectation " ..
                     i .. "%{reset}: %{bright}" ..  expectation.message
        reports.fail = reports.fail .. "\n" .. fail:gsub ("\n", "%0  ")
      end
    end

  elseif status.ispending then
    -- Otherwise, display only pending examples.
    writc "%{yellow}*"
    reports.pend = reports.pend .. " (%{yellow}PENDING example%{reset}: " ..
                   "%{bright}Not Yet Implemented%{reset})"
  end
  io.write (">")
  io.flush ()

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
  print "\08 "

  print ()
  if reports.pend ~= "" then
    princ "%{blue}Summary of pending expectations%{red}:"
    princ (reports.pend)
  end
  if reports.fail ~= "" then
    princ "%{blue}Summary of failed expectations%{red}:"
    princ (reports.fail)
  end

  if stats.fail == 0 then
    writc "%{bright}All expectations met%{reset} "
    if stats.pend ~= 0 then
      writc ("with %{yellow}" .. stats.pend .. " still pending%{reset}, ")
    end
  else
    writc ("%{green}" .. stats.pass .. " passed%{reset}, " ..
            "%{yellow}" .. stats.pend .. " pending%{reset}, " ..
            "and %{bright white redbg}" ..  stats.fail .. " failed%{reset} ")
  end
  princ ("in %{bright}" ..  (os.clock () - stats.starttime) ..
         " seconds%{reset}.")
end


  
--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  header       = header,
  spec         = nop,
  expectations = expectations,
  footer       = footer,
}

return M
