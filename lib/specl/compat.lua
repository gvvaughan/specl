-- Compatibility between 5.1 and 5.2
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2014 Gary V. Vaughan
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


-- Lua 5.1 requires 'debug.setfenv' to change environment of C funcs.
local _setfenv = debug.setfenv


local function setfenv (f, t)
  -- Unwrap functable:
  if type (f) == "table" then
    f = f.call or (getmetatable (f) or {}).__call
  end

  if _setfenv then
    return _setfenv (f, t)

  else
    -- From http://lua-users.org/lists/lua-l/2010-06/msg00313.html
    local name
    local up = 0
    repeat
      up = up + 1
      name = debug.getupvalue (f, up)
    until name == '_ENV' or name == nil
    if name then
      debug.upvaluejoin (f, up, function () return name end, 1)
      debug.setupvalue (f, up, t)
    end
    return f
  end
end


local loadstring = loadstring or function (chunk, chunkname)
  return load (chunk, chunkname)
end


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
  loadstring = loadstring,
  setfenv    = setfenv,
  xpcall     = xpcall,
}
