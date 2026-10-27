--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2014-2026 Gary V. Vaughan
]]

-- Check arguments to specl's own functions.  Examples load a separate
-- copy of std._debug, so this doesn't change the code under test.
require 'std._debug'.argcheck = true


local normalize = require 'std.normalize'
local object = require 'std.prototype.object'

local concat = table.concat
local find = string.find
local format = string.format
local getmetamethod = normalize.getmetamethod
local gsub = string.gsub
local match = string.match
local sub = string.sub
local tostring = _G.tostring
local type = _G.type

local dirsep = normalize.package.dirsep
local path_mark = normalize.package.pathmark
local pathsep = normalize.package.pathsep


local function copy(src)
   local dest = {}
   for k, v in pairs(src) do
      dest[k] = v
   end
   return dest
end


local function keysort(a, b)
   if type(a) == 'number' then
      return type(b) ~= 'number' or a < b
   else
      return type(b) ~= 'number' and tostring(a) < tostring(b)
   end
end


local function opairs(t)
   local keys, i = {}, 0
   for k in pairs(t) do
      keys[#keys + 1] = k
   end
   table.sort(keys, keysort)

   local _, _t = pairs(t)
   return function(t)
      i = i + 1
      local k = keys[i]
      if k ~= nil then
         return k, t[k]
      end
   end, _t, nil
end


local function str(x, roots)
   roots = roots or {}

   local function stop_roots(x)
      return roots[x] or str(x, copy(roots))
   end

   if type(x) ~= 'table' or getmetamethod(x, '__tostring') then
      return tostring(x)

   else
      local buf = {'{'}                        -- pre-buffer table open
      roots[x] = tostring(x)                   -- recursion protection

      local kp, vp                             -- previous key and value
      for k, v in opairs(x) do
         if kp ~= nil and k ~= nil then
            -- semi-colon separator after sequence values, or else comma separator
            buf[#buf + 1] = type(kp) == 'number' and k ~= kp + 1 and '; ' or ', '
         end
         if k == 1 or type(k) == 'number' and k -1 == kp then
            -- no key for sequence values
            buf[#buf + 1] = stop_roots(v)
         else
            buf[#buf + 1] = stop_roots(k) .. '=' .. stop_roots(v)
         end
         kp, vp = k, v
      end
      buf[#buf + 1] = '}'                      -- buffer << table close

      return table.concat(buf)                 -- stringify buffer
   end
end


local function render(x, elem, roots)
   roots = roots or {}

   local function stop_roots(x)
      return roots[x] or render(x, elem, copy(roots))
   end

   if type(x) ~= 'table' or
      type((getmetatable(x) or {}).__tostring) == 'function'
   then
      return elem(x)
   else
      local buf, keys = {'{'}, {}
      for k in pairs(x) do
         keys[#keys +1] = k
      end
      table.sort(keys, keysort)

      roots[x] = elem(x)
      local kp, vp
      for _, k in ipairs(keys) do
         local v = x[k]
         if kp ~= nil then
            buf[#buf +1] = ','
         end
         buf[#buf +1] = stop_roots(k) .. '=' .. stop_roots(v)
         kp, vp = k, v
      end
      buf[#buf +1] = '}'
      return table.concat(buf)
   end
end


-- Unlike std.prototype.object.type, fall back to io.type and type for
-- values that aren't objects.
local function objtype(x)
   return(getmetatable(x) or {})._type or io.type(x) or type(x)
end


local function mnemonic(x)
   return render(x, function(x)
      if type(x) == 'string' then
         return string.format('%q', x)
      end
      return tostring(x)
   end)
end



--[[ ================================================================= ]]--
--[[ Copies of what specl uses from lua-stdlib 42, which no package     ]]--
--[[ broken out of lua-stdlib provides yet.  Each 'TODO: stdlib 42'     ]]--
--[[ names the original: replace the copy with a dependency on the      ]]--
--[[ package that provides it, once one is released.                    ]]--
--[[ ================================================================= ]]--


-- TODO: stdlib 42 std.io.catfile.
local function catfile(...)
   return concat({...}, dirsep)
end


-- TODO: stdlib 42 std.io.dirname.
local function dirname(path)
   return(gsub(path, catfile('', '[^', ']*$'), ''))
end


-- TODO: stdlib 42 std.io.slurp, for a file name or handle.
local function slurp(file)
   local h, err = file, nil
   if type(file) == 'string' then
      h, err = io.open(file)
      if h == nil then
         error(err, 2)
      end
   end
   local s = h:read '*a'
   h:close()
   return s
end


-- TODO: stdlib 42 std.io.writelines, for a file handle and strings.
local function writelines(h, ...)
   for i = 1, select('#', ...) do
      h:write((select(i, ...)), '\n')
   end
end


-- TODO: stdlib 42 std.string.escape_pattern.
local function escape_pattern(s)
   return(gsub(s, '[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0'))
end


-- TODO: stdlib 42 std.string.chomp.
local function chomp(s)
   return(gsub(s, '\n$', ''))
end


-- TODO: stdlib 42 std.string.split.
local function split(s, sep)
   local r, patt = {}
   if sep == '' then
      patt = '(.)'
      r[#r + 1] = ''
   else
      patt = '(.-)' ..(sep or '%s+')
   end
   local b, slen = 0, #s
   while b <= slen do
      local _, n, m = find(s, patt, b + 1)
      r[#r + 1] = m or sub(s, b + 1, slen)
      b = n or slen + 1
   end
   return r
end


-- TODO: stdlib 42 std.string.pickle.
local function serialize(x, roots)
   local t = type(x)
   if t == 'string' then
      return format('%q', x)
   elseif t == 'number' then
      if x ~= x then
         return '0/0'
      elseif x == math.huge then
         return '1/0'
      elseif x == -math.huge then
         return '-1/0'
      end
      local s = tostring(x)
      if tonumber(s) ~= x then
         s = format('%.17g', x)
      end
      return s
   elseif t == 'boolean' or t == 'nil' then
      return tostring(x)
   elseif t == 'table' then
      if roots[x] then
         return nil, 'cannot pickle recursive table'
      end
      roots[x] = true
      local buf = {}
      for k in opairs(x) do
         local ks, err = serialize(k, roots)
         if ks == nil then
            return nil, err
         end
         local vs
         vs, err = serialize(x[k], roots)
         if vs == nil then
            return nil, err
         end
         buf[#buf + 1] = '[' .. ks .. ']=' .. vs
      end
      roots[x] = nil
      return '{' .. concat(buf, ',') .. '}'
   end
   return nil, 'cannot pickle ' .. tostring(x)
end

local function pickle(x)
   local s, err = serialize(x, {})
   if s == nil then
      error(err, 2)
   end
   return s
end


-- TODO: stdlib 42 std.string.prettytostring, over std.normalize's
-- string.render.
local function prettytostring(x, indent, spacing)
   indent = indent or '\t'
   spacing = spacing or ''
   return normalize.string.render(x, {
      term = function(x)
         return type(x) ~= 'table' or getmetamethod(x, '__tostring')
      end,
      elem = function(x)
         return type(x) == 'string' and format('%q', x) or tostring(x)
      end,
      sort = function(keylist)
         table.sort(keylist, keysort)
         return keylist
      end,
      open = function()
         local s = spacing .. '{'
         spacing = spacing .. indent
         return s
      end,
      close = function()
         spacing = gsub(spacing, indent .. '$', '')
         return spacing .. '}'
      end,
      pair = function(_, _, _, k, v, kstr, vstr)
         local type_k = type(k)
         local s = spacing
         if type_k ~= 'string' or match(k, '[^%w_]') then
            s = s .. '['
            if type_k == 'table' then
               s = s .. '\n'
            end
            s = s .. kstr
            if type_k == 'table' then
               s = s .. '\n'
            end
            s = s .. ']'
         else
            s = s .. k
         end
         s = s .. ' ='
         if type(v) == 'table' then
            s = s .. '\n'
         else
            s = s .. ' '
         end
         return s .. vstr
      end,
      sep = function(_, k)
         local s = '\n'
         if k then
            s = ',' .. s
         end
         return s
      end,
   })
end


-- TODO: stdlib 42 std.package.normalize.
local function pathsub(path)
   return(gsub(path, '%%?.', function(capture)
      if capture == '?' then
         return path_mark
      elseif capture == '/' then
         return dirsep
      else
         return(gsub(capture, '^%%', '', 1))
      end
   end))
end

local function normalize_path(...)
   local i, paths = 1, {}
   for _, path in ipairs(split(concat({...}, pathsep), pathsep)) do
      path = gsub(pathsub(path), catfile('^[^', ']'), catfile('.', '%0'))
      path = gsub(path, catfile('', '%.', ''), dirsep)
      path = gsub(path, catfile('', '%.$'), '')
      path = gsub(path, catfile('^%.', '%..', ''), catfile('..', ''))
      path = gsub(path, catfile('', '$'), '')

      -- Carefully remove redundant /foo/../ matches.
      repeat
         local again = false
         path = gsub(path, catfile('', '([^', ']+)', '%.%.', ''),
            function(dir1)
               if dir1 == '..' then   -- don't remove /../../
                  return catfile('', '..', '..', '')
               else
                  again = true
                  return dirsep
               end
            end)
         path = gsub(path, catfile('', '([^', ']+)', '%.%.$'),
            function(dir1)
               if dir1 == '..' then -- don't remove /../..
                  return catfile('', '..', '..')
               else
                  again = true
                  return ''
               end
            end)
      until again == false

      -- Eliminate duplicates after normalization.
      if not paths[path] then
         paths[path], i = i, i + 1
      end
   end
   local r = {}
   for path, n in pairs(paths) do
      r[n] = path
   end
   return concat(r, pathsep)
end


-- TODO: stdlib 42 std.table.merge, without its map and nometa options.
local function merge(t, u)
   setmetatable(t, getmetatable(u))
   for k, v in pairs(u) do
      t[k] = v
   end
   return t
end


-- TODO: stdlib 42 std.table.clone, without its map and nometa options.
local function clone(t)
   return merge({}, t)
end


-- TODO: stdlib 42 std.table.empty.
local function empty(t)
   return not next(t)
end


-- TODO: stdlib 42 std.table.invert.
local function invert(t)
   local i = {}
   for k, v in pairs(t) do
      i[v] = k
   end
   return i
end


-- TODO: stdlib 42 std.table.size.
local function size(t)
   local n = 0
   for _ in pairs(t) do
      n = n + 1
   end
   return n
end


--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   io = {
      catfile = catfile,
      dirname = dirname,
      slurp = slurp,
      writelines = writelines,
   },
   object = setmetatable({type = objtype}, {
      __call = function(_, ...)
         return object(...)
      end,
   }),
   operator = {
      eqv = function(a, b)
         if a == b then
            return true
         end
         if type(a) ~= 'table' or type(b) ~= 'table' then
            return false
         end
         return mnemonic(a) == mnemonic(b)
      end,
   },
   package = {
      normalize = normalize_path,
   },
   string = {
      chomp = chomp,
      escape_pattern = escape_pattern,
      pickle = pickle,
      prettytostring = prettytostring,
      split = split,
      tostring = str,
   },
   table = {
      clone = clone,
      empty = empty,
      invert = invert,
      merge = merge,
      size = size,
   },
   tostring = str,
}
