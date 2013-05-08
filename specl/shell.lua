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

local matchers = require "specl.matchers"
local util     = require "specl.util"

local type = util.typeof

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


-- Register some additional matchers for dealing with the results from
-- a completed process in an expectation.
do
  local reformat, Matcher, matchers =
        matchers.reformat, matchers.Matcher, matchers.matchers

  -- Long format shell output formatting.
  local function concat (alternatives)
    local m = ""
    for _, expect in ipairs (alternatives) do
      m = m .. "or:" .. reformat (expect) .. "\n"
    end
    return m:gsub ("^or:", "")
  end


  -- If a shell command fails to meet an expectation, show anything output
  -- to standard error along with the Specl failure message.
  local function process_errout (process)
    local m = ":" .. reformat (process.output)
    if process.errout ~= nil and process.errout ~= "" then
      return m .. "\nand error:" .. reformat (process.errout)
    end
    return m
  end


  -- Reformat process error output with the reformat() function.
  local function reformat_err (process)
    return ":" .. reformat (process.errout)
  end


  -- Matches if the exit status of a process is <expect>.
  matchers.exit = Matcher {
    function (actual, expect)
      return (actual.status == expect)
    end,

    actual_type   = "process",

    format_actual = function (process)
      local m = " " .. tostring (process.status)
      if process.errout ~= nil and process.errout ~= "" then
        return m .. "\nand error:" .. reformat (process.errout)
      end
      return m
    end,

    format_expect = function (expect)
      return " exit status " .. tostring (expect) .. ", "
    end,

    format_one_of = function (alternatives)
      return " an exit status of " .. util.concat (alternatives, util.QUOTED) .. ", "
    end,
  }


  -- Matches if the output of a process is exactly <expect>.
  matchers.output = Matcher {
    function (actual, expect)
      return (actual.output == expect)
    end,

    actual_type   = "process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " output:" .. concat (alternatives)
    end,
  }


  -- Matches if the error output of a process is exactly <expect>.
  matchers.output_error = Matcher {
    function (actual, expect)
      return (actual.errout == expect)
    end,

    actual_type   = "process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " error output:" .. concat (alternatives)
    end,
  }


  -- Matches if the output of a process matches <pattern>.
  matchers.match_output = Matcher {
    function (actual, pattern)
      return (string.match (actual.output, pattern) ~= nil)
    end,

    actual_type   = "process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output matching:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " output matching:" .. concat (alternatives)
    end,
  }


  -- Matches if the error output of a process matches <pattern>.
  matchers.match_error = Matcher {
    function (actual, pattern)
      return (string.match (actual.errout, pattern) ~= nil)
    end,

    actual_type   = "process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output matching:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " error output matching:" .. concat (alternatives)
    end,
  }


  -- Matches if the output of a process contains <expect>.
  matchers.contain_output = Matcher {
    function (actual, expect)
      local pattern = expect:gsub ("%W", "%%%0")
      return (string.match (actual.output, pattern) ~= nil)
    end,

    actual_type   = "process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output containing:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " output containing:" .. concat (alternatives)
    end,
  }


  -- Matches if the error output of a process contains <expect>.
  matchers.contain_error = Matcher {
    function (actual, expect)
      local pattern = expect:gsub ("%W", "%%%0")
      return (string.match (actual.errout, pattern) ~= nil)
    end,

    actual_type   = "process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output containing:" .. reformat (expect) .. "\n"
    end,

    format_one_of = function (alternatives)
      return " error output containing:" .. concat (alternatives)
    end,
  }
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  Command = Command,
  Process = Process,

  spawn   = spawn,
}
