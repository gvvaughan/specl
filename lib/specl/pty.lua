--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2026 Gary V. Vaughan
]]

--[[--
 Run programs on a pseudo-terminal, for specs of what needs a terminal.

 Programs that draw on a terminal, or read keys from one, need one to be
 tested.  `run` forks a child process that has a new pseudo-terminal for its
 standard input, output and error, calls a function there, and returns what
 the function returned and what it wrote to the terminal.  `start` runs a
 program on a pseudo-terminal, which it keeps, so that a spec can type at
 the program, and look at what the program has drawn, as a person would.

 When the `lvterm` virtual terminal library can be loaded, what a program
 writes is fed to one, so that the screen can be checked with the matchers
 of `specl.screen`.  Without it the output is still returned.

 It needs the luaposix modules that make pseudo-terminals and processes.

 @module specl.pty
]]

local fcntl = require 'posix.fcntl'
local poll = require 'posix.poll'
local signal = require 'posix.signal'
local stdlib = require 'posix.stdlib'
local time = require 'posix.sys.time'
local termio = require 'posix.termio'
local unistd = require 'posix.unistd'
local wait = require 'posix.sys.wait'

local concat, format, sub = table.concat, string.format, string.sub


local load = loadstring or load
local pack = table.pack or function(...) return {n = select('#', ...), ...} end
local unpack = table.unpack or unpack


local defaults = {
   term = 'xterm',
   lines = 24,
   columns = 80,
   timeout = 10000,  -- milliseconds that the function of `run` may take
}


local M = {}


-- The virtual terminal library, or false if there is none.  This is specl's
-- own copy, which is not the copy of the project that the examples test, if
-- that is lvterm.  Both can be in one process if the C backend makes
-- this one, as the C modules of luaposix can, but not if the LuaJIT ffi does,
-- as the C types that it declares are the same for all of the process.
local function find_lvterm()
   local wanted = os.getenv 'LVTERM_BACKEND'
   if wanted == nil or wanted == '' then
      stdlib.setenv('LVTERM_BACKEND', 'core')
      local ok, lib = pcall(require, 'lvterm')
      stdlib.setenv('LVTERM_BACKEND')
      if ok then
         return lib
      end
   end
   local ok, lib = pcall(require, 'lvterm')
   return ok and lib
end

--- The `lvterm` library that screens are made with, or false if there is
-- none.
-- @field lvterm
M.lvterm = find_lvterm()


-- OPTIONS with what is not in it from the defaults.
local function settings(options)
   local all = {}
   for k, v in next, defaults do
      all[k] = v
   end
   for k, v in next, options or {} do
      all[k] = v
   end
   return all
end


-- Write all of S to the file descriptor FD.
local function writeall(fd, s)
   while #s > 0 do
      s = sub(s, unistd.write(fd, s) + 1)
   end
end


-- The milliseconds since some moment, which only differences of mean
-- anything.
local function now()
   local t = time.gettimeofday()
   return t.tv_sec * 1000 + t.tv_usec / 1000
end


-- The sessions that have not been stopped, by the master of each.  A
-- child that is forked now must not keep the masters of the others: it would
-- hold on to their terminals until it ended.  Each has the process of
-- its program, whether that has been waited for, and a weak reference to the
-- session, to tell when nothing else refers to it.  Specl loads its modules
-- again for each example, so this is in the registry to be the same for all.
local registry = debug.getregistry()
local owned = registry['specl.pty']
if not owned then
   owned = {}
   registry['specl.pty'] = owned
end



-- How many sessions that have not been stopped are too many to leave be.
-- Whatever an example does not stop would use up all of the
-- pseudo-terminals of the host, if a run of many spec files was in one
-- process.
local CROWDED = 32

local function crowded()
   local n = 0
   for _ in next, owned do
      n = n + 1
   end
   return n >= CROWDED
end


--- Stop the sessions that nothing refers to any more.
-- A session that an example does not stop is stopped here, and so is it
-- when `start` finds that there are very many.  This is not left to the
-- collector, as what it runs, when it chooses to, is not safe to use
-- the libraries of the process with.
function M.reap()
   collectgarbage()
   for master, entry in next, owned do
      if entry.ref[1] == nil then
         if not entry.exited then
            pcall(signal.kill, entry.pid, signal.SIGKILL)
            pcall(wait.wait, entry.pid)
         end
         pcall(unistd.close, master)
         owned[master] = nil
      end
   end
