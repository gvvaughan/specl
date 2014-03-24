-- In process Lua programs.
-- Written by Gary V. Vaughan, 2014
--
-- Copyright (c) 2014 Gary V. Vaughan
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


local compat = require "specl.compat"
local hell   = require "specl.shell"
local std    = require "specl.std"
local util   = require "specl.util"

from compat    import setfenv
from hell      import Process
from std.func  import case
from std.table import clone, merge
from util      import nop


local StrFile = std.Object {
  _type = "StrFile",
  _init = {"mode", "buffer"},

  mode   = "r",
  pos    = 1,

  __tostring = function (self)
    -- If not set manually, default `name` to a unique hex address.
    self.name = self.name or tostring ({}):gsub (".*x", "0x")
    return "strfile (" .. self.name .. "/" .. self.mode .. ")"
  end,

  -- Equivalents to core file object methods.
  __index = {
    close   = function (self)
                return nil, "cannot close standard virtual file"
              end,

    flush   = nop,

    lines   = nop,

    read    = function (self, mode)
                -- Obeys the spec, though may not match core file:read
                -- error precisely.
                if self.mode ~= "r" then
                  return nil, "Bad virtual file descriptor", 9
                end
                local b = self.pos
                return case (mode or "*l", {
                  ["*n"] = function ()
                             local ok, e = self.buffer:find ("^%d*%.?%d+")
                             if ok then
                               self.pos = e + 1
                               return tonumber (self.buffer:sub (b, e))
                             end
                             local ok, e = self.buffer:find ("^0[xX]%x*%.?%x+")
                             if ok then
                               self.pos = e + 1
                               return tonumber (self.buffer:sub (b, e), 16)
                             end
                             return nil
                           end,

                  ["*a"] = function ()
                             self.pos = #self.buffer + 1
                             return self.buffer:sub (b)
                           end,

                  ["*l"] = function ()
                             local e = self.buffer:find ("\n", self.pos) or #self.buffer
                             self.pos = e + 1
                             return self.buffer:sub (b, e):gsub ("\n$", "")
                           end,

                  ["*L"] = function ()
                             local e = self.buffer:find ("\n", self.pos) or #self.buffer
                             self.pos = e + 1
                             return self.buffer:sub (b, e)
                           end,

                           function ()
                             if type (mode) ~= "number" then
                               return error ("bad argument #1 to 'read' (invalid option)", 3)
                             end
                             self.pos = self.pos + mode
                             return self.buffer:sub (b, self.pos - 1)
                           end,
                })
              end,

    seek    = function (self, whence, offset)
                offset = offset or 0
                self.pos = case (whence or "cur", {
                  set     = function () return offset + 1                end,
                  cur     = function () return self.pos + offset         end,
                  ["end"] = function () return #self.buffer + offset + 1 end,
                })
                return self.pos - 1
              end,

    setvbuf = nop,

    write   = function (self, ...)
                -- Obeys the spec, though may not match core file:read
                -- error precisely.
                if self.mode ~= "w" then
                  return nil, "Bad virtual file descriptor", 9
                end
                self.buffer = (self.buffer or "") .. table.concat {...}
                self.pos = #self.buffer + 1
              end,
  },
}


local function inject (into, from)
  for k, v in pairs (from) do
    local tfrom, tinto = type (v), type (into[k])
    if tfrom == "table" and (tinto == "table" or tinto == "nil") then
      into[k] = into[k] or {}
      inject (into[k], from[k])
    else
      into[k] = from[k]
    end
  end
  return into
end


-- Run a Lua program in-process
local function call (main, arg, stdin)
  util.type_check ("call", {main}, {"Main"})
  arg = arg or {}

  -- Captured exit status, standard input, standard output and standard error.
  local pstat = -1
  local pin, pout, perr = StrFile {"r", stdin}, StrFile {"w"}, StrFile {"w"}

  -- Execution environment.
  local env = {}

  env.io = {
    stdin   = pin,
    stdout  = pout,
    stderr  = perr,

    input   = function (h)
                if std.Object.type (h) == "StrFile" then
                  pin = h
                elseif h then
                  io.input (h)
                else
                  return pin or io.input ()
                end
              end,

    output  = function (h)
                if std.Object.type (h) == "StrFile" then
                  pout = h
                elseif h then
                  io.output (h)
                else
                  return pout or io.output ()
                end
              end,

    type    = function (h)
                if std.Object.type (h) == "StrFile" then
                  return "file" -- virtual stdio streams cannot be closed
                end
                return io.type (h)
              end,

    write   = function (...)
                env.io.output ():write (...)
              end,
  }

  env.os = {
    -- Capture exit status without quitting specl process itself.
    exit = function (code)
             case (tostring (code), {
               ["false"] = function () pstat = 1 end,
               ["true"]  = function () pstat = 0 end,
                           function () pstat = code end,
             })
             -- Abort execution now that status is set.
             error ("env.os.exit", 0)
           end,
  }

  -- Capture print statements to process output.
  env.print = function (...)
                local t = {...}
                for i = 1, select ("#", ...) do t[i] = tostring (t[i]) end
                env.io.output ():write (table.concat (t, "\t") .. "\n")
              end

  -- Instantiate with the execution environment so that sandboxed
  -- applications can see and manipulate it before continuing.
  local Main = main (arg, env)

  -- Append traceback to an error inside xpcall.
  local function traceback (errobj)
    if errobj ~= "env.os.exit" then
      env.io.stderr:write (debug.traceback (errobj, 2))
    end
  end

  -- Diagnose malformed Main object.
  if type (Main.inprocess) ~= "table" then
    error ("malformed 'inprocess' in Main object (table expected, found " ..
           type (Main.inprocess) .. ")")
  end

  -- Set the environment for `execute`, for non-sandboxing apps, so they
  -- have no special steps to take.
  local restore = {
    io = {
      input  = Main.inprocess.io.input,
      output = Main.inprocess.io.output,
      stderr = Main.inprocess.io.stderr,
      stdin  = Main.inprocess.io.stdin,
      stdout = Main.inprocess.io.stdout,
      type   = Main.inprocess.io.type,
      write  = Main.inprocess.io.write,
    },
    os = {
      exit   = Main.inprocess.os.exit,
    },
    print    = Main.inprocess.print,
  }

  inject (Main.inprocess, env)
  local ok, err = xpcall (Main.execute, traceback, Main)
  inject (Main.inprocess, restore)

  if ok then
    pstat = 0
  elseif type (pstat) ~= "number" then
    pstat = 1
  end

  return Process {pstat, pout.buffer, perr.buffer}
end


return {
  call = call,
}
