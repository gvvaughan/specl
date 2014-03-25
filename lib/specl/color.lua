-- Conditional ANSI coloration.
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


local have_color, ansicolors = pcall (require, "ansicolors")

local h1      = "%{bright blue}"
local h2      = "%{blue}"
local h3      = "%{cyan}"
local default = ""
local good    = "%{green}"
local bad     = "%{bright white redbg}"

local colormap = {
  specify  = h1,
  describe = h2,
  context  = h3,
  when     = h3,
  with     = h3,
  it       = default,
  example  = default,

  head     = h2,
  subhead  = h3,
  entry    = default,
  summary  = h2,

  fail     = bad,
  pend     = "%{yellow}",
  pass     = "",
  good     = good,
  bad      = bad,
  warn     = "%{red}",
  strong   = "%{bright white}",

  reset    = "%{reset}",
  match    = "%{green}",

  listpre     = "%{yellow}-%{reset} ",
  listpost    = "%{red}:%{reset}",
  allpass     = "",
  notallpass  = "%{reverse}",
  summarypost = "%{red}:%{reset}",
  clock       = "",
}


local function color (want_color, s)
  if want_color and have_color then
    s = ansicolors (s)
  else
    s = s:gsub ("%%{(.-)}", "")
  end
  return s
end


return setmetatable (colormap, {
         __call  = function (self, ...) return color (...) end,
         __index = function (_, k)
                     return "%{underline}"
                   end,
       })
