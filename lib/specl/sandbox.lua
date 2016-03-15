-- Specification testing sandbox.
-- Written by Gary V. Vaughan, 2016
--
-- Copyright (c) 2016 Gary V. Vaughan
--
-- Specl is free software distributed under the terms of the MIT license;
-- it may be used for any purpose, including commercial purposes, at
-- absolutely no cost without having to ask permission.
--
-- The only requirement is that if you do use Specl, then you should give
-- credit by including the appropriate copyright notice somewhere in your
-- product or its documentation.
--
-- You should have received a copy of the MIT license along with this
-- program; see the file LICENSE.md.  If not, a copy can be downloaded
-- from <https://mit-license.org>.


local compat	= require "specl.compat"
local expect	= require "specl.expect"
local std	= require "specl.std"
local util	= require "specl.util"

local intercept_loaders = compat.intercept_loaders
local getfenv, setfenv = std.debug.getfenv, std.debug.setfenv
local clone, merge = std.table.clone, std.table.merge
local deepcopy = util.deepcopy



--[[ ====================================== ]]--
--[[ Set up the bare outermost environment. ]]--
--[[ ====================================== ]]--


local load = load
if not pcall (load, "_=1") then
  local loadfunction = load
  load = function (...)
    if type (...) == "string" then
      return loadstring (...)
    end
    return loadfunction (...)
  end
end


local sandbox = {
  _VERSION	= _VERSION,
  arg		= clone (arg),
  assert	= assert,
  collectgarbage = collectgarbage,
  coroutine = {
    create	= coroutine.create,
    resume	= coroutine.resume,
    running	= coroutine.running,
    status	= coroutine.status,
    wrap	= coroutine.wrap,
    yield	= coroutine.yield,
  },
  debug = {
    debug	 = debug.debug,
    gethook	 = debug.gethook,
    getinfo	 = debug.getinfo,
    getlocal	 = debug.getlocal,
    getmetatable = debug.getmetatable,
    getregistry	 = debug.getregistry,
    getupvalue	 = debug.getupvalue,
    getuservalue = debug.getuservalue,
    sethook	 = debug.sethook,
    setmetatable = debug.setmetatable,
    setupvalue	 = debug.setupvalue,
    setuservalue = debug.setuservalue,
    traceback	 = debug.traceback,
    upvalueid	 = debug.upvalueid,
    upvaluejoin	 = debug.upvaluejoin,
  },
  dofile	= dofile,
  error		= error,
  getfenv	= getfenv,
  getmetatable	= getmetatable,
  io = {
    close	= io.close,
    flush	= io.flush,
    input	= io.input,
    lines	= io.lines,
    open	= io.open,
    output	= io.output,
    popen	= io.popen,
    read	= io.read,
    stderr	= io.stderr,
    stdin	= io.stdin,
    stdout	= io.stdout,
    tmpfile	= io.tmpfile,
    type	= io.type,
    write	= io.write,
  },
  ipairs	= ipairs,
  load		= load,
  loadfile	= loadfile,
  math = {
    abs		= math.abs,
    acos	= math.acos,
    asin	= math.asin,
    atan	= math.atan,
    ceil	= math.ceil,
    cos		= math.cos,
    deg		= math.deg,
    exp		= math.exp,
    floor	= math.floor,
    fmod	= math.fmod,
    huge	= math.huge,
    log		= math.log,
    max		= math.max,
    min		= math.min,
    modf	= math.modf,
    pi		= math.pi,
    rad		= math.rad,
    random	= math.random,
    randomseed	= math.randomseed,
    sin		= math.sin,
    sqrt	= math.sqrt,
    tan		= math.tan,
  },
  module	= module,
  next		= next,
  os = {
    clock	= os.clock,
    date	= os.date,
    difftime	= os.difftime,
    execute	= os.execute,
    exit	= os.exit,
    getenv	= os.getenv,
    remove	= os.remove,
    rename	= os.rename,
    setlocale	= os.setlocale,
    time	= os.time,
    tmpname	= os.tmpname,
  },
  pack		= pack or table.pack,
  package = {
    config	= package.config,
    cpath	= package.cpath,
    loaders	= package.loaders or package.searchers,
    loadlib	= package.loadlib,
    path	= package.path,
    preload	= package.preload,
    searchers	= package.loaders or package.searchers,
    searchpath	= package.searchpath,
    seeall	= package.seeall,
  },
  pairs		= pairs,
  pcall		= pcall,
  print		= print,
  rawequal	= rawequal,
  rawget	= rawget,
  rawlen	= rawlen,
  rawset	= rawset,
  require	= require,
  select	= select,
  setfenv	= setfenv,
  setmetatable	= setmetatable,
  string = {
    byte	= string.byte,
    char	= string.char,
    dump	= string.dump,
    find	= string.find,
    format	= string.format,
    gmatch	= string.gmatch,
    gsub	= string.gsub,
    len		= string.len,
    lower	= string.lower,
    match	= string.match,
    rep		= string.rep,
    reverse	= string.reverse,
    sub		= string.sub,
    upper	= string.upper,
  },
  table = {
    concat	= table.concat,
    insert	= table.insert,
    pack	= table.pack or pack,
    remove	= table.remove,
    sort	= table.sort,
    unpack	= table.unpack or unpack,
  },
  tonumber	= tonumber,
  tostring	= tostring,
  type		= type,
  unpack	= unpack or table.unpack,
  xpcall	= xpcall,
}
sandbox._G	= sandbox
sandbox.package.loaded = {
  _G		= sandbox,
  coroutine	= sandbox.coroutine,
  debug		= sandbox.debug,
  io		= sandbox.io,
  math		= sandbox.math,
  os		= sandbox.os,
  package	= sandbox.package,
  string	= sandbox.string,
  table		= sandbox.table,
}



