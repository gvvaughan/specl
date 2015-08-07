--- Load Lua stdlib into `specl.std` namespace.

-- First handle debug_init and _DEBUG, being careful not to affect
-- DEBUG disposition of subsequent example loaders for std.debug_init!
local _DEBUG = require "std.debug_init"._DEBUG
_DEBUG.argcheck = false


-- Handle to the stdlib modules.
local M = require "std"

-- Check minimum version requirement.
M.require ("std", "41")


local F = M.functional
local filter, lambda, map, reduce = F.filter, F.lambda, F.map, F.reduce
local set = M.operator.set
local tostring = _G.tostring
local type = _G.type


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
    "optparse",
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


function M.string.tostring (x)
  return render (x, tostring)
end


M.tostring = M.string.tostring



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--

-- Don't prevent examples from loading a different stdlib.
map (function (e) package.loaded[e] = nil end,
     filter (lambda '|k| k:match "^std%." or k == "std"', package.loaded))

return M