end


-- Open a pseudo-terminal, as big as OPTIONS say, and return the descriptor
-- of its master side, the name of its slave side, and a descriptor that keeps
-- the slave side open.
local function open_pty(options)
   if crowded() then
      M.reap()
   end
   local master = assert(stdlib.openpt(fcntl.O_RDWR + fcntl.O_NOCTTY))
   assert(stdlib.grantpt(master))
   assert(stdlib.unlockpt(master))
   local slave = assert(stdlib.ptsname(master))

   -- Only a terminal that has a slave side open has a size to change, and a
   -- program that asks for it, rather than using LINES and COLUMNS, must
   -- not find none.  The master of one that has had its slave side closed
   -- is hung up, so it stays open until the child has its own.
   local tty = assert(fcntl.open(slave, fcntl.O_RDWR + fcntl.O_NOCTTY))
   termio.tcsetwinsize(tty, {ws_row = options.lines, ws_col = options.columns})
   return master, slave, tty
end


-- The environment of what runs on the terminal, which is OPTIONS.
local function setenvs(options)
   stdlib.setenv('TERM', options.term)
   stdlib.setenv('LINES', tostring(options.lines))
   stdlib.setenv('COLUMNS', tostring(options.columns))
   for name, value in next, options.env or {} do
      stdlib.setenv(name, value)
   end
end


-- Fork a process that has the slave side of a pseudo-terminal for its
-- terminal, and call CHILD there, with its master side closed, as are the
-- masters of all of the others.  Return the process.  KEEP, which is open
-- on the slave side, is closed after.
local function spawn(options, master, slave, keep, child)
   io.stdout:flush()
   io.stderr:flush()
   local pid = assert(unistd.fork())

   if pid == 0 then
      for other in next, owned do
         unistd.close(other)
      end
      unistd.close(master)

      -- Opening the pseudo-terminal in a new session makes it ours.
      unistd.setpid('s')
      local tty = assert(fcntl.open(slave, fcntl.O_RDWR))
      for fd = 0, 2 do
         unistd.dup2(tty, fd)
      end
      unistd.close(tty)
      unistd.close(keep)

      if options.cwd then
         assert(unistd.chdir(options.cwd))
      end
      setenvs(options)
      child()
      unistd._exit(0)
   end
   unistd.close(keep)
   return pid
end


-- The virtual terminal for the program of OPTIONS, which is nil if there is no
-- `lvterm`.
local function screen_of(options)
   local lib = options.lvterm
   if lib == nil then
      lib = M.lvterm
   end
   return lib and lib.new(options.lines, options.columns) or nil
end


