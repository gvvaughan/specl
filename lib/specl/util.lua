--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

-- Only luaposix's submodules, whose APIs are the same in every release
-- since 33, unlike the legacy functions of its `posix` module.  Look for
-- them when they are first needed, so that showing the help or version
-- does not load them.
local posix
local function posixmodules()
   if posix == nil then
      local have, dirent = pcall(require, 'posix.dirent')
      posix = have and {
         dirent = dirent,
         stat = require 'posix.sys.stat',
         time = require 'posix.sys.time',
      } or false
   end
   return posix
end


local _ = {
   len = require 'std.normalize'.len,
   std = require 'specl.std',
}

local _ENV = {
   getmetatable = getmetatable,
   ipairs = ipairs,
   next = next,
   rawset = rawset,
   setfenv = function() end,
   setmetatable = setmetatable,
   tostring = tostring,
   type = type,

   now = os.time,
   format = string.format,
   gsub = string.gsub,
   rep = string.rep,
   concat = table.concat,

   catfile = _.std.io.catfile,
   len = _.len,
   str = _.std.tostring,
}
setfenv(1, _ENV)
_ = nil



local function deepcopy(orig, copied)
   copied = copied or {}

   local mt = getmetatable(orig)
   local copy
   -- be careful of tables set to be their own metatable!
   if mt ~= orig then
      copy = mt and setmetatable({}, copied[mt] or deepcopy(mt, copied)) or {}
   else
      copy = {}
   end
   copied[orig] = copy
   for k, v in next, orig, nil do
      local innerk = k
      local innerv = v
      if type(k) == 'table' then
         innerk = copied[k] or deepcopy(k, copied)
      end
      if type(v) == 'table' then
         innerv = copied[v] or deepcopy(v, copied)
      end
      rawset(copy, innerk, innerv)
   end
   if mt == orig then
      setmetatable(copy, copy)
   end
   return copy
end


local function isstring(x)
   return type(x) == 'string' or(getmetatable(x) or {})._type == 'string'
end


local function strip1st(s)
   local r = gsub(s, '^.-%S%s+', '')
   if r ~= s then
      return r
   end
   -- gsub above didn't change anything, so there must be 0 or 1 words
   -- in *s*(maybe with whitespace for 0 words), so strip everything!
   return ''
end


local M = {
   -- Concatenate elements of table ALTERNATIVES much like `table.concat`
   -- except the separator is always ', '.   If INFIX is provided, the
   -- final separotor uses that instead of ', '.   If QUOTED is not nil or
   -- false, then any elements of ALTERNATIVES with type 'string' will be
   -- quoted using `string.format('%q')` before concatenation.
   concat = function(alternatives, infix, quoted)
      local buf = {}
      for i = 1, len(alternatives) do
         local v = alternatives[i]
         if quoted ~= nil and isstring(v) then
            buf[i] = format('%q', v)
         else
            buf[i] = str(v)
         end
      end
      buf = concat(buf, ', ')

      return infix and gsub(buf, ', ([^,]+)$', infix .. '%1') or buf
   end,

   -- Return a complete copy of T, along with copied metatables.
   deepcopy = deepcopy,

   -- Return elements of DESCRIPTIONS concatenated after removing the
   -- first word of each item.
   examplename = function(descriptions)
      local buf = {}
      for i, v in ipairs(descriptions) do
         buf[i] = strip1st(v)
      end
      return concat(buf, ' ')
   end,

   -- Return an appropriate indent for last element of DESCRIPTIONS.
   indent = function(descriptions)
      return rep('   ', #descriptions - 1)
   end,

   nop = function() end,

   -- Return S with the first word and following whitespace stripped,
   -- where S contains some whitespace initially(i.e single words are
   -- returned unchanged).
   strip1st = strip1st,

   -- Simplified object.type, that just returns 'object' for non-primitive
   -- types, or else the primitive type name.
   type = function(x)
      if type(x) == 'table' and(getmetatable(x) or {})._type ~= 'table' then
         return 'object'
      end
      return type(x)
   end,
}


M.files = function(root, t)
   local p = posixmodules()
   if not p then
      return nil, "install luaposix to autoload spec files from '" .. tostring(root) .. "/'"
   end

   t = t or {}
   for _, file in ipairs(p.dirent.dir(root) or {}) do
      if file ~= '.' and file ~= '..' then
         local path = catfile(root, file)
         local info = p.stat.lstat(path)
         if info and p.stat.S_ISDIR(info.st_mode) ~= 0 then
            t = M.files(path, t)
         else
            t[#t + 1] = path
         end
      end
   end
   return t
end


-- Use higher resolution timers from luaposix if available.
M.gettimeofday = function()
   local p = posixmodules()
   if p then
      return p.time.gettimeofday()
   end
   return now()
end

M.timesince = function(earlier)
   local later = M.gettimeofday()
   if type(later) == 'table' then
      return (later.tv_sec - earlier.tv_sec) +
         (later.tv_usec - earlier.tv_usec) / 1000000
   end
   return later - earlier
end


return M
