--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2016-2026 Gary V. Vaughan
]]

local _ = {
   normalize = require 'std.normalize',
   std = require 'specl.std',
}


-- The `package` of the Lua that runs specl. When smushed into a single file
-- we see the bundle's `package`, so capture the host's `package` here.
local host_package = require 'package'


-- Load a file with `load`, which std.normalize has for every Lua, and
-- the contents of the file.  A first line that starts with '#' is skipped,
-- as `loadfile` does, but kept as a comment so that line numbers are right.
local slurp, load = _.std.io.slurp, _.normalize.load

local function loadfile(filename, mode, ...)
   local ok, text = pcall(slurp, filename)
   if not ok then
      return nil, text
   end
   if string.sub(text, 1, 1) == '#' then
      text = '--' .. text
   end
   return load(text, '@' .. filename, mode, ...)
end


--[[ ====================================== ]]--
--[[ Set up the bare outermost environment. ]]--
--[[ ====================================== ]]--


-- Examples search the path set in environment variable *var*, rather
-- than specl's own *current* path, which a luarocks wrapper starts with
-- the tree specl was installed in.  Only *current* holds the default
-- path that ';;' in *var* stands for, so keep that.
local function userpath(current, var)
   local v = string.match(_VERSION, '^Lua (%d+%.%d+)')
   local value = v ~= '5.1' and os.getenv(var .. '_' .. string.gsub(v, '%.', '_'))
      or os.getenv(var)
   if value == nil or string.find(value, ';;', 1, true) then
      return current
   end
   return value
end


local sandbox = {
   _VERSION = _VERSION,
   arg = _.std.table.clone(arg),
   assert = assert,
   collectgarbage = collectgarbage,
   coroutine = {
      create = coroutine.create,
      resume = coroutine.resume,
      running = coroutine.running,
      status = coroutine.status,
      wrap = coroutine.wrap,
      yield = coroutine.yield,
   },
   debug = {
      debug = debug.debug,
      gethook = debug.gethook,
      getinfo = debug.getinfo,
      getlocal = debug.getlocal,
      getmetatable = debug.getmetatable,
      getregistry = debug.getregistry,
      getupvalue = debug.getupvalue,
      getuservalue = debug.getuservalue,
      sethook = debug.sethook,
      setmetatable = debug.setmetatable,
      setupvalue = debug.setupvalue,
      setuservalue = debug.setuservalue,
      traceback = debug.traceback,
      upvalueid = debug.upvalueid,
      upvaluejoin = debug.upvaluejoin,
   },
   dofile = dofile,
   error = error,
   getfenv = _.normalize.getfenv,
   getmetatable = getmetatable,
   io = {
      close = io.close,
      flush = io.flush,
      input = io.input,
      lines = io.lines,
      open = io.open,
      output = io.output,
      popen = io.popen,
      read = io.read,
      stderr = io.stderr,
      stdin = io.stdin,
      stdout = io.stdout,
      tmpfile = io.tmpfile,
      type = io.type,
      write = io.write,
   },
   ipairs = ipairs,
   load = _.normalize.load,
   loadfile = loadfile,
   math = {
      abs = math.abs,
      acos = math.acos,
      asin = math.asin,
      atan = math.atan,
      ceil = math.ceil,
      cos = math.cos,
      deg = math.deg,
      exp = math.exp,
      floor = math.floor,
      fmod = math.fmod,
      huge = math.huge,
      log = math.log,
      max = math.max,
      min = math.min,
      modf = math.modf,
      pi = math.pi,
      rad = math.rad,
      random = math.random,
      randomseed = math.randomseed,
      sin = math.sin,
      sqrt = math.sqrt,
      tan = math.tan,
   },
   module = module,
   next = next,
   os = {
      clock = os.clock,
      date = os.date,
      difftime = os.difftime,
      execute = os.execute,
      exit = os.exit,
      getenv = os.getenv,
      remove = os.remove,
      rename = os.rename,
      setlocale = os.setlocale,
      time = os.time,
      tmpname = os.tmpname,
   },
   pack = pack or table.pack,
   package = {
      config = package.config,
      cpath = userpath(package.cpath, 'LUA_CPATH'),
      loadlib = package.loadlib,
      path = userpath(package.path, 'LUA_PATH'),
      preload = {},
      searchers = package.searchers or package.loaders,
      searchpath = _.normalize.package.searchpath,
   },
   pairs = pairs,
   pcall = pcall,
   print = print,
   rawequal = rawequal,
   rawget = rawget,
   rawlen = rawlen,
   rawset = rawset,
   require = require,
   select = select,
   setfenv = _.normalize.setfenv,
   setmetatable = setmetatable,
   string = {
      byte = string.byte,
      char = string.char,
      dump = string.dump,
      find = string.find,
      format = string.format,
      gmatch = string.gmatch,
      gsub = string.gsub,
      len = string.len,
      lower = string.lower,
      match = string.match,
      rep = string.rep,
      reverse = string.reverse,
      sub = string.sub,
      upper = string.upper,
   },
   table = {
      concat = table.concat,
      insert = table.insert,
      pack = table.pack or pack,
      remove = table.remove,
      sort = table.sort,
      unpack = table.unpack or unpack,
   },
   tonumber = tonumber,
   tostring = tostring,
   type = type,
   unpack = unpack or table.unpack,
   xpcall = xpcall,
}
sandbox._G = sandbox
sandbox.package.loaded = {
   _G = sandbox,
   coroutine = sandbox.coroutine,
   debug = sandbox.debug,
   io = sandbox.io,
   math = sandbox.math,
   os = sandbox.os,
   package = sandbox.package,
   string = sandbox.string,
   table = sandbox.table,
}



