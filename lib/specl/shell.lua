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


from "specl.std"  import Object, string.escape_pattern
from "specl.util" import type_check


local function shell_quote (s)
  return "'" .. tostring (s):gsub ("'", "'\\''") .. "'"
end

-- Massage a command description into a string suitable for executing
-- by the shell.
local Command = Object {
  _type = "Command",

  _init = function (self, params)
    type_check ("Command",
      {self, params}, {{"Command", "table"}, {"string", "table"}})

    local kind = Object.type (params)
    if kind == "string" then params = {params} end

    local cmd = table.concat (params, " ")
    local env, stdin = params.env, params.stdin

    -- Flatten the command itself to a string.
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
  type_check ("spawn", {o}, {{"string", "table", "Command"}})
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
  local matchers = require "specl.matchers"

  local concat, reformat, Matcher, matchers =
        matchers.concat, matchers.reformat, matchers.Matcher, matchers.matchers

  -- Append reformatted output stream content, if it contains anything.
  local function nonempty_output (process)
    if process.output ~= nil and process.output ~= "" then
      return "\nand output:" .. reformat (process.output)
    end
    return ""
  end

  -- Append reformatted error stream content, if it contains anything.
  local function nonempty_errout (process)
    if process.errout ~= nil and process.errout ~= "" then
      return "\nand error:" .. reformat (process.errout)
    end
    return ""
  end

  -- If a shell command fails to meet an expectation, show anything output
  -- to standard error along with the Specl failure message.
  local function but_got_output (self, process)
    return ":" .. reformat (process.output) .. nonempty_errout (process)
  end

  -- If a shell command fails to meet an expectation, show everything output
  -- to standard error.
  local function but_got_errout (self, process)
    return ":" .. reformat (process.errout)
  end

  -- If a shell command fails to match expected exit status, show
  -- anything output to standard error along with the Specl failure
  -- message.
  local function but_got_status (self, process)
    return " " .. tostring (process.status) .. nonempty_errout (process)
  end

  -- If a shell command fails to match expected exit status or output,
  -- show anything output to standard error along with the Specl
  -- failure message.
  local function but_got_status_with_output (self, process)
    return " exit status " .. tostring (process.status) ..
           ", with output:" .. reformat (process.output) ..
	   nonempty_errout (process)
  end


  -- If a shell command fails to match expected exit status or output,
  -- show anything output to standard output along with the Specl
  -- failure message.
  local function but_got_status_with_errout (self, process)
    return " exit status " .. tostring (process.status) ..
           ", with error:" .. reformat (process.errout) ..
	   nonempty_output (process)
  end


  -- A Matcher requiring a Process object.
  local ProcessMatcher = Matcher {
    _init       = {"matchp",   "format_actual"},
    _parmtypes  = {"function", "function"     },

    actual_type = "Process",

    format_expect = function (self, expect)
      return self.expecting .. reformat (expect)
    end,

    format_alternatives = function (self, adaptor, alternatives)
      return self.expecting .. reformat (alternatives, adaptor)
    end,
  }


  -- Matches if the exit status of a process is <expect>.
  matchers.exit = ProcessMatcher {
    function (self, actual, expect)
      return (actual.status == expect)
    end,

    format_expect = function (self, expect)
      return " exit status " .. tostring (expect) .. ", "
    end,

    but_got_status,

    format_alternatives = function (self, adaptor, alternatives)
      return " an exit status of " ..
             concat (alternatives, adaptor, ":quoted") .. ", "
    end,
  }


  -- Matches if the exit status of a process is 0.
  matchers.succeed = ProcessMatcher {
    function (self, actual)
      return (actual.status == 0)
    end,

    format_expect = function (self, expect)
      return " exit status 0, "
    end,

    but_got_status,
  }


  -- Matches if the output of a process contains <expect>.
  matchers.contain_output = ProcessMatcher {
    function (self, actual, expect)
      return (string.match (actual.output, escape_pattern (expect)) ~= nil)
    end,

    expecting = " output containing:", but_got_output,
  }


  -- Matches if the process exits normally with output containing <expect>
  matchers.succeed_while_containing = ProcessMatcher {
    function (self, actual, expect)
      return (actual.status == 0) and (string.match (actual.output, escape_pattern (expect)) ~= nil)
    end,

    expecting =  " exit status 0, with output containing:", 
    but_got_status_with_output,
  }


  -- Matches if the output of a process is exactly <expect>.
  matchers.output = ProcessMatcher {
    function (self, actual, expect)
      return (actual.output == expect)
    end,

    expecting = " output:", but_got_output,
  }


  -- Matches if the process exits normally with output <expect>
  matchers.succeed_with = ProcessMatcher {
    function (self, actual, expect)
      return (actual.status == 0) and (actual.output == expect)
    end,

    expecting = " exit status 0, with output:", but_got_status_with_output,
  }


  -- Matches if the output of a process matches <pattern>.
  matchers.match_output = ProcessMatcher {
    function (self, actual, pattern)
      return (string.match (actual.output, pattern) ~= nil)
    end,

    expecting = " output matching:", but_got_output,
  }


  -- Matches if the process exits normally with output matching <expect>
  matchers.succeed_while_matching = ProcessMatcher {
    function (self, actual, pattern)
      return (actual.status == 0) and (string.match (actual.output, pattern) ~= nil)
    end,

    expecting = " exit status 0, with output matching:",
    but_got_status_with_output,
  }


  -- Matches if the exit status of a process is <expect>.
  matchers.fail = ProcessMatcher {
    function (self, actual)
      return (actual.status ~= 0)
    end,

    format_expect = function (self, expect)
      return " non-zero exit status, "
    end,

    but_got_status,
  }


  -- Matches if the error output of a process contains <expect>.
  matchers.contain_error = ProcessMatcher {
    function (self, actual, expect)
      return (string.match (actual.errout, escape_pattern (expect)) ~= nil)
    end,

    expecting = " error output containing:", but_got_errout,
  }


  -- Matches if the process exits normally with output containing <expect>
  matchers.fail_while_containing = ProcessMatcher {
    function (self, actual, expect)
      return (actual.status ~= 0) and (string.match (actual.errout, escape_pattern (expect)) ~= nil)
    end,

    expecting = " non-zero exit status, with error output containing:",
    but_got_status_with_errout,
  }


  -- Matches if the error output of a process is exactly <expect>.
  matchers.output_error = ProcessMatcher {
    function (self, actual, expect)
      return (actual.errout == expect)
    end,

    expecting = " error output:", but_got_errout,
  }


  -- Matches if the process exits abnormally with error output <expect>
  matchers.fail_with = ProcessMatcher {
    function (self, actual, expect)
      return (actual.status ~= 0) and (actual.errout == expect)
    end,

    expecting = " non-zero exit status, with error:",
    but_got_status_with_errout,
  }


  -- Matches if the error output of a process matches <pattern>.
  matchers.match_error = ProcessMatcher {
    function (self, actual, pattern)
      return (string.match (actual.errout, pattern) ~= nil)
    end,

    expecting = " error output matching:", but_got_errout,
  }


  -- Matches if the process exits normally with output matching <expect>
  matchers.fail_while_matching = ProcessMatcher {
    function (self, actual, pattern)
      return (actual.status ~= 0) and (string.match (actual.errout, pattern) ~= nil)
    end,

    expecting = " non-zero exit status, with error output matching:",
    but_got_status_with_errout,
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
