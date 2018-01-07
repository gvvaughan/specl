--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2013-2018 Gary V. Vaughan
]]

local _ENV = {
   load = load,
   loadstring = loadstring,
   pcall = pcall,
   setfenv = function() end,
   select = select,
   type = type,
   unpack = table.unpack or unpack,
   xpcall = xpcall,

   open = io.open,
   config = package.config,
   searchpath = package.searchpath,
   gmatch = string.gmatch,
   gsub = string.gsub,
   match = string.match,
   concat = table.concat,
}
setfenv(1, _ENV)


-- Lua 5.1 load implementation does not handle string argument.
if not pcall(load, '_=1') then
   local loadfunction = load
   load = function(...)
      if type(...) == 'string' then
         return loadstring(...)
      end
      return loadfunction(...)
   end
end


local dirsep, pathsep, path_mark = match(config, '^(%S+)\n(%S+)\n(%S+)\n')


local searchpath = searchpath or function(name, path, sep, rep)
   name = gsub(name, sep or '%.', rep or dirsep)

   local errbuf = {}
   for template in gmatch(path, '[^' .. pathsep .. ']+') do
      local filename = gsub(template, path_mark, name)
      local fh = open(filename, 'r')
      if fh then
         fh:close()
         return filename
      end
      errbuf[#errbuf + 1] = "\tno file '" .. filename .. "'"
   end
   return nil, concat(errbuf, '\n')
end


do
   local have_xpcall_args
   local function catch(arg) have_xpcall_args = arg end
   xpcall(catch, function() end, true)

   if have_xpcall_args ~= true then
      local _xpcall = xpcall
      xpcall = function(fn, errh, ...)
         local args, n = {...}, select('#', ...)
         return _xpcall(function() return fn(unpack(args, 1, n)) end, errh)
      end
   end
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

return {
   load = load,
   searchpath = searchpath,
   xpcall = xpcall,
}
