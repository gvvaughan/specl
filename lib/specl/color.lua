-- Conditional ANSI coloration.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2015 Gary V. Vaughan
--
-- Specl is free software distributed under the terms of the MIT license;
-- it may be used for any purpose, including commercial purposes, at
-- absolutely no cost without having to ask permission.
--
-- The only requirement is that if you do use Specl, then you should give
-- credit by including the appropriate copyright notice somewhere in your
-- product or its documentation.
--
-- You should have received a copy of the MIT license along with this
-- program; see the file LICENSE.  If not, a copy can be downloaded from
-- <http://www.opensource.org/licenses/mit-license.html>.


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
  strong   = "%{bright}",

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