--[[ ========================================== ]]--
--[[ Initialize a copy of the bare environment. ]]--
--[[ ========================================== ]]--


local _ENV = {
   concat = table.concat,
   deepcopy = require 'specl.util'.deepcopy,
   error = error,
   expect = require 'specl.expect'.expect,
   find = string.find,
   gsub = string.gsub,
   ipairs = ipairs,
   load = sandbox.load,
   loadfile = sandbox.loadfile,
   matchers = require 'specl.matchers',
   merge = _.std.table.merge,
   package = package,
   pcall = pcall,
   pending = require 'specl.expect'.pending,
   require = require,
   searchpath = _.normalize.package.searchpath,
   select = select,
   setfenv = function() end,
   setmetatable = setmetatable,
   tostring = tostring,
   type = type,
}
setfenv(1, _ENV)
local setfenv = sandbox.setfenv
_ = nil


-- Modules that examples require, kept apart from the modules that specl
-- loaded for itself, so that an example finds every other module on its
-- own package.path, however specl came to load a copy of it.
local modules = {}


-- Where specl found its own modules, before any example changes them.
local path, cpath = package.path, package.cpath


-- Whether *m* is one of specl's own modules.
local function own(m)
   return m == 'specl' or find(m, '^specl%.') ~= nil
end


-- Examples share specl's own modules, which hold the state of this run,
-- and built-in libraries, which aren't on specl's search paths.
local function shared(m)
   if own(m) then
      return true
   end
   return package.loaded[m] ~= nil and
      searchpath(m, path) == nil and
      searchpath(m, cpath) == nil
end


-- Examples test the modules in the current tree, before any copy of
-- them on the search paths, except for the modules they share.
local tree_path, tree_cpath
do
   local dirsep, pathsep, mark = package.config:match('^(%S+)\n(%S+)\n(%S+)\n')
   local ext = package.cpath:match('%' .. mark .. '(%.%w+)') or '.so'
   local function template(...)
      return concat({'.', ...}, dirsep)
   end
   tree_path = concat({
      template('lib', mark .. '.lua'),
      template('lib', mark, 'init.lua'),
      template(mark .. '.lua'),
      template(mark, 'init.lua'),
   }, pathsep)
   tree_cpath = concat({
      template('lib', mark .. ext),
      template(mark .. ext),
   }, pathsep)
end


-- Return the loader function for module *m* in the current tree, or
-- nil if it isn't there, or else nil and an error message.
local function tree_loader(m)
   local filename = searchpath(m, tree_path)
   if filename then
      return loadfile(filename)
   end
   filename = searchpath(m, tree_cpath)
   if filename then
      -- Like Lua, ignore any version prefix up to a hyphen.
      local name = gsub(gsub(m, '^[^-]*%-', ''), '%.', '_')
      return package.loadlib(filename, 'luaopen_' .. name)
   end
