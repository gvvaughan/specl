-- Shell and file helpers.
--
-- Copyright (c) 2013 Free Software Foundation, Inc.
-- Written by Gary V. Vaughan, 2013
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

-- Additional commands useful for writing command-line specs.

local util     = require "specl.util"
local matchers = require "specl.matchers"

local type = util.typeof
local q    = matchers.q

local function shell_quote (s)
  return "'" .. tostring (s):gsub ("'", "'\\''") .. "'"
end

-- Massage a command description into a string suitable for executing
-- by the shell.
local Command = util.Object {"command";
  _init = function (self, params)
    util.type_check ("Command",
      {self, params}, {"command", {"string", "table"}})

    local kind = type (params)
    if kind == "string" then params = {params} end

    local cmd = table.concat (params, " ")
    local env, stdin = params.env, params.stdin

    -- Flatten the command itstelf to a string.
    self.cmd = cmd
    if type (cmd) == "table" then
      -- Subshell is required to make sure redirections are captured,
      -- and environment is already set in time for embedded references.
      self.cmd = table.concat (cmd, " ")
    end

    -- Subshell is required to make sure redirections are captured,
    -- and environment is already set in time for embedded references.
    self.cmd = "sh -c " .. shell_quote (self.cmd)

    -- Make sure package search path is passed through.
    env = env or {}
    if env.LUA_PATH then
      env.LUA_PATH = env.LUA_PATH .. ";" .. package.path
    else
      env.LUA_PATH = package.path
    end

    -- Use 'env' shell command to set environment variables.
    local t = {}
    for k, v in pairs (env) do
      table.insert (t, k .. "=" .. shell_quote (v))
    end
    self.cmd = "env " .. table.concat (t, " ") .. " " .. self.cmd

    if stdin then
      self.cmd = "printf '%s\\n' " .. shell_quote (stdin):gsub ("\n", "' '") ..
                 "|" .. self.cmd
    end

    return self
  end,
}


-- Description of a completed process.
local Process = util.Object { "process";
  _init = {"status", "output", "errout"},
  __index = util.Object,
}


-- Run a command in a subprocess
local function spawn (o)
  util.type_check ("spawn", {o}, {{"string", "table", "command"}})
  if type (o) ~= "command" then o = Command (o) end

  -- Capture stdout and stderr to temporary files.
  local fout = os.tmpname ()
  local ferr = os.tmpname ()
  local pipe  = io.popen (o.cmd .. " >" .. fout .. " 2>" .. ferr .. '; printf "$?"')
  local pstat = tonumber (pipe:read ())
  pipe:close ()

  local hout, herr = io.open (fout), io.open (ferr)
  local pout, perr = hout:read "*a", herr:read "*a"
  hout:close ()
  herr:close ()
  os.remove (fout)
  os.remove (ferr)

  return Process {pstat, pout, perr}
end



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


local function with_errout (process)
  if process.errout ~= nil and process.errout ~= "" then
    return ' and error:"\n' .. process.errout .. '"'
  end
  return ""
end


matchers.matchers.exit = function (value, expected)
  if type (value) ~= "process" then
    error ("'exit' matcher: process expected, but got " .. type (value))
  end
  local m = "expecting exit status " .. q(expected) .. ", but got " .. q(value.status)
  return (value.status == expected), m .. with_errout (value)
end


matchers.matchers.output = function (value, expected)
  if type (value) ~= "process" then
    error ("'output' matcher: process expected, but got " .. type (value))
  end
  m = "expecting output " .. q(expected) .. ", but got ".. q(value.output)
  return (value.output == expected), m .. with_errout (value)
end


matchers.matchers.match_output = function (value, pattern)
  if type (value) ~= "process" then
    error ("'match_output' matcher: process expected, but got " .. type (value))
  end
  local m = "expecting output matching " .. q(pattern) .. ", but got " ..
            q(value.output)
  return (string.match (value.output, pattern) ~= nil), m .. with_errout (value)
end


matchers.matchers.contain_output = function (value, expected)
  if type (value) ~= "process" then
    error ("'contain_output' matcher: process expected, but got " .. type (value))
  end
  local pattern = expected:gsub ("%W", "%%%0")
  local m = "expecting output containing " .. q(expected) .. ", but got " ..
            q(value.output)
  return (string.match (value.output, pattern) ~= nil), m .. with_errout (value)
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  Command = Command,
  Process = Process,

  spawn   = spawn,
}