-- Lua source for a chunk that returns the number of VALUES, which are
-- numbers, strings, booleans or nils, followed by the values themselves.
local function serialize(values)
   local t = {tostring(values.n)}
   for i = 1, values.n do
      local v = values[i]
      if type(v) == 'number' then
         t[#t + 1] = format('%.17g', v)
      elseif type(v) == 'string' then
         t[#t + 1] = format('%q', v)
      else
         t[#t + 1] = tostring(v)
      end
   end
   return 'return ' .. concat(t, ', ')
end


-- The values that a chunk made by `serialize` returns, with their count in
-- the `n` field.
local function deserialize(source)
   local packed = pack(assert(load(source, 'child results'))())
   return {n = packed[1], unpack(packed, 2, packed.n)}
end


-- Save the lines run in this process, as `luacov` only does when the
-- process that started it exits normally, which the child must not.
local function save_coverage()
   local loaded = debug.getregistry()._LOADED
   local runner = loaded and loaded['luacov.runner']
   if runner and runner.initialized then
      runner.save_stats()
   end
end


-- What the child of `run` does, until it exits: call F, send what it
-- returned down the pipe WR, or an error, and say through CTL_WR when F
-- calls `ready`.
local function run_child(f, wr, ctl_wr)
   local results = pack(pcall(f, function()
      unistd.write(ctl_wr, 'r')
   end))

   -- Leaving without closing the Lua state doesn't flush what's buffered.
   io.stdout:flush()
   io.stderr:flush()

   if results[1] then
      writeall(wr, serialize{n = results.n - 1, unpack(results, 2, results.n)})
   else
      writeall(wr, format('error(%q, 0)', tostring(results[2])))
   end
   unistd.close(wr)

   save_coverage()
   unistd._exit(0)
end


-- Read what the child process PID says on the descriptors MASTER (the
-- terminal), RD (its results) and CTL (when it is ready for input), until
-- the results are complete, typing INPUT at the terminal once the child
-- is ready for it.  Return the results and the terminal output, or nil and
-- why not.
local function converse(pid, master, rd, ctl, input, timeout)
   local said = {[master] = {}, [rd] = {}, [ctl] = {}}
   local live = {[master] = true, [rd] = true, [ctl] = true}

   while live[rd] do
      local fds = {}
      for fd in next, live do
         fds[fd] = {events = {IN = true}}
      end

      if poll.poll(fds, timeout) == 0 then
         return nil, 'timed out waiting for the child process'
      end

      for fd, status in next, fds do
         if status.revents.IN or status.revents.HUP then
            local data = unistd.read(fd, 4096)
            if data == nil or #data == 0 then
               live[fd] = nil
            else
               said[fd][#said[fd] + 1] = data
               if fd == ctl and input then
                  writeall(master, input)
                  input = nil
               end
            end
         end
      end
   end

   return concat(said[rd]), concat(said[master])
end


--- Run a function with a pseudo-terminal for its terminal.
-- The child shares the state of the process that forked it, so the function
-- can use whatever has been loaded already, and the code it runs is covered
-- by `luacov`.
-- @func f function to run in a child process, which is passed `ready`,
--   a function it can call to have the `input` typed at the terminal
-- @tparam[opt] table options
-- @tparam[opt] string options.input what to type at the terminal, after
--   `f` calls `ready`
-- @tparam[opt='xterm'] string options.term the `TERM` of the terminal
-- @tparam[opt=24] int options.lines height of the terminal
-- @tparam[opt=80] int options.columns width of the terminal
-- @tparam[opt] table options.env environment variables to set for it
-- @tparam[opt] table|false options.lvterm the library for the
--   screen, or false for none
-- @tparam[opt=10000] int options.timeout milliseconds to wait for `f`
--   to return before giving up and raising an error
-- @treturn table the numbers, strings, booleans and nils that `f`
--   returned, with their count in `n`; an error in `f` is raised here
-- @treturn string what `f` wrote to the terminal
-- @treturn lvterm.Terminal|nil what the terminal shows, if there is an `lvterm`
function M.run(f, options)
   options = settings(options)

   local master, slave, keep = open_pty(options)
   local rd, wr = unistd.pipe()
   local ctl_rd, ctl_wr = unistd.pipe()

   local pid = spawn(options, master, slave, keep, function()
      unistd.close(rd)
      unistd.close(ctl_rd)
      run_child(f, wr, ctl_wr)
   end)

   unistd.close(wr)
   unistd.close(ctl_wr)
   local data, output = converse(
      pid, master, rd, ctl_rd, options.input, options.timeout
   )

   if data == nil then
      signal.kill(pid, signal.SIGKILL)
   end
   unistd.close(rd)
   unistd.close(ctl_rd)

   -- Closing the master hangs up the child, which has to finish first.
   wait.wait(pid)
   unistd.close(master)

   if data == nil then
      error(output, 0)
   end

   local screen = screen_of(options)
   return deserialize(data), output, screen and screen:write(output)
end


local Session = {}
Session.__index = Session

--- The class of a session, for a spec that has methods of its own to add:
-- derive from it with `setmetatable({}, {__index = pty.Session})`, and make a
-- session one with `setmetatable(session, Derived)`.
-- @table Session
M.Session = Session


--- Run a program on a pseudo-terminal, and keep it.
-- The program is a new process, not the Lua that runs the specs, so it can
-- use older libraries than the specs do, if `options.env` says what its
-- environment is.
-- @tparam table options
-- @tparam {string,...} options.argv the program and its arguments
-- @tparam[opt] table options.env environment variables to set for it
-- @tparam[opt] string options.cwd the directory to run it in
-- @tparam[opt] table|false options.lvterm the library for the
--   screen, or false for none
-- @tparam[opt=24] int options.lines height of the terminal
-- @tparam[opt=80] int options.columns width of the terminal
-- @tparam[opt='xterm'] string options.term the `TERM` of the terminal
-- @treturn Session
function M.start(options)
   options = settings(options)

   local master, slave, keep = open_pty(options)
   local pid = spawn(options, master, slave, keep, function()
      local argv = {}
      for i = 2, #options.argv do
         argv[#argv + 1] = options.argv[i]
      end
      unistd.exec(options.argv[1], argv)
      unistd._exit(127)
   end)

   local session = setmetatable({
      pid = pid,
      master = master,
      term = screen_of(options),
      transcript = {},
   }, Session)

   local entry = {pid = pid}
   session.entry = entry
   entry.ref = setmetatable({session}, {__mode = 'v'})
   owned[master] = entry
   return session
end


--- Read what the program has written, until it is quiet.
-- Bytes are fed to the virtual terminal as they arrive, and what it says
-- back, to the questions that the program asked it, is typed.
-- @tparam[opt=300] int quiet milliseconds without output that means the
--   program is waiting for a key
-- @tparam[opt=5000] int limit milliseconds after which to stop anyway
-- @treturn Session the session
function Session:settle(quiet, limit)
   quiet, limit = quiet or 300, limit or 5000
   local started = now()

   while self.master and now() - started < limit do
      local fds = {[self.master] = {events = {IN = true}}}
      if poll.poll(fds, quiet) == 0 then
         break
      end
      local status = fds[self.master].revents
      if status.IN then
         local data = unistd.read(self.master, 4096)
         if data == nil or #data == 0 then
            break
         end
         self.transcript[#self.transcript + 1] = data
         if self.term then
            self.term:write(data)
            local reply = self.term:output()
            if #reply > 0 then
               writeall(self.master, reply)
            end
         end
      elseif status.HUP or status.ERR then
         break
      end
   end
   return self
end


--- Type at the terminal, then wait for the program to settle.
-- @string keys what a person would type
-- @treturn Session the session
function Session:type(keys)
   writeall(self.master, keys)
   return self:settle()
end


--- The screen, as a terminal that the matchers of `specl.screen` can check.
-- @treturn lvterm.Terminal|nil nil if there is no `lvterm`
function Session:screen()
   return self.term
end


--- Everything the program has written so far.
-- @treturn string
function Session:output()
   return concat(self.transcript)
end


--- Whether the program has exited.
-- @treturn boolean
-- @treturn int the exit status, or 128 + the signal that killed it
function Session:exited()
   if self.status == nil then
      local done, how, code = wait.wait(self.pid, wait.WNOHANG)
      if done == self.pid and how ~= 'stopped' then
         self.status = how == 'exited' and code or 128 + code
         self.entry.exited = true
      end
   end
   return self.status ~= nil, self.status
end


--- Wait for the program to exit, reading what it writes meanwhile.
-- @tparam[opt=5000] int limit milliseconds to wait
-- @treturn boolean whether it exited
-- @treturn int the exit status
function Session:wait(limit)
   local started = now()
   limit = limit or 5000
   while not self:exited() and now() - started < limit do
      self:settle(100, 100)
   end
   return self:exited()
end


--- Whether the program has stopped, because it was sent SIGTSTP.
-- @treturn boolean
function Session:suspended()
   local done, how, code = wait.wait(self.pid, wait.WNOHANG + wait.WUNTRACED)
   if done == self.pid then
      if how == 'stopped' then
         return true
      end
      self.status = how == 'exited' and code or 128 + code
      self.entry.exited = true
   end
   return false
end


--- Change the size of the terminal, as a person does with its window.
-- @int lines the new height
-- @int columns the new width
-- @treturn Session the session
function Session:resize(lines, columns)
   termio.tcsetwinsize(self.master, {ws_row = lines, ws_col = columns})
   if self.term then
      self.term:resize(lines, columns)
   end
   signal.kill(self.pid, signal.SIGWINCH)
   return self:settle(500)
end


--- Send a signal to the program.
-- @int sig the signal, such as `posix.signal.SIGTERM`
-- @treturn Session the session
function Session:signal(sig)
   signal.kill(self.pid, sig)
   return self:settle(500)
end


--- Continue a program that has stopped.
-- @treturn Session the session
function Session:resume()
   signal.kill(self.pid, signal.SIGCONT)
   return self:settle(500)
end


--- End the session, killing the program if it is still running.
-- A session that is not stopped is, by `reap`, when nothing refers to it any
-- more.
-- @treturn int the exit status of the program
function Session:stop()
   if not self:exited() then
      signal.kill(self.pid, signal.SIGKILL)
      wait.wait(self.pid)
      self.status = 137
      self.entry.exited = true
   end
   if self.master then
      owned[self.master] = nil
      unistd.close(self.master)
      self.master = nil
   end
   return self.status
end


return M
