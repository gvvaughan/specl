--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

local _ENV = {
   load = load,
   loadfile = loadfile,
   loadstring = loadstring,
   pcall = pcall,
   rawsetfenv = setfenv,
   setfenv = function() end,
   select = select,
   type = type,
   unpack = table.unpack or unpack,
   xpcall = xpcall,

   open = io.open,
   config = package.config,
   searchpath = package.searchpath,
   find = string.find,
   format = string.format,
   gmatch = string.gmatch,
   gsub = string.gsub,
   match = string.match,
   sub = string.sub,
   concat = table.concat,
}
setfenv(1, _ENV)


-- Lua 5.1 load and loadfile take no mode or environment arguments, and
-- load does not accept a string chunk.  LuaJIT and Lua 5.2+ do.
if not pcall(load, '_=1') then
   local function checkmode(c, mode)
      local kind = c == '\27' and 'binary' or 'text'
      if mode ~= nil and not find(mode, sub(kind, 1, 1), 1, true) then
         return format("attempt to load a %s chunk (mode is '%s')", kind, mode)
      end
   end

   local function setenv(fn, err, n, env)
      -- A Lua 5.1 function can't have a nil environment, so the
      -- closest equivalent is an empty one.
      if fn ~= nil and n > 0 then
         rawsetfenv(fn, env or {})
      end
      return fn, err
   end

   load = function(ld, source, mode, ...)
      if type(ld) == 'function' then
         local buf, piece = {}, ld()
         while piece ~= nil and piece ~= '' do
            buf[#buf + 1] = piece
            piece = ld()
         end
         ld, source = concat(buf), source or '=(load)'
      end
      if type(ld) == 'string' then
         local err = checkmode(sub(ld, 1, 1), mode)
         if err then
            return nil, err
         end
      end
      local fn, err = loadstring(ld, source)
      return setenv(fn, err, select('#', ...), ...)
   end

   local nativeloadfile = loadfile
   loadfile = function(filename, mode, ...)
      local fh = mode ~= nil and filename ~= nil and open(filename, 'rb')
      if fh then
         -- Like Lua, skip a first line starting with '#'.
         local c = fh:read(1)
         if c == '#' then
            fh:read('*l')
            c = fh:read(1)
         end
         fh:close()
         local err = checkmode(c, mode)
         if err then
            return nil, err
         end
      end
      local fn, err = nativeloadfile(filename)
      return setenv(fn, err, select('#', ...), ...)
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
   loadfile = loadfile,
   searchpath = searchpath,
   xpcall = xpcall,
}
