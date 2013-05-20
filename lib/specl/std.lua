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



--[[ -------------- ]]--
--[[ std.functional ]]--
--[[ -------------- ]]--


-- Return given metamethod, if any, or nil.
local function metamethod (x, n)
  local _, m = pcall (function (x)
                        return getmetatable (x)[n]
                      end,
                      x)
  if type (m) ~= "function" then
    m = nil
  end
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
  local m = func.metamethod (x, "__totable")
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


-- Object methods.
local M = {
  type = function (self)
    if type (self) == "table" and self._type ~= nil then
      return self._type
    end
    return type (self)
  end,
}


-- Root object.
local new = {
  _type = "object",

  _init = {},

  _clone = function (self, ...)
    local object = clone (self)
    if type (self._init) == "table" then
      merge (object, clone_rename (self._init, ...))
    else
      object = self._init (object, ...)
    end
    return setmetatable (object, object)
  end,

  -- respond to table.totable with a new table containing a copy of all
  -- elements from object, except any key prefixed with "_".
  __totable = function (self)
    local t = {}
    for k, v in pairs (self) do
      if type (k) ~= "string" or k:sub (1, 1) ~= "_" then
        t[k] = v
      end
    end
    return t
  end,

  __index = M,

  __call = function (...)
    return (...)._clone (...)
  end,
}
setmetatable (new, new)

-- Inject `new` method into public interface.
M.new = new

std.object = setmetatable (M, {
  -- Sugar to call new automatically from module table.
  -- Use select to replace `self` (this table) with `new`, the real prototype.
  __call = function (...)
    return new._clone (new, select (2, ...))
  end,
})


-- A nicer handle for the rest of the file to use...
Object = new



--[[ ---------- ]]--
--[[ std.strbuf ]]--
--[[ ---------- ]]--

--- String buffers.

local M = {
  --- Add a string to a buffer
  concat = function (b, s)
    table.insert (b, s)
    return b
  end,

  --- Convert a buffer to a string
  tostring = function (b)
    return table.concat (b)
  end,
}

--- Create a new string buffer
-- @return strbuf
local function new (...)
  return Object {
    -- Derived object type.
    _type = "strbuf",

    -- Metamethods.
    __concat   = M.concat,   -- buffer .. string
    __tostring = M.tostring, -- tostring (buffer)

    -- strbuf:method ()
    __index = M,

    -- Initialise.
    ...
  }
end

-- Inject `new` method into public interface.
M.new = new

std.strbuf = setmetatable (M, {
  -- Sugar to call new automatically from module table.
  __call = function (self, t)
    return new (unpack (t))
  end,
})



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
    local i, v = nil, nil
    for j, w in pairs (x) do
      s = s .. sep (x, i, v, j, w) .. pair (x, j, w, stop_roots (j), stop_roots (w))
      i, v = j, w
    end
    s = s .. sep(x, i, v, nil, nil) .. close (x)
    return s:tostring ()
  end
end


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
                   local s = spacing .. "["
                   if type (i) == "table" then
                     s = s .. "\n"
                   end
                   s = s .. is
                   if type (i) == "table" then
                     s = s .. "\n"
                   end
                   s = s .. "] ="
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
