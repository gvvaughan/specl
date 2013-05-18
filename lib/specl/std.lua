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

--- String buffers.

local metatable = {}
local strbuf = {
  -- Create a new string buffer.
  new      = function () return setmetatable ({}, metatable) end,

  -- Add a string to a buffer.
  concat   = function (b, s) table.insert (b, s); return b end,

  -- Convert a buffer to a string.
  tostring = function  (b) return table.concat (b) end,
}

-- Metamethods for string buffers.
metatable.__index    = strbuf
metatable.__concat   = strbuf.concat
metatable.__tostring = strbuf.tostring


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


-- Root object.
local Object = {
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

  __call = function (...)
    return (...)._clone (...)
  end,
}
setmetatable (Object, Object)


-- Process files specified on the command-line.
local function processFiles (fn)
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


-- Turn tables into strings with recursion detection.
local function render (x, open, close, elem, pair, sep, roots)
  local function stop_roots (x)
    return roots[x] or render (x, open, close, elem, pair, sep, clone (roots))
  end
  roots = roots or {}
  if type (x) ~= "table" or metamethod (x, "__tostring") then
    return elem (x)
  else
    local s = strbuf.new ()
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



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  chomp          = chomp,
  clone          = clone,
  clone_rename   = clone_rename,
  escape_pattern = escape_pattern,
  merge          = merge,
  metamethod     = metamethod,
  Object         = Object,
  prettytostring = prettytostring,
  processFiles   = processFiles,
  render         = render,
  slurp          = slurp,
  tostring       = tostring,
}

return M
