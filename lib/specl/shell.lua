--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2013-2023 Gary V. Vaughan
]]
--[[--
 Additional commands useful for writing command-line specs.

 @module specl.shell
]]


local _ = {
   matchers = require 'specl.matchers',
   std = require 'specl.std',
}

local _ENV = {
   getmetatable = getmetatable,
   gsub = string.gsub,
   match = string.match,
   pairs = pairs,
   setfenv = function() end,
   tonumber = tonumber,
   tostring = tostring,
   type = type,

   -- Note: this module is loaded from examples, potentially inside a
   -- `specl.inprocess` environment with `io` and `os` tables tweaked
   -- to capture i/o before reaching the console, so it's not safe to
   -- grab individual `io` or `os` table members here.
   io = io,
   os = os,

   table_concat = table.concat,
   table_insert = table.insert,

   matchers = _.matchers,
   object = _.std.object,
   argcheck = _.std.debug.argcheck,
   argscheck = _.std.debug.argscheck,
   escape_pattern = _.std.string.escape_pattern,

   Object = _.std.object {},
}
setfenv(1, _ENV)
_ = nil


local function shell_quote(s)
   return "'" .. gsub(tostring(s), "'", "'\\''") .. "'"
end

--- Description of a shell command.
-- @object Command
-- @tparam string|table params shell command to act on
local Command = Object {
   _type = 'Command',

   _init = function(self, params)
      argcheck('Command', 1, 'string|table', params)

      if type(params) ~= 'table' then
         params = {params}
      end

      local cmd = table_concat(params, ' ')
      local env, stdin = params.env, params.stdin

      -- Flatten the command itself to a string.
      self.cmd = cmd
      if type(cmd) == 'table' then
         -- Subshell is required to make sure redirections are captured,
         -- and environment is already set in time for embedded references.
         self.cmd = table_concat(cmd, ' ')
      end

      -- Subshell is required to make sure redirections are captured,
      -- and environment is already set in time for embedded references.
      self.cmd = 'sh -c ' .. shell_quote(self.cmd)

      -- Use 'env' shell command to set environment variables.
      local t = {}
      for k, v in pairs(env or {}) do
         table_insert(t, k .. '=' .. shell_quote(v))
      end
      if #t > 0 then
         self.cmd = 'env ' .. table_concat(t, ' ') .. ' ' .. self.cmd
      end

      if stdin then
         self.cmd = "printf '%s\\n' " .. gsub(shell_quote(stdin), '\n', "' '") ..
            '|' .. self.cmd
      end

      return self
   end,
}


--- A completed process.
-- @object Process
-- @int status exit status of a command
-- @string output standard output from a command
-- @string errout standard error from a command
local Process = Object {
   _type = 'Process',
   _init = {'status', 'output', 'errout'},
}


--- Run a command in a subprocess
-- @tparam string|table|Command o a shell command to run in a subprocess
-- @treturn Process result of executing *o*
local function spawn(o)
   if(getmetatable(o) or {})._type ~= 'Command' then
      o = Command(o)
   end

   -- Capture stdout and stderr to temporary files.
   local fout = os.tmpname()
   local ferr = os.tmpname()
   local pipe = io.popen(o.cmd .. ' >' .. fout .. ' 2>' .. ferr .. '; printf "$?"')
   local pstat = tonumber(pipe:read())
   pipe:close()

   local hout, herr = io.open(fout), io.open(ferr)
   local pout, perr = hout:read '*a', herr:read '*a'
   hout:close()
   herr:close()
   os.remove(fout)
   os.remove(ferr)

   return Process {pstat, pout, perr}
end



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


