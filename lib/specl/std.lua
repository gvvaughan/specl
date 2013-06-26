--[[

Lua stdlib, with quite a few bits missing.

This file is licensed under the terms of the MIT license reproduced below.

=============================================================================

Copyright (C) 2013 Reuben Thomas.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=============================================================================
]]


local std = {}

-- Return the named entry from x's metatable, if any, else nil.
local function metaentry (x, n)
  local ok, f = pcall (function (x)
	                 return getmetatable (x)[n]
		       end,
		       x)
  if not ok then f = nil end
  return f
end



--[[ -------------- ]]--
--[[ std.functional ]]--
--[[ -------------- ]]--


-- Return given metamethod, if any, or nil.
local function metamethod (x, n)
  local m = metaentry (x, n)
  if type (m) ~= "function" then m = nil end
  return m
end


std.func = {
  metamethod = metamethod,
}



--[[ --------- ]]--
--[[ std.table ]]--
--[[ --------- ]]--


-- Make a shallow copy of a table, including any metatable.
local function clone (t, nometa)
  local u = {}
  if not nometa then
    setmetatable (u, getmetatable (t))
  end
  for i, v in pairs (t) do
    u[i] = v
  end
  return u
end


-- Clone a table, renaming some keys.
local function clone_rename (map, t)
  local r = clone (t)
  for i, v in pairs (map) do
    r[v] = t[i]
    r[i] = nil
  end
  return r
end


-- Merge one table into another. Merge <u> into <t>.
local function merge (t, u)
  for k, v in pairs (u) do
    t[k] = v
  end
  return t
end


--- Turn an object into a table according to __totable metamethod.
local function totable (x)
  local m = metamethod (x, "__totable")
  if m then
    return m (x)
  elseif type (x) == "table" then
    return x
  else
    return nil
  end
end


std.table = {
  clone        = clone,
  clone_rename = clone_rename,
  merge        = merge,
  totable      = totable,
}



--[[ ---------- ]]--
--[[ std.object ]]--
--[[ ---------- ]]--


-- Return the extended object type, if any, else primitive type.
local function object_type (self)
  local _type = metaentry (self, "_type")
  if type (self) == "table" and _type ~= nil then
    return _type
  end
  return type (self)
end


-- Return a new object, cloned from prototype.
local function object_clone (prototype, ...)
  local mt = getmetatable (prototype)

  -- Make a shallow copy of prototype.
  local object = {}
  for k, v in pairs (prototype) do
    object[k] = v
  end

  -- Map arguments according to _init metamathod.
  local _init = metaentry (prototype, "_init")
  if type (_init) == "table" then
    merge (object, clone_rename (_init, ...))
  else
    object = _init (object, ...)
  end

  -- Extract any new fields beginning with "_".
  local object_mt = {}
  for k, v in pairs (object) do
    if type (k) == "string" and k:sub (1, 1) == "_" then
      object_mt[k], object[k] = v, nil
    end
  end

  if next (object_mt) == nil then
    -- Reuse metatable if possible
    object_mt = getmetatable (prototype)
  else

    -- Otherwise copy the prototype metatable...
    local t = {}
    for k, v in pairs (mt) do
      t[k] = v
    end
    -- ...but give preference to "_" prefixed keys from init table
    object_mt = merge (t, object_mt)

    -- ...and merge object methods from prototype too.
    if mt then
      if type (object_mt.__index) == "table" and type (mt.__index) == "table" then
        local methods = clone (object_mt.__index)
	for k, v in pairs (mt.__index) do
          methods[k] = methods[k] or v
	end
	object_mt.__index = methods
      end
    end
  end

  return setmetatable (object, object_mt)
end


-- Return a stringified version of the contents of object.
local function stringify (object)
  local totable = metaentry (object, "__totable")
  local array = clone (totable (object), "nometa")
  local other = clone (array, "nometa")
  local s = ""
  if #other > 0 then
    for i in ipairs (other) do other[i] = nil end
  end
  for k in pairs (other) do array[k] = nil end
  for i, v in ipairs (array) do array[i] = tostring (v) end

  local keys, dict = {}, {}
  for k in pairs (other) do table.insert (keys, k) end
  table.sort (keys, function (a, b) return tostring (a) < tostring (b) end)
  for _, k in ipairs (keys) do
    table.insert (dict, tostring (k) .. "=" .. tostring (other[k]))
  end

  if #array > 0 then
    s = s .. table.concat (array, ", ")
    if next (dict) ~= nil then ss = s .. "; " end
  end
  if #dict > 0 then
    s = s .. table.concat (dict, ", ")
  end

  return metaentry (object, "_type") .. " {" .. s .. "}"
end


-- Return a new table with a shallow copy of all non-.rivate fields in object.
local function tablify (object)
  local t = {}
  for k, v in pairs (object) do
    if type (k) ~= "string" or k:sub (1, 1) ~= "_" then
      t[k] = v
    end
  end
  return t
