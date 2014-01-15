-- Shell and file helpers.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2014 Gary V. Vaughan
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
local std      = require "specl.std"
local util     = require "specl.util"

from std        import Object
from std.string import escape_pattern

local function shell_quote (s)
  return "'" .. tostring (s):gsub ("'", "'\\''") .. "'"
end

-- Massage a command description into a string suitable for executing
-- by the shell.
local Command = Object {
  _type = "Command",

  _init = function (self, params)
    util.type_check ("Command",
      {self, params}, {{"Command", "table"}, {"string", "table"}})

    local kind = Object.type (params)
    if kind == "string" then params = {params} end

    local cmd = table.concat (params, " ")
    local env, stdin = params.env, params.stdin

    -- Flatten the command itstelf to a string.
    self.cmd = cmd
    if Object.type (cmd) == "table" then
      -- Subshell is required to make sure redirections are captured,
      -- and environment is already set in time for embedded references.
      self.cmd = table.concat (cmd, " ")
    end

    -- Subshell is required to make sure redirections are captured,
    -- and environment is already set in time for embedded references.
    self.cmd = "sh -c " .. shell_quote (self.cmd)

    -- Use 'env' shell command to set environment variables.
    local t = {}
    for k, v in pairs (env or {}) do
      table.insert (t, k .. "=" .. shell_quote (v))
    end
    if #t > 0 then
      self.cmd = "env " .. table.concat (t, " ") .. " " .. self.cmd
    end

    if stdin then
      self.cmd = "printf '%s\\n' " .. shell_quote (stdin):gsub ("\n", "' '") ..
                 "|" .. self.cmd
    end

    return self
  end,
}


-- Description of a completed process.
local Process = Object {
  _type = "Process",
  _init = {"status", "output", "errout"},
}


-- Run a command in a subprocess
local function spawn (o)
  util.type_check ("spawn", {o}, {{"string", "table", "Command"}})
  if Object.type (o) ~= "Command" then o = Command (o) end

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
  local concat, reformat, Matcher, matchers =
        matchers.concat, matchers.reformat, matchers.Matcher, matchers.matchers

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

    actual_type   = "Process",

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

    format_alternatives = function (adaptor, alternatives)
      return " an exit status of " ..
             concat (alternatives, adaptor, util.QUOTED) .. ", "
    end,
  }


  -- Matches if the output of a process is exactly <expect>.
  matchers.output = Matcher {
    function (actual, expect)
      return (actual.output == expect)
    end,

    actual_type   = "Process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " output:" .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the error output of a process is exactly <expect>.
  matchers.output_error = Matcher {
    function (actual, expect)
      return (actual.errout == expect)
    end,

    actual_type   = "Process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " error output:" .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the output of a process matches <pattern>.
  matchers.match_output = Matcher {
    function (actual, pattern)
      return (string.match (actual.output, pattern) ~= nil)
    end,

    actual_type   = "Process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output matching:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " output matching:" .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the error output of a process matches <pattern>.
  matchers.match_error = Matcher {
    function (actual, pattern)
      return (string.match (actual.errout, pattern) ~= nil)
    end,

    actual_type   = "Process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output matching:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " error output matching:" .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the output of a process contains <expect>.
  matchers.contain_output = Matcher {
    function (actual, expect)
      return (string.match (actual.output, escape_pattern (expect)) ~= nil)
    end,

    actual_type   = "Process",
    format_actual = process_errout,

    format_expect = function (expect)
      return " output containing:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " output containing:" .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the error output of a process contains <expect>.
  matchers.contain_error = Matcher {
    function (actual, expect)
      return (string.match (actual.errout, escape_pattern (expect)) ~= nil)
    end,

    actual_type   = "Process",
    format_actual = reformat_err,

    format_expect = function (expect)
      return " error output containing:" .. reformat (expect)
    end,

    format_alternatives = function (adaptor, alternatives)
      return " error output containing:" .. reformat (alternatives, adaptor)
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
