-- Miscellaneous utility functions.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2016 Gary V. Vaughan
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


local have_posix, posix = pcall (require, "posix")

-- Don't prevent examples from loading a different luaposix.
for k in pairs (package.loaded) do
  if k == "posix" or k == "posix_c" or k:match "^posix%." then
    package.loaded[k] = nil
  end
end


local _ = {
  std	= require "specl.std",
}

local _ENV = {
  getmetatable	= getmetatable,
  ipairs	= ipairs,
  next		= next,
  rawset	= rawset,
  setfenv	= function () end,
  setmetatable	= setmetatable,
  tostring	= tostring,
  type		= type,

  now		= os.time,
  format	= string.format,
  gsub		= string.gsub,
  rep		= string.rep,
  concat	= table.concat,

  catfile	= _.std.io.catfile,
  str		= _.std.tostring,
}
setfenv (1, _ENV)
_ = nil



local function deepcopy (orig, copied)
  copied = copied or {}

  local mt = getmetatable (orig)
  local copy
  -- be careful of tables set to be their own metatable!
  if mt ~= orig then
    copy = mt and setmetatable ({}, copied[mt] or deepcopy (mt, copied)) or {}
  else
    copy = {}
  end
  copied[orig] = copy
  for k, v in next, orig, nil do
    if type (k) == "table" then k = copied[k] or deepcopy (k, copied) end
    if type (v) == "table" then v = copied[v] or deepcopy (v, copied) end
    rawset (copy, k, v)
  end
  if mt == orig then
    setmetatable (copy, copy)
  end
  return copy
end


local function isstring (x)
  return type (x) == "string" or (getmetatable (x) or {})._type == "string"
end


local function strip1st (s)
  local r = gsub (s, "^.-%S%s+", "")
  if r ~= s then return r end
  -- gsub above didn't change anything, so there must be 0 or 1 words
  -- in *s* (maybe with whitespace for 0 words), so strip everything!
  return ""
end


local M = {
  -- Concatenate elements of table ALTERNATIVES much like `table.concat`
  -- except the separator is always ", ".  If INFIX is provided, the
  -- final separotor uses that instead of ", ".  If QUOTED is not nil or
  -- false, then any elements of ALTERNATIVES with type "string" will be
  -- quoted using `string.format ("%q")` before concatenation.
  concat = function (alternatives, infix, quoted)
    local buf = {}
    for i, v in ipairs (alternatives) do
      if quoted ~= nil and isstring (v) then
        buf[i] = format ("%q", v)
      else
        buf[i] = str (v)
      end
    end
    buf = concat (buf, ", ")

    return infix and gsub (buf, ", ([^,]+)$", infix .. "%1") or buf
  end,

  -- Return a complete copy of T, along with copied metatables.
  deepcopy = deepcopy,

  -- Return elements of DESCRIPTIONS concatenated after removing the
  -- first word of each item.
  examplename = function (descriptions)
    local buf = {}
    for i, v in ipairs (descriptions) do
      buf[i] = strip1st (v)
    end
    return concat (buf, " ")
  end,

  -- Return an appropriate indent for last element of DESCRIPTIONS.
  indent = function (descriptions)
    return rep ("  ", #descriptions - 1)
  end,

  nop = function () end,

  -- Return S with the first word and following whitespace stripped,
  -- where S contains some whitespace initially (i.e single words are
  -- returned unchanged).
  strip1st = strip1st,

  -- Simplified object.type, that just returns "object" for non-primitive
  -- types, or else the primitive type name.
  type = function (x)
    if type (x) == "table" and (getmetatable (x) or {})._type ~= "table" then
      return "object"
    end
    return type (x)
  end,
}


local timersub = false

if not have_posix then

  M.files = function (root, t)
    return nil, "install luaposix to autoload spec files from '" .. tostring (root) .. "/'"
  end

else

  M.files = function (root, t)
    t = t or {}
    for _, file in ipairs (posix.dir (root) or {}) do
      if file ~= "." and file ~= ".." then
        local path = catfile (root, file)
        if posix.stat (path).type == "directory" then
          t = files (path, t)
        else
          t[#t + 1] = path
        end
      end
    end
    return t
  end

  timersub = posix.sys and posix.sys.timersub or posix.timersub

end


-- Use higher resolution timers from luaposix if available.
if timersub then
  M.gettimeofday = posix.gettimeofday

  M.timesince = function (earlier)
    local elapsed = timersub (M.gettimeofday (), earlier)
    return (elapsed.usec / 1000000) + elapsed.sec
  end

else

  M.gettimeofday = now

  M.timesince = function (earlier)
    return now () - earlier
  end

end


return M
