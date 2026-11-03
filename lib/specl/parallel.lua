--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2026 Gary V. Vaughan
]]

--[[--
 Run spec files in several processes at once.

 The parent starts the workers, and gives each the next spec file that has
 not been claimed, until there are none.  A worker runs one file with the
 output of its formatter, and everything else that it writes to standard
 output, kept apart, and sends the parent that with the counts of the
 expectations and what the formatter accumulated for its footer.  The parent
 writes the output of each file whole, when the file is done, so that what
 different files write never mixes, and writes one footer for all of them.

 It needs the luaposix modules that make processes and pipes, which the
 specl that has none of them does not use for anything else.

 @module specl.parallel
]]

local fileno = require 'posix.stdio'.fileno
local poll = require 'posix.poll'.poll
local unistd = require 'posix.unistd'
local wait = require 'posix.sys.wait'.wait

local find, format, match, sub = string.find, string.format, string.match, string.sub

local runner = require 'specl.runner'

local load = loadstring or load


local M = {}


-- Text that `load` makes into VALUE again, for strings, numbers, booleans and
-- tables of them.
local function serialize(value)
   local t = type(value)
   if t == 'table' then
      local parts = {}
      for k, v in pairs(value) do
         parts[#parts + 1] = '[' .. serialize(k) .. ']=' .. serialize(v)
      end
      return '{' .. table.concat(parts, ',') .. '}'
   elseif t == 'string' then
      return format('%q', value)
   end
   return tostring(value)
end


local function deserialize(text)
   local chunk = load('return ' .. text)
   return chunk and chunk()
end


-- Write all of S to the file descriptor FD.
local function write_all(fd, s)
   while #s > 0 do
      local n = unistd.write(fd, s)
      if not n then
         return false
      end
      s = sub(s, n + 1)
   end
   return true
end


--- The arguments of each spec file, which are the line filters that are before
-- it, and the file.
-- @tparam {string,...} args the arguments after the options
-- @treturn {{string,...},...} the arguments of each
function M.units(args)
   local units, filters = {}, {}
   for _, v in ipairs(args) do
      filters[#filters + 1] = v
      if not match(v, '^%+%d+$') then
         units[#units + 1] = filters
         filters = {}
      end
   end
   return units
end


-- The name of the spec file of a unit.
local function filename(unit)
   return unit[#unit]
end


-- Run the spec file of UNIT in this process, with what is written to standard
-- output kept in the result that is returned.
local function run_unit(state, parser, unit)
   state.arg = unit
   state.specs = {}
   state.filters = nil
   state.accumulated = nil
   state.stats = {pass = 0, pend = 0, fail = 0, starttime = state.stats.starttime}

   local out = io.tmpfile()
   io.stdout:flush()
   unistd.dup2(fileno(out), unistd.STDOUT_FILENO)

   local ok, err = pcall(function()
      state:process_args(parser)
      runner.run_specs(state)
   end)

   io.stdout:flush()
   out:seek 'set'
   local text = out:read '*a'
   out:close()

   return {
      out = text,
      stats = {pass = state.stats.pass, pend = state.stats.pend, fail = state.stats.fail},
      accumulated = state.accumulated,
      error = not ok and tostring(err) or nil,
   }
end


-- The number that is on the first line of what is read from FD, or nil at the
-- end of it.
local function read_number(fd)
   local line = ''
   while true do
      local c = unistd.read(fd, 1)
      if c == nil or c == '' then
         return nil
      elseif c == '\n' then
         return tonumber(line)
      end
      line = line .. c
   end
end


-- What a worker does in the process that is made for it: run each unit that
-- the parent sends the number of, and send the result back, until the parent
-- closes the pipe.
local function work(state, parser, units, w)
   while true do
      local n = read_number(w.cmd_r)
      if not n then
         break
      end
      local payload = serialize(run_unit(state, parser, units[n]))
      if not write_all(w.res_w, #payload .. '\n' .. payload) then
         break
      end
   end
   unistd._exit(0)
end


-- Start a worker, whose pipes are with the others in WORKERS, that are not
-- needed in its process.
local function spawn(state, parser, units, workers)
   local cmd_r, cmd_w = unistd.pipe()
   local res_r, res_w = unistd.pipe()
   io.stdout:flush()
   local pid = unistd.fork()
   assert(pid, 'could not start a worker')

   local w = {pid = pid, cmd_r = cmd_r, cmd_w = cmd_w, res_r = res_r, res_w = res_w, buf = ''}
   if pid == 0 then
      -- Only the parent has the ends of the pipes of the others, and its own;
      -- if the worker kept them, the others would not see the end of theirs.
      for other in pairs(workers) do
         unistd.close(other.cmd_w)
         unistd.close(other.res_r)
      end
      unistd.close(cmd_w)
      unistd.close(res_r)
      work(state, parser, units, w)
   end

   unistd.close(cmd_r)
   unistd.close(res_w)
   workers[w] = true
   return w
end


-- The complete results that are in the buffer of W, which are each a number,
-- a newline, and as many bytes as the number is.
local function results(w)
   local out = {}
   while true do
      local nl = find(w.buf, '\n', 1, true)
      local len = nl and tonumber(sub(w.buf, 1, nl - 1))
      if not len or #w.buf < nl + len then
         return out
      end
      out[#out + 1] = deserialize(sub(w.buf, nl + 1, nl + len))
      w.buf = sub(w.buf, nl + len + 1)
   end
end


--- Run spec files, several at a time, and report on all of them.
-- @tparam Main state the state of the run, which has the options
-- @tparam optparse parser the parser that read the options
-- @tparam {{string,...},...} units the arguments of each spec file
-- @int jobs how many to run at once
-- @treturn int the exit status
function M.run(state, parser, units, jobs)
   local formatter = state.opts.formatter
   local workers, live, next_unit, crashed = {}, 0, 1, 0
   local stopping = false

   runner.prepare(state)
   state.accumulated = nil
   state:accumulator(formatter.header(state.stats, state.opts))

   -- Give W the next unit that no worker has, or tell it that there are none.
   local function assign(w)
      if next_unit <= #units and not stopping then
         w.unit = next_unit
         next_unit = next_unit + 1
         write_all(w.cmd_w, w.unit .. '\n')
      else
         w.unit = nil
         if w.cmd_w then
            unistd.close(w.cmd_w)
            w.cmd_w = nil
         end
      end
   end

   -- Show a result, and add it to the counts.
   local function collect(w, result)
      io.stdout:write(result.out)
      io.stdout:flush()
      state.stats.pass = state.stats.pass + result.stats.pass
      state.stats.pend = state.stats.pend + result.stats.pend
      state.stats.fail = state.stats.fail + result.stats.fail
      state:accumulator(result.accumulated)
      if result.error then
         crashed = crashed + 1
         io.stderr:write('specl: ' .. filename(units[w.unit]) .. ': ' .. result.error .. '\n')
      end
      if result.stats.fail > 0 and state.opts.fail_fast then
         stopping = true
      end
   end

   -- A worker whose pipe has ended is gone, with its unit if it had one.
   local function finish(w)
      if w.unit then
         crashed = crashed + 1
         io.stderr:write('specl: ' .. filename(units[w.unit]) .. ': the worker ended before it was done\n')
         w.unit = nil
      end
      if w.cmd_w then
         unistd.close(w.cmd_w)
      end
      unistd.close(w.res_r)
      wait(w.pid)
      workers[w] = nil
      live = live - 1
   end

   for _ = 1, math.min(jobs, #units) do
      live = live + 1
      assign(spawn(state, parser, units, workers))
   end

   while live > 0 do
      local fds, asked = {}, {}
      for w in pairs(workers) do
         fds[w.res_r] = {events = {IN = true}}
         asked[#asked + 1] = w
      end
      poll(fds, -1)

      for _, w in ipairs(asked) do
         local ready = fds[w.res_r].revents
         if ready and (ready.IN or ready.HUP or ready.ERR) then
            local chunk = unistd.read(w.res_r, 65536)
            if chunk == nil or chunk == '' then
               finish(w)
               -- Another takes over what it had to do, if there is more.
               if next_unit <= #units and not stopping and live < jobs then
                  live = live + 1
                  assign(spawn(state, parser, units, workers))
               end
            else
               w.buf = w.buf .. chunk
               for _, result in ipairs(results(w)) do
                  collect(w, result)
                  assign(w)
               end
            end
         end
      end
   end

   formatter.footer(state.stats, state.accumulated, state.opts)
   return (state.stats.fail ~= 0 or crashed ~= 0) and 1 or 0
end


return M