end

-- Metatable for objects
local metatable = {
  _type = "Object",
  _init = {},

  __totable  = tablify,
  __tostring = stringify,

  -- object:method ()
  __index    = {
    clone    = object_clone,
    tostring = stringify,
    totable  = tablify,
    type     = object_type,
  },

  -- Sugar instance creation
  __call = function (self, ...)
    return self:clone (...)
  end,
}


-- A nicer handle for the rest of the file to use...
std.Object = setmetatable ({}, metatable)



--[[ ---------- ]]--
--[[ std.strbuf ]]--
--[[ ---------- ]]--

--- String buffers.

-- Add a string to a buffer
local function concat (b, s)
  table.insert (b, s)
  return b
end


-- Convert a buffer to a string.
local function stringify (b)
  return table.concat (b)
end


std.strbuf = std.Object {
  -- Derived object type.
  _type = "StrBuf",

  -- Metamethods.
  __concat   = concat,    -- buffer .. string
  __tostring = stringify, -- tostring (buffer)

  -- strbuf:method ()
  __index = {
    concat   = concat,
    tostring = stringify,
  },
}



--[[ ------ ]]--
--[[ std.io ]]--
--[[ ------ ]]--


-- Process files specified on the command-line.
local function process_files (fn)
  if #arg == 0 then
    table.insert (arg,  "-")
  end
  for i, v in ipairs (arg) do
    if v == "-" then
      io.input (io.stdin)
    else
      io.input (v)
    end
    fn (v, i)
  end
end


std.io = {
  process_files = process_files,
}



--[[ ---------- ]]--
--[[ std.string ]]--
--[[ ---------- ]]--


-- Remove any final newline from a string.
local function chomp (s)
  return s:gsub ("\n$", "")
end


--- Escape a string to be used as a pattern
local function escape_pattern (s)
  return (string.gsub (s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end


-- Slurp a file handle.
local function slurp (h)
  if h == nil then
    h = io.input ()
  elseif type (h) == "string" then
    h = io.open (h)
  end
  if h then
    local s = h:read ("*a")
    h:close ()
    return s
  end
end


-- Turn tables into strings with recursion detection.
local function render (x, open, close, elem, pair, sep, roots)
  local function stop_roots (x)
    return roots[x] or render (x, open, close, elem, pair, sep, clone (roots))
  end
  roots = roots or {}
  if type (x) ~= "table" or metamethod (x, "__tostring") then
    return elem (x)
  else
    local s = std.strbuf {}
    s = s .. open (x)
    roots[x] = elem (x)

    -- create a sorted list of keys
    local ord = {}
    for k, _ in pairs (x) do table.insert (ord, k) end
    table.sort (ord, function (a, b) return tostring (a) < tostring (b) end)

    -- traverse x again in sorted order
    local i, v = nil, nil
    for _, j in pairs (ord) do
      local w = x[j]
      s = s .. sep (x, i, v, j, w) .. pair (x, j, w, stop_roots (j), stop_roots (w))
      i, v = j, w
    end
    s = s .. sep(x, i, v, nil, nil) .. close (x)
    return s:tostring ()
  end
end


-- Extend `tostring` to work better on tables.
local _tostring = tostring
local function tostring (x)
  return render (x,
                 function () return "{" end,
                 function () return "}" end,
                 _tostring,
                 function (t, _, _, i, v)
                   return i .. "=" .. v
                 end,
                 function (_, i, _, j)
                   if i and j then
                     return ","
                   end
                   return ""
                 end)
end


-- Pretty-print a table.
local function prettytostring (t, indent, spacing)
  indent = indent or "\t"
  spacing = spacing or ""
  return render (t,
                 function ()
                   local s = spacing .. "{"
                   spacing = spacing .. indent
                   return s
                 end,
                 function ()
                   spacing = string.gsub (spacing, indent .. "$", "")
                   return spacing .. "}"
                 end,
                 function (x)
                   if type (x) == "string" then
                     return string.format ("%q", x)
                   else
                     return tostring (x)
                   end
                 end,
                 function (x, i, v, is, vs)
                   local s = spacing
		   if type (i) ~= "string" or i:match "[^%w_]" then
		     s = s .. "["
                     if type (i) == "table" then
                       s = s .. "\n"
                     end
                     s = s .. is
                     if type (i) == "table" then
                       s = s .. "\n"
                     end
                     s = s .. "]"
		   else
		     s = s .. i
		   end
		   s = s .. " ="
                   if type (v) == "table" then
                     s = s .. "\n"
                   else
                     s = s .. " "
                   end
                   s = s .. vs
                   return s
                 end,
                 function (_, i)
                   local s = "\n"
                   if i then
                     s = "," .. s
                   end
                   return s
                 end)
end


std.string = {
  chomp          = chomp,
  escape_pattern = escape_pattern,
  prettytostring = prettytostring,
  render         = render,
  slurp          = slurp,
  tostring       = tostring,
}


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return std
