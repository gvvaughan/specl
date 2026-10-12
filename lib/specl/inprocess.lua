--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2015-2026 Gary V. Vaughan
]]
--[[--
 Functions for running a Lua program in the Specl Lua interpreter.

 @module specl.inprocess
]]

local find = string.find
local gsub = string.gsub
local sub = string.sub

local compat = require 'specl.compat'
local sandbox = require 'specl.sandbox'
local shell = require 'specl.shell'
local std = require 'specl.std'
local util = require 'specl.util'

local xpcall = compat.xpcall
local Process = shell.Process
local getfenv, setfenv = std.getfenv, std.setfenv
local case, object = std.functional.case, std.object
local clone, merge, unpack = std.table.clone, std.table.merge, std.table.unpack
local nop = util.nop


local Object = object{}

local StrFile = Object{
   _type = 'StrFile',
   _init = {'mode', 'buffer'},

   mode = 'r',
   pos = 1,

   __tostring = function(self)
      -- If not set manually, default `name` to a unique hex address.
      self.name = self.name or gsub(tostring{}, '.*x', '0x')
      return 'strfile (' .. self.name .. '/' .. self.mode .. ')'
   end,

   -- Equivalents to core file object methods.
   __index = {
      close = function(self)
         return nil, 'cannot close standard virtual file'
      end,

      flush = nop,

      lines = function(self, ...)
         local fmts = {...}
         return function()
            return self:read(unpack(fmts))
         end
      end,

      read = function(self, ...)
         -- Obeys the spec, though may not match core file:read
         -- error precisely.
         if self.mode ~= 'r' then
            return nil, 'Bad virtual file descriptor', 9
         end

         local r = {}
         if select('#', ...) == 0 then
            fmts = {'*l'}
         else
            fmts = {...}
         end

         for i = 1, #fmts do
            -- For this format, return an empty string when input is exhausted...
            if fmts[i] == '*a' then
               r[i] = sub(self.buffer, self.pos)
               self.pos = #self.buffer + 1

            -- ...otherwise return nil at end of file.
            elseif self.buffer and self.pos > #self.buffer then
               r[i] = nil

            else
               local b = self.pos
               r[i] = case(fmts[i], {
                  ['*n'] = function()
                     local ok, e, cap = find(self.buffer, '^%s*0[xX](%x+)', b)
                     if ok then
                        self.pos = e + 1
                        return tonumber(cap, 16)
                     end
                     local ok, e = find(self.buffer, '^%s*%d*%.?%d+[eE]%d+', b)
                     if ok then
                        self.pos = e + 1
                        return tonumber(sub(self.buffer, b, e))
                     end
                     local ok, e = find(self.buffer, '^%s*%d*%.?%d+', b)
                     if ok then
                        self.pos = e + 1
                        return tonumber(sub(self.buffer, b, e))
                     end
                     return nil
                  end,

                  ['*l'] = function()
                     local e = find(self.buffer, '\n', self.pos) or #self.buffer
                     self.pos = e + 1
                     return gsub(sub(self.buffer, b, e), '\n$', '')
                  end,

                  ['*L'] = function()
                     local e = find(self.buffer, '\n', self.pos) or #self.buffer
                     self.pos = e + 1
                     return sub(self.buffer, b, e)
                  end,

                  function()
                     if type(fmts[i]) ~= 'number' then
                        return error("bad argument #1 to 'read'(invalid option)", 3)
                     end
                     self.pos = self.pos + fmts[i]
                     return sub(self.buffer, b, self.pos - 1)
                  end,
               })
            end
         end

         if select('#', r) == 0 then
            return nil
         end
         return unpack(r)
      end,

      seek = function(self, whence, offset)
         offset = offset or 0
         self.pos = case(whence or 'cur', {
            set = function()
               return offset + 1
            end,
            cur = function()
               return self.pos + offset
            end,
            ['end'] = function()
               return #self.buffer + offset + 1
            end,
         })
         return self.pos - 1
      end,

      setvbuf = nop,

      write = function(self, ...)
         -- Obeys the spec, though may not match core file:read
         -- error precisely.
         if self.mode ~= 'w' then
            return nil, 'Bad virtual file descriptor', 9
         end
         self.buffer = (self.buffer or '') .. table.concat{...}
         self.pos = #self.buffer + 1
      end,
   },
}


