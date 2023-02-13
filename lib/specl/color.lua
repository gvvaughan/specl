--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2013-2023 Gary V. Vaughan
]]

local have_color, ansicolors = pcall(require, 'ansicolors')

local _ENV = {
   setfenv = function() end,
   setmetatable = setmetatable,
   gsub = string.gsub,
}
setfenv(1, _ENV)


local h1 = '%{bright blue}'
local h2 = '%{blue}'
local h3 = '%{cyan}'
local default = ''
local good = '%{green}'
local bad = '%{bright white redbg}'

local colormap = {
   specify = h1,
   describe = h2,
   context = h3,
   when = h3,
   with = h3,
   it = default,
   example = default,

   head = h2,
   subhead = h3,
   entry = default,
   summary = h2,

   fail = bad,
   pend = '%{yellow}',
   pass = '',
   good = good,
   bad = bad,
   warn = '%{red}',
   strong = '%{bright}',

   reset = '%{reset}',
   match = '%{green}',

   listpre = '%{yellow}-%{reset} ',
   listpost = '%{red}:%{reset}',
   allpass = '',
   notallpass = '%{reverse}',
   summarypost = '%{red}:%{reset}',
   clock = '',
}


local function color(want_color, s)
   if want_color and have_color then
      s = ansicolors(s)
   else
      s = gsub(s, '%%{(.-)}', '')
   end
   return s
end


return setmetatable(colormap, {
   __call = function(self, ...) return color(...) end,
   __index = function(_, k)
                return '%{underline}'
             end,
})
