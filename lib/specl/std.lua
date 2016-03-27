--- Load Lua stdlib into `specl.std` namespace.
-- Written by Gary V. Vaughan, 2014
--
-- Copyright (c) 2014-2015 Gary V. Vaughan
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
-- program; see the file LICENSE.md.  If not, a copy can be downloaded
-- from <https://mit-license.org>.

-- First handle debug_init and _DEBUG, being careful not to affect
-- DEBUG disposition of subsequent example loaders for std.debug_init!
local _DEBUG = require "std.debug_init"._DEBUG
_DEBUG.argcheck = true


-- Handle to the stdlib modules.
local M = require "std"

-- Check minimum version requirement.
M.require ("std", "41")


local F = M.functional
local filter, lambda, map, reduce = F.filter, F.lambda, F.map, F.reduce
local set = M.operator.set
local tostring = _G.tostring
local type = _G.type

-- Use std.optparse if available, otherwise standalone optparse module.
local ok
ok, M.optparse = pcall (require, "std.optparse")
if not ok then
  M.optparse = require "optparse"
end


-- Cache submodule handles into local `std` above.
reduce (set, M,
  map (lambda '_2, require ("std." .. _2)', {
    "container",
    "debug",
    "functional",
    "io",
    "list",
    "math",
    "object",
    "package",
    "set",
    "strbuf",
    "string",
    "table",
    "tree",
  })
)


-- Overwrite with implementations copied from unreleased git stdlib master.
-- We are using these already, even though there isn't a released stdlib
-- that exports them yet.

local function copy (src)
  local dest = {}
  for k, v in pairs (src) do dest[k] = v end
  return dest
end


local function keysort (a, b)
  if type (a) == "number" then
    return type (b) ~= "number" or a < b
  else
    return type (b) ~= "number" and tostring (a) < tostring (b)
  end
end


local function opairs (t)
  local keys, i = {}, 0
  for k in pairs (t) do keys[#keys + 1] = k end
  table.sort (keys, keysort)

  local _, _t = pairs (t)
  return function (t)
    i = i + 1
    local k = keys[i]
    if k ~= nil then
      return k, t[k]
    end
  end, _t, nil
end


local function getmetamethod (x, n)
  local m = (getmetatable (x) or {})[n]
  if type (m) == "function" then return m end
  if type ((getmetatable (m) or {}).__call) == "function" then return m end
end


local function str (x, roots)
  roots = roots or {}

  local function stop_roots (x)
    return roots[x] or str (x, copy (roots))
  end

  if type (x) ~= "table" or getmetamethod (x, "__tostring") then
    return tostring (x)

  else
    local buf = {"{"}				-- pre-buffer table open
    roots[x] = tostring (x)			-- recursion protection

    local kp, vp				-- previous key and value
    for k, v in opairs (x) do
      if kp ~= nil and k ~= nil then
        -- semi-colon separator after sequence values, or else comma separator
	buf[#buf + 1] = type (kp) == "number" and k ~= kp + 1 and "; " or ", "
      end
      if k == 1 or type (k) == "number" and k -1 == kp then
	-- no key for sequence values
	buf[#buf + 1] = stop_roots (v)
      else
	buf[#buf + 1] = stop_roots (k) .. "=" .. stop_roots (v)
      end
      kp, vp = k, v
    end
    buf[#buf + 1] = "}"				-- buffer << table close

    return table.concat (buf)			-- stringify buffer
  end
end


local function render (x, elem, roots)
  roots = roots or {}

  local function stop_roots (x)
    return roots[x] or render (x, elem, copy (roots))
  end

  if type (x) ~= "table" or
      type ((getmetatable (x) or {}).__tostring) == "function"
  then
    return elem (x)
  else
    local buf, keys = {"{"}, {}
    for k in pairs (x) do keys[#keys +1] = k end
    table.sort (keys, keysort)

    roots[x] = elem (x)
    local kp, vp
    for _, k in ipairs (keys) do
      local v = x[k]
      if kp ~= nil then buf[#buf +1] = "," end
      buf[#buf +1] = stop_roots (k) .. "=" .. stop_roots (v)
      kp, vp = k, v
    end
    buf[#buf +1] = "}"
    return table.concat (buf)
  end
end


-- Upto std 41.2, std.object returns an actual object, so we have to
-- inject type into the metatable, otherwise std.object is a module
-- and we can inject the type method directly.
local objectmethods = (getmetatable (M.object) or {}).__index or M.object

function objectmethods.type (x)
  return (getmetatable (x) or {})._type or io.type (x) or type (x)
end


local function mnemonic (x)
  return render (x, function (x)
    if type (x) == "string" then
      return string.format ("%q", x)
    end
    return tostring (x)
  end)
end


M.operator = {
  eqv = function (a, b)
    if a == b then return true end
    if type (a) ~= "table" or type (b) ~= "table" then return false end
    return mnemonic (a) == mnemonic (b)
  end,
}


M.string.tostring = str

M.tostring = M.string.tostring


-- We rely on choosing correctly between [gs]etfenv and debug.[gs]etfenv
-- in Lua 5.1 based on the object type; but released stdlib still tries
-- to pass stack offsets to debug.[gs]etfenv, which doesn't work.

if debug.getfenv then

  M.getfenv = function (fn)
    fn = fn or 1

    local type_fn = type (fn)
    if type_fn == "table" then
      fn = (getmetatable (fn) or {}).__call or fn
    elseif type_fn == "number" and fn > 0 then
      fn = fn + 1
    end

    if type (fn) == "function" then
      return debug.getfenv (fn)
    end
    return getfenv (fn), nil
  end

  M.setfenv = function (fn, env)
    fn = fn or 1

    local type_fn = type (fn)
    if type_fn == "table" then
      fn = (getmetatable (fn) or {}).__call or fn
    elseif type_fn == "number" and fn > 0 then
      fn = fn + 1
    end

    if type (fn) == "function" then
      return debug.setfenv (fn, env)
    end
    return setfenv (fn, env), nil
  end

else

  M.getfenv = M.debug.getfenv
  M.setfenv = M.debug.setfenv

end

M.debug.getfenv = nil
M.debug.setfenv = nil



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--

-- Don't prevent examples from loading a different stdlib (or optparse!).
map (function (e) package.loaded[e] = nil end,
     filter (lambda '|k| k:match "^std%." or k == "std" or k == "optparse"', package.loaded))

return M