local function inject(into, from)
   for k, v in pairs(from) do
      local tfrom, tinto = type(v), type(into[k])
      if tfrom == 'table' and(tinto == 'table' or tinto == 'nil') then
         into[k] = into[k] or {}
         inject(into[k], from[k])
      else
         into[k] = from[k]
      end
   end
   return into
end


local function env_init(env, stdin)
   -- Captured standard input, standard output and standard error.
   local pin, pout, perr = StrFile{'r', stdin}, StrFile{'w'}, StrFile{'w'}

   -- Keep any other io functions already in *env*.
   env.io = merge(env.io or {}, {
      stdin = pin,
      stdout = pout,
      stderr = perr,

      input = function(h)
         if object.type(h) == 'StrFile' then
            pin = h
         elseif h then
            pin = io.input(h)
         end
         return pin or io.input()
      end,

      output = function(h)
         if h ~= nil then
            if io.type(pout) ~= 'closed file' then
               pout:flush()
            end
            if object.type(h) == 'StrFile' then
               pout = h
            else
               pout = io.output(h)
            end
         end
         return pout or io.output()
      end,

      type = function(h)
         if(getmetatable(h) or {})._type == 'StrFile' then
            return 'file' -- virtual stdio streams cannot be closed
         end
         return io.type(h)
      end,

      write = function(...)
         env.io.output():write(...)
      end,
   })

   -- Capture print statements to process output.
   env.print = function(...)
      local t = {...}
      for i = 1, select('#', ...) do
         t[i] = tostring(t[i])
      end
      env.io.output():write(table.concat(t, '\t') .. '\n')
   end

   return pout, perr
end


-- Return a `require` for *env* that loads Lua modules found on
-- `env.package.path` into *env*, caching them only in *loaded*, so that
-- every module the program loads sees the captured io and os, even
-- ones it saves in locals when first loaded.  Modules not found that
-- way, such as C modules, come from *caller*'s `require` instead.
local function isolated_require(env, caller, loaded)
   return function(modname)
      if loaded[modname] == nil then
         local loader = env.package.preload[modname]
         local filename = compat.searchpath(modname, env.package.path)
         if loader == nil and filename ~= nil then
            loader = assert(compat.loadfile(filename, 't', env))
         end
         if loader == nil then
            loaded[modname] = (caller.require or require)(modname)
         else
            local r = loader(modname, filename)
            if r ~= nil then
               loaded[modname] = r
            elseif loaded[modname] == nil then
               loaded[modname] = true
            end
         end
      end
      return loaded[modname]
   end
end


