--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

local have_color, ansicolors = pcall(require, 'ansicolors')

local _ENV = {
   setfenv = function() end,
   setmetatable = setmetatable,
   tostring = tostring,
   gsub = string.gsub,
}
setfenv(1, _ENV)


-- Specl marks its own colors with control characters, so that text from the
-- examples, which can have a `%{` in it, as the Lua patterns that they show
-- do, is never mistaken for one of them.
local function mark(keys)
   return '\1' .. keys .. '\2'
end


local h1 = mark 'bright blue'
local h2 = mark 'blue'
local h3 = mark 'cyan'
local default = ''
local good = mark 'green'
local bad = mark 'bright white redbg'

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
   pend = mark 'yellow',
   pass = '',
   good = good,
   bad = bad,
   warn = mark 'red',
   strong = mark 'bright',

   reset = mark 'reset',
   match = mark 'green',

   listpre = mark 'yellow' .. '-' .. mark 'reset' .. ' ',
   listpost = mark 'red' .. ':' .. mark 'reset',
   allpass = '',
   notallpass = mark 'reverse',
   summarypost = mark 'red' .. ':' .. mark 'reset',
   clock = '',
}


local function color(want_color, s)
   s = tostring(s or '')
   if want_color and have_color then
      local function paint(keys)
         return ansicolors.noReset('%{' .. keys .. '}')
      end
      local reset = ansicolors.noReset('%{reset}')
      s = reset .. (gsub(s, '\1(.-)\2', paint)) .. reset
   else
      s = gsub(s, '\1.-\2', '')
   end
   return s
end


return setmetatable(colormap, {
   __call = function(self, ...) return color(...) end,
   __index = function(_, k)
                return mark 'underline'
             end,
})
