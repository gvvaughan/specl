-- Compatibility between 5.1, 5.2 and 5.3
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2015 Gary V. Vaughan
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


local std = require "specl.std"


-- Lua 5.3 has renamed package.loaders to package.searchers, so set a
-- metatable to make sure assignments and references go to the right
-- one.
local package_mt = {
  -- These methods only trigger when the referenced key is missing,
  -- so when the client code references the wrong entry, the methods
  -- trigger, and we retarget the key that is present.
  __index = function (self, k)
    if k == "loaders" then
      return self.searchers
    elseif k == "searchers" then
      return self.loaders
    end
  end,

  __newindex = function (self, k, v)
    if k == "loaders" then
      k = "searchers"
    elseif k == "searchers" then
      k = "loaders"
    end
    return rawset (self, k, v)
  end,
}

local function intercept_loaders (t)
  -- If it's already set, we're done.
  if getmetatable (t) ~= package_mt then
    -- Avoid infinite loops when neither key is present!
    if t.searchers ~= nil or t.loaders ~= nil then
      setmetatable (t, package_mt)
    end
  end
  return t
end


local loadstring = loadstring or function (chunk, chunkname)
  return load (chunk, chunkname)
end


do
  local have_xpcall_args
  local function catch (arg) have_xpcall_args = arg end
  local unpack = table.unpack or unpack
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
  intercept_loaders = intercept_loaders,
  loadstring        = loadstring,
  xpcall            = xpcall,
}