--- Run a Lua program in-process.
--
-- *fn* runs in an environment where `io`, `os.exit` and `print` are
-- captured, along with every Lua module it loads, which it finds on
-- the calling example's `package.path`.  Calling `os.exit` sets the
-- exit status, as does returning a number; an uncaught error writes a
-- traceback to the captured standard error, and sets exit status 1.
-- @func fn program-like function to act on
-- @tparam table arg command-line arguments for *fn*
-- @string stdin standard input content for *fn*
-- @treturn Process result of executing *fn*, with results of *fn* in
--    its array part
local function capture(fn, arg, stdin)
   arg = arg or {}

   -- Execution environment.
   local caller = getfenv(fn) or {}
   local env = sandbox.new()

   -- Captured standard output and standard error.
   local pstat
   local pout, perr = env_init(env, stdin)

   -- Capture exit status without quitting specl process itself.
   env.os.exit = function(code)
      case(tostring(code), {
         ['false'] = function()
            pstat = 1
         end,
         ['true'] = function()
            pstat = 0
         end,
         function()
            pstat = code
         end,
      })
      -- Abort execution now that status is set.
      error('env.os.exit', 0)
   end

   -- Load modules afresh into the execution environment, from the
   -- calling example's module search paths.
   local callerpackage = caller.package or package
   env.package.path, env.package.cpath = callerpackage.path, callerpackage.cpath
   local loaded = merge({}, env.package.loaded)
   loaded.io, loaded.os = env.io, env.os
   env.package.loaded = loaded
   env.require = isolated_require(env, caller, loaded)

   -- Append traceback to an error inside xpcall.
   local function traceback(errobj)
      if errobj ~= 'env.os.exit' then
         env.io.stderr:write(debug.traceback(errobj, 2))
      end
   end

   setfenv(fn, env)
   local t = {xpcall(fn, traceback, unpack(arg))}
   local ok = table.remove(t, 1)
   if pstat == nil then
      if not ok then
         pstat = 1
      elseif type(t[1]) == 'number' then
         pstat = t[1]
      else
         pstat = 0
      end
   end

   local process = Process{pstat, pout.buffer or '', perr.buffer or ''}
   for i, v in ipairs(t) do
      process[i] = v
   end
   return process
end


--- Run a Lua program in-process.
-- @tparam Main main callable object with an inprocess field
-- @tparam table arg command-line arguments for *main*
-- @string stdin standard input content for *main*
-- @treturn Process result of executing *main*
local function call(main, arg, stdin)
   arg = arg or {}

   -- Execution environment.
   local env = {}

   -- Captured exit status, standard output and standard error.
   local pstat = -1
   local pout, perr = env_init(env, stdin)

   env.os = {
      -- Capture exit status without quitting specl process itself.
      exit = function(code)
         case(tostring(code), {
            ['false'] = function()
               pstat = 1
            end,
            ['true'] = function()
               pstat = 0
            end,
            function()
               pstat = code
            end,
         })
         -- Abort execution now that status is set.
         error('env.os.exit', 0)
      end,
   }

   -- Instantiate with the execution environment so that sandboxed
   -- applications can see and manipulate it before continuing.
   local Main = main(arg, env)

   -- Append traceback to an error inside xpcall.
   local function traceback(errobj)
      if errobj ~= 'env.os.exit' then
         env.io.stderr:write(debug.traceback(errobj, 2))
      end
   end

   -- Diagnose malformed Main object.
   if type(Main.inprocess) ~= 'table' then
      error("malformed 'inprocess' in Main object(table expected, found " ..
             type(Main.inprocess) .. ')')
   end

   -- Set the environment for `execute`, for non-sandboxing apps, so they
   -- have no special steps to take.
   local restore = {
      io = {
         input = Main.inprocess.io.input,
         output = Main.inprocess.io.output,
         stderr = Main.inprocess.io.stderr,
         stdin = Main.inprocess.io.stdin,
         stdout = Main.inprocess.io.stdout,
         type = Main.inprocess.io.type,
         write = Main.inprocess.io.write,
      },
      os = {
         exit = Main.inprocess.os.exit,
      },
      print = Main.inprocess.print,
   }

   inject(Main.inprocess, env)
   local ok, err = xpcall(Main.execute, traceback, Main)
   inject(Main.inprocess, restore)

   if ok then
      pstat = 0
   elseif type(pstat) ~= 'number' then
      pstat = 1
   end

   return Process{pstat, pout.buffer or '', perr.buffer or ''}
end


--[[ = ================ ]]--
--[[ Public Interface. ]]--
--[[ = ================ ]]--

local function X(decl, fn)
   return std.debug.argscheck('specl.inprocess.' .. decl, fn)
end

--- @export
return {
   call = X('call(Main, ?table, ?string)', call),
   capture = X('capture(function, ?table, ?string)', capture),
}