-- Register some additional matchers for dealing with the results from
-- a completed process in an expectation.
do
   local Matcher = matchers.Matcher

   local concat = matchers.concat
   local reformat = matchers.reformat
   local matchers = matchers.matchers

   -- Append reformatted output stream content, if it contains anything.
   local function nonempty_output(process)
      if process.output ~= nil and process.output ~= '' then
         return '\nand output:' .. reformat(process.output)
      end
      return ''
   end

   -- Append reformatted error stream content, if it contains anything.
   local function nonempty_errout(process)
      if process.errout ~= nil and process.errout ~= '' then
         return '\nand error:' .. reformat(process.errout)
      end
      return ''
   end

   -- If a shell command fails to meet an expectation, show anything output
   -- to standard error along with the Specl failure message.
   local function but_got_output(self, process)
      return ':' .. reformat(process.output) .. nonempty_errout(process)
   end

   -- If a shell command fails to meet an expectation, show everything output
   -- to standard error.
   local function but_got_errout(self, process)
      return ':' .. reformat(process.errout)
   end

   -- If a shell command fails to match expected exit status, show
   -- anything output to standard error along with the Specl failure
   -- message.
   local function but_got_status(self, process)
      return ' ' .. tostring(process.status) .. nonempty_errout(process)
   end

   -- If a shell command fails to match expected exit status or output,
   -- show anything output to standard error along with the Specl
   -- failure message.
   local function but_got_status_with_output(self, process)
      return ' exit status ' .. tostring(process.status) ..
         ', with output:' .. reformat(process.output) ..
         nonempty_errout(process)
   end


   -- If a shell command fails to match expected exit status or output,
   -- show anything output to standard output along with the Specl
   -- failure message.
   local function but_got_status_with_errout(self, process)
      return ' exit status ' .. tostring(process.status) ..
         ', with error:' .. reformat(process.errout) ..
         nonempty_output(process)
   end


   -- A Matcher requiring a Process object.
   local ProcessMatcher = Matcher {
      _init = {'matchp', 'format_actual'},
      _parmtypes = {'function', 'function'},

      actual_type = 'Process',

      format_expect = function(self, expect)
         return self.expecting .. reformat(expect)
      end,

      format_alternatives = function(self, adaptor, alternatives)
         return self.expecting .. reformat(alternatives, adaptor)
      end,
   }


   --- Matches if the exit status of a Process is *status*.
   -- @matcher exit
   -- @int status expected exit status
   matchers.exit = ProcessMatcher {
      function(self, actual, expect)
         return(actual.status == expect)
      end,

      format_expect = function(self, expect)
         return ' exit status ' .. tostring(expect) .. ', '
      end,

      but_got_status,

      format_alternatives = function(self, adaptor, alternatives)
         return ' an exit status of ' ..
            concat(alternatives, adaptor, ':quoted') .. ', '
      end,
   }


   --- Matches if the exit status of a Process is 0.
   -- @matcher succeed
   matchers.succeed = ProcessMatcher {
      function(self, actual)
         return(actual.status == 0)
      end,

      format_expect = function(self, expect)
         return ' exit status 0, '
      end,

      but_got_status,
   }


   --- Matches if the output of a Process contains *out*.
   -- @matcher contain_output
   -- @string out substring to match against Process output
   matchers.contain_output = ProcessMatcher {
      function(self, actual, expect)
         return match(actual.output or '', escape_pattern(expect)) ~= nil
      end,

      expecting = ' output containing:', but_got_output,
   }


   --- Matches if the process exits normally with output containing *out*
   -- @matcher succeed_while_containing
   -- @string out substring to match against Process output
   matchers.succeed_while_containing = ProcessMatcher {
      function(self, actual, expect)
         return (actual.status == 0) and
            (match(actual.output or '', escape_pattern(expect)) ~= nil)
      end,

      expecting = ' exit status 0, with output containing:',
      but_got_status_with_output,
   }


   --- Matches if the output of a Process is exactly *stdout*.
   --@matcher output
   --@string stdout entire expected Process output
   matchers.output = ProcessMatcher {
      function(self, actual, expect)
         return actual.output == expect
      end,

      expecting = ' output:', but_got_output,
   }


   --- Matches if the Process exits normally with output containing *out*.
   -- @matcher succeed_with
   -- @string out substring to match against Process output
   matchers.succeed_with = ProcessMatcher {
      function(self, actual, expect)
         return(actual.status == 0) and(actual.output == expect)
      end,

      expecting = ' exit status 0, with output:', but_got_status_with_output,
   }


   --- Matches if the output of a Process matches *pattern*.
   -- @matcher match_output
   -- @string pattern match this against Process output
   matchers.match_output = ProcessMatcher {
      function(self, actual, pattern)
         return match(actual.output or '', pattern) ~= nil
      end,

      expecting = ' output matching:', but_got_output,
   }


   --- Matches if the Process exits normally with output matching *pattern*.
   -- @matcher succed_while_matching
   -- @string pattern match this against Process output
   matchers.succeed_while_matching = ProcessMatcher {
      function(self, actual, pattern)
         return (actual.status == 0) and
            (match(actual.output or '', pattern) ~= nil)
      end,

      expecting = ' exit status 0, with output matching:',
      but_got_status_with_output,
   }


   --- Matches if the exit status of a Process is non-zero.
   -- @matcher fail
   matchers.fail = ProcessMatcher {
      function(self, actual)
         return actual.status ~= 0
      end,

      format_expect = function(self, expect)
         return ' non-zero exit status, '
      end,

      but_got_status,
   }


   --- Matches if the error output of a Process contains *err*.
   -- @matcher contain_error
   -- @string err substring to match against Process error output
   matchers.contain_error = ProcessMatcher {
      function(self, actual, expect)
         return match(actual.errout or '', escape_pattern(expect)) ~= nil
      end,

      expecting = ' error output containing:', but_got_errout,
   }


   --- Matches if the Process exits normally containing error output *err*.
   -- @matcher fail_while_containing
   -- @string err substring to match against Process error output
   matchers.fail_while_containing = ProcessMatcher {
      function(self, actual, expect)
         return (actual.status ~= 0) and
            (match(actual.errout or '', escape_pattern(expect)) ~= nil)
      end,

      expecting = ' non-zero exit status, with error output containing:',
      but_got_status_with_errout,
   }


   --- Matches if the error output of a Process is exactly *stderr*.
   -- @matcher output_error
   --@string stderr entire expected Process error output
   matchers.output_error = ProcessMatcher {
      function(self, actual, expect)
         return actual.errout == expect
      end,

      expecting = ' error output:', but_got_errout,
   }


   --- Matches if the Process exits abnormally containing error output *err*.
   -- @matcher fail_with
   -- @string err substring to match against Process error output
   matchers.fail_with = ProcessMatcher {
      function(self, actual, expect)
         return(actual.status ~= 0) and(actual.errout == expect)
      end,

      expecting = ' non-zero exit status, with error:',
      but_got_status_with_errout,
   }


   --- Matches if the error output of a Process matches *pattern*.
   -- @matcher match_error
   -- @string pattern match this against Process error output
   matchers.match_error = ProcessMatcher {
      function(self, actual, pattern)
         return match(actual.errout or '', pattern) ~= nil
      end,

      expecting = ' error output matching:', but_got_errout,
   }


   --- Matches if the Process exits normally with output matching *pattern*.
   -- @matcher fail_while_matching
   -- @string pattern match this against Process error output
   matchers.fail_while_matching = ProcessMatcher {
      function(self, actual, pattern)
         return (actual.status ~= 0) and
            (match(actual.errout or '', pattern) ~= nil)
      end,

      expecting = ' non-zero exit status, with error output matching:',
      but_got_status_with_errout,
   }
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--

local function X(decl, fn)
   return argscheck('specl.shell.' .. decl, fn)
end

--- @export
return {
   Command = Command,
   Process = Process,
   spawn = X('spawn(string|table|Command)', spawn),
}
