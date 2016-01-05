-- Compatibility between 5.1, 5.2 and 5.3
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
-- program; see the file LICENSE.  If not, a copy can be downloaded from
-- <http://www.opensource.org/licenses/mit-license.html>.


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
