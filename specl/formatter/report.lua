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
  local failreports = ""

  if next (status.expectations) then
    spec (descriptions)

    for i, expectation in ipairs (status.expectations) do
      if expectation.status == "pending" then
        princ (spaces .. "  %{yellow}PENDING expectation " ..
	       i .. "%{reset}: %{bright}Not Yet Implemented")

      elseif expectation.status == false then
        local fail = "  %{bright white redbg}FAILED expectation " ..
		     i .. "%{reset}: %{bright}" ..  expectation.message

        princ (spaces .. fail:gsub ("\n", "%0  " .. spaces))
        failreports = failreports .. "\n" .. fail:gsub ("\n", "%0  ") .. "\n"
      end
    end
  elseif status.ispending then
    princ (indent (descriptions) .. table.concat (tabulate (descriptions)) ..
           " (%{yellow}PENDING example%{reset}: %{bright}Not Yet Implemented%{reset})")
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
  if opts.verbose and failreports ~= "" then
    princ "%{blue}Summary of failed expectations%{red}:"
    princ (failreports)
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
  name         = "report",
  header       = nop,
  spec         = spec,
  expectations = expectations,
  footer       = footer,
}

return M