--[[ ========================================== ]]--
--[[ Initialize a copy of the bare environment. ]]--
--[[ ========================================== ]]--


local matchers = require "specl.matchers"


local function root_closures (root_env, state)
  -- Add closures to sandbox.
  root_env.expect = function (...)
    return expect.expect (state, ...)
  end

  root_env.pending = function (...)
    return expect.pending (state, ...)
  end

  return root_env
end


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function inner_closures (env, state)
  env.load = function (ld, source, _, fenv)
    local fn = load (ld, source)
    return function ()
      setfenv (fn, fenv or env)
      return fn ()
    end
  end

  env.loadfile = function (filename, _, fenv)
    local fn = loadfile (filename)
    return function ()
      setfenv (fn, fenv or env)
      return fn ()
    end
  end

  -- For a not-yet-{pre,}loaded module, try to find it on the
  -- environment `package.path` using the system loaders, and cache any
  -- symbols that leak out (the side effects). Copy any leaked symbols
  -- into the example block environment, for this and subsequent
  -- examples that load it.
  env.require = function (m)
    local errmsg, import, loaded, loadfn

    intercept_loaders (package)
    intercept_loaders (env.package)

    -- temporarily switch to the environment package context.
    local save = {
      cpath = package.cpath, path = package.path, loaders = package.loaders,
    }
    package.cpath, package.path, package.loaders =
      env.package.cpath, env.package.path, env.package.loaders

    -- We can have a spec_helper.lua in each spec directory, so don't
    -- cache the side effects of a random one!
    if m ~= "spec_helper" then
      loaded, loadfn = package.loaded[m], package.preload[m]
      import = state.sidefx[m]
    end

    if import == nil and loaded == nil then
      -- No side effects cached; find a loader function.
      if loadfn == nil then
        errmsg = ""
        for _, loader in ipairs (package.loaders) do
	  loadfn = loader (m)
	  if type (loadfn) == "function" then
            break
	  end
	  errmsg = errmsg .. (loadfn and tostring (loadfn) or "")
        end
      end
      if type (loadfn) ~= "function" then
        package.path, package.cpath = save.path, save.cpath
        return error (errmsg)
      end

      -- Capture side effects.
      if loadfn ~= nil then
        import = setmetatable ({}, {__index = env})
        setfenv (loadfn, import)
        loaded = loadfn ()
      end
    end

    -- Import side effects into example block environment.
    for name, value in pairs (import or {}) do
      env[name] = value
    end

    -- A map of module name to global symbol side effects.
    -- We keep track of these so that they can be injected into an
    -- execution environment that requires a module.
    state.sidefx[m] = import
    package.loaded[m] = package.loaded[m] or loaded or nil

    package.cpath, package.path, package.loaders =
      save.cpath, save.path, save.loaders
    return package.loaded[m]
  end

  return env
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  inner = function (state, source_env)
    return inner_closures (deepcopy (source_env), state)
  end,

  new = function (state, caller_env)
    local root_env = root_closures (deepcopy (sandbox), state)
    return merge (root_env, caller_env)
  end,
}
