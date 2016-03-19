-- Compatibility between 5.1, 5.2 and 5.3
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2016 Gary V. Vaughan
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.



local getfenv = getfenv or function (fn)
  fn = fn or 1
  -- Unwrap functable:
  if type (fn) == "table" then
    fn = fn.call or (getmetatable (fn) or {}).__call
  elseif type (fn) == "number" then
    fn = debug.getinfo (fn + 1, "f").func
  end
  local name, env
  local up = 0
  repeat
    up = up + 1
    name, env = debug.getupvalue (fn, up)
  until name == '_ENV' or name == nil
  return env
end


-- Lua 5.1 load implementation does not handle string argument.
local load = load
if not pcall (load, "_=1") then
  local loadfunction = load
  load = function (...)
    if type (...) == "string" then
      return loadstring (...)
    end
    return loadfunction (...)
  end
end


-- Lua 5.1 requires 'debug.setfenv' to change environment of C funcs.
local _setfenv = debug.setfenv


local function setfenv (fn, t)
  -- Unwrap functable:
  if type (fn) == "table" then
    fn = fn.call or (getmetatable (fn) or {}).__call
  end

  if _setfenv then
    return _setfenv (fn, t)

  else
    if type (fn) == "number" then
      fn = debug.getinfo (fn == 0 and 0 or fn + 1, "f").func
    end

    -- From http://lua-users.org/lists/lua-l/2010-06/msg00313.html
    local name
    local up = 0
    repeat
      up = up + 1
      name = debug.getupvalue (fn, up)
    until name == '_ENV' or name == nil
    if name then
      debug.upvaluejoin (fn, up, function () return name end, 1)
      debug.setupvalue (fn, up, t)
    end
    return f
  end
end


-- Lua 5.3 has table.unpack but not _G.unpack;
-- Lua 5.2 has both table.unpack and _G.unpack;
-- Lua 5.1 has _G.unpack but not table.unpack!
local unpack = table.unpack or unpack


do
  local have_xpcall_args
  local function catch (arg) have_xpcall_args = arg end
  xpcall (catch, function () end, true)

  if have_xpcall_args ~= true then
    local _xpcall = xpcall
    xpcall = function (fn, errh, ...)
      local args, n = {...}, select ("#", ...)
      return _xpcall(function() return fn (unpack (args, 1, n)) end, errh)
    end
  end
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

return {
  getfenv	= getfenv,
  load		= load,
  setfenv	= setfenv,
  unpack	= unpack,
  xpcall	= xpcall,
}
