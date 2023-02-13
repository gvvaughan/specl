--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2015-2023 Gary V. Vaughan
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
local setfenv = std.setfenv
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

   env.io = {
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
   }

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


--- Run a Lua program in-process
-- @func fn program-like function to act on
-- @tparam table arg command-line arguments for *fn*
-- @string stdin standard input content for *fn*
-- @treturn Process result of executing *fn*
local function capture(fn, arg, stdin)
   arg = arg or {}

   -- Execution environment.
   local env = sandbox.new()

   -- Captured standard output and standard error.
   local pstat = 0
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

   setfenv(fn, env)
   local t = {fn(unpack(arg))}
   local process = Process{pstat, pout.buffer, perr.buffer}
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

   return Process{pstat, pout.buffer, perr.buffer}
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
