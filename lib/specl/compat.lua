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
-- program; see the file LICENSE.md.  If not, a copy can be downloaded
-- from <https://mit-license.org>.


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
  loadstring        = loadstring,
  xpcall            = xpcall,
}