end


-- Return the loader function that *searchers* find for module *m*, or
-- else nil and an error message.
local function search(m, searchers)
   local errmsg = ''
   for _, searcher in ipairs(searchers) do
      local loadfn = searcher(m)
      if type(loadfn) == 'function' then
         return loadfn
      end
      errmsg = errmsg .. (loadfn and tostring(loadfn) or '')
   end
   return nil, errmsg
end


-- Call *fn* with the global search paths, which searchers and C modules
-- read, set to *spath* and *scpath*, and restore them even on error.
local function with_paths(spath, scpath, fn, ...)
   local save_path, save_cpath = host_package.path, host_package.cpath
   host_package.path, host_package.cpath = spath, scpath
   local ok, a, b = pcall(fn, ...)
   host_package.path, host_package.cpath = save_path, save_cpath
   if not ok then
      return error(a, 0)
   end
   return a, b
end


local function root_closures(root_env, state)
   -- Add closures to sandbox.
   root_env.expect = function(...)
      return expect(state, ...)
   end

   root_env.pending = function(...)
      return pending(state, ...)
   end

   return root_env
end


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function inner_closures(env, state)
   -- Like Lua 5.2+, use an explicit environment argument even if it
   -- is nil; but default to the example environment, not the real one.
   env.load = function(ld, source, mode, ...)
      if select('#', ...) == 0 then
         return load(ld, source, mode, env)
      end
      return load(ld, source, mode, ...)
   end

   env.loadfile = function(filename, mode, ...)
      if select('#', ...) == 0 then
         return loadfile(filename, mode, env)
      end
      return loadfile(filename, mode, ...)
   end

   env.dofile = function(filename)
      local fn, err = loadfile(filename, nil, env)
      if fn == nil then
         error(err, 0)
      end
      return fn()
   end

   -- Specl's own modules run in the example environment, so that their
   -- side effects are captured too, but they find their dependencies
   -- where specl found them.
   local own_env = setmetatable({
      require = function(m)
         if shared(m) then
            return env.require(m)
         end
         return with_paths(path, cpath, require, m)
      end,
   }, {__index = env, __newindex = env})

   -- For a not-yet-{pre,}loaded module, try to find it on the
   -- environment `package.path` using the system searchers, and cache any
   -- symbols that leak out(the side effects). Copy any leaked symbols
   -- into the example block environment, for this and subsequent
   -- examples that load it.
   env.require = function(m)
      local errmsg, loaded, loadfn
      local cache = shared(m) and package.loaded or modules

      -- We can have a spec_helper.lua in each spec directory, so don't
      -- cache the side effects of a random one!
      if m ~= 'spec_helper' then
         -- Specl's own modules are preloaded where specl keeps them, which
         -- is in the bundle when it is smushed, and any other that an
         -- example requires is preloaded by the example.
         loaded = cache[m]
         loadfn = (own(m) and package.preload or env.package.preload)[m]
      end

      if loaded == nil then
         -- No side effects cached; find a loader function.
         if loadfn == nil and cache == modules then
            loadfn, errmsg = tree_loader(m)
            if errmsg ~= nil then
               return error(errmsg)
            end
         end
         -- Specl finds its own modules where it found the rest.
         local spath, scpath = path, cpath
         if cache == modules then
            spath, scpath = env.package.path, env.package.cpath
         end
         if loadfn == nil then
            loadfn, errmsg = with_paths(spath, scpath, search, m, env.package.searchers)
         end
         if type(loadfn) ~= 'function' then
            return error(errmsg)
         end

         -- Capture side effects.
         setfenv(loadfn, cache == modules and env or own_env)
         loaded = with_paths(spath, scpath, loadfn)
      end

      cache[m] = cache[m] or loaded or nil
      return cache[m]
   end

   return env
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   inner = function(state, source_env)
      return inner_closures(deepcopy(source_env), state)
   end,

   new = function(state, caller_env)
      local root_env = root_closures(deepcopy(sandbox), state)
      return caller_env and merge(root_env, caller_env) or root_env
   end,
}
