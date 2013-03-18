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


local color = require "specl.color"


-- Use '>' as a marker for currently executing expectation.
local function header ()
  io.write (">")
  io.flush ()
end


-- Print '.' for passed, or 'F' for failed expectation.
-- Update '>' position.
local function expectations (expectations, descriptions)
  io.write ("\08")
  for i, expectation in ipairs (expectations) do
    if expectation.status == true then
      io.write (color "%{green}.")
    else
      io.write (color "%{bright white redbg}F")
    end
  end
  io.write (">")
  io.flush ()
end


-- Report statistics.
local function footer (stats)
  io.write ("\08 \n")

  if stats.fail == 0 then
    io.write (color "%{bright}All expectations met%{reset}, ")
  else
    io.write (color ("%{green}" .. stats.pass .. " passed%{reset}, " ..
                     "and %{red}" ..  stats.fail .. " failed%{reset} "))
  end
  io.write (color ("in %{bright}" ..  (os.clock () - stats.starttime) ..
                   " seconds%{reset}.\n"))
end


  
--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local function nop (...) end

local M = {
  name         = "progress",
  header       = header,
  spec         = nop,
  example      = nop,
  expectations = expectations,
  footer       = footer,
}

return M
