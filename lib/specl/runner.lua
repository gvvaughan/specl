-- Specification testing framework.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2015 Gary V. Vaughan
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
-- program; see the file LICENSE.  If not, a copy can be downloaded from
-- <http://www.opensource.org/licenses/mit-license.html>.


local compat   = require "specl.compat"
local expect   = require "specl.expect"
local std      = require "specl.std"
local util     = require "specl.util"

local loadstring = compat.loadstring
local setfenv, slurp, split, merge =
  std.debug.setfenv, std.io.slurp, std.string.split, std.table.merge
local examplename = util.examplename

-- Protect against examples misusing or resetting keywords.
local error, ipairs, pairs, type, rawset, setmetatable =
      error, ipairs, pairs, type, rawset, setmetatable



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


-- Append non-nil ARG to HOLDER.accumulated.
-- If ARG is a table, values for all keys in ARG are accumulated in
-- equivalent HOLDER keys.
-- Used to collect output from formatter calls, to be saved for footer.
local function accumulator (self, arg)
  if arg ~= nil then
    if type (arg) == "table" then
      self.accumulated = self.accumulated or {}
      for k, v in pairs (arg) do
        self.accumulated[k] = (self.accumulated[k] or "") .. tostring(v)
      end
    else
      self.accumulated = (self.accumulated or "") .. arg
    end
  end
end


-- Access to core functions that we override to run within nested
-- function environments.
local core = {
  load       = load,
  loadfile   = loadfile,
  loadstring = loadstring,
  require    = require,
}


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function initenv (state, env)
  -- Don't let _G (or _ENV) assignments leak into outer tables.
  rawset (env, "_G", env)
  if rawget (env, "_ENV") then rawset (env, "_ENV", env) end

  for _, intercept in pairs { "load", "loadfile", "loadstring" } do
    env[intercept] = function (...)
      local fn = core[intercept] (...)
      return function ()
        setfenv (fn, env)
        return fn ()
      end
    end
  end

  -- For a not-yet-{pre,}loaded module, try to find it on the
  -- environment `package.path` using the system loaders, and cache any
  -- symbols that leak out (the side effects). Copy any leaked symbols
  -- into the example block environment, for this and subsequent
  -- examples that load it.
  env.require = function (m)
    local errmsg, import, loaded, loadfn

    compat.intercept_loaders (package)
    compat.intercept_loaders (env.package)

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
end



--[[ ============= ]]--
--[[ Spec' Runner. ]]--
--[[ ============= ]]--


local run_example, run_examples, run_contexts, run


-- Execute an example in a clean new sub-environment; as long as there
-- are no filters, or the filters for the source line of this definition
-- or inclusive example pattern is true.
function run_example (state, definition, descriptions, fenv)
  local formatter = state.opts.formatter
  local filters   = state.spec.filters
  local inclusive = (filters == nil) or (filters[definition.line])
  local keepgoing = true

  if not inclusive then
    local title = examplename (descriptions)
    for _, pattern in ipairs (filters.inclusive or {}) do
      if title:match (pattern) then
        inclusive = true
        break
      end
    end
  end

  if inclusive then
    expect.init (state, definition.line)

    -- Propagate nested environments to functions that might be called
    -- from inside the example.
    local badargs  = require "specl.badargs"
    setfenv (badargs.diagnose, fenv)
    setfenv (definition.example, fenv)
    definition.example ()

    local status = expect.status (state)
    state:accumulator (formatter.expectations (status, descriptions, state.opts))

    if state.opts.fail_fast then
      for _, expectation in ipairs (status.expectations) do
        -- don't stop for passing or even failing pending examples
        if not (expectation.status or expectation.pending) then
          keepgoing = false
        end
      end
    end
  end

  return keepgoing
end


-- Run each of EXAMPLES under ENV in order.
function run_examples (state, examples, descriptions, env)
  local block = function (example, blockenv)
    local keepgoing = true
    local fenv = util.deepcopy (blockenv)

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)
    local line = definition.line

    fenv.expect = function (...)
      return expect.expect (state, ...)
    end
    setfenv (fenv.expect, fenv)

    fenv.pending = function (...)
      return expect.pending (state, ...)
    end
    setfenv (fenv.pending, fenv)

    fenv.examples = function (t)
      -- FIXME: robust argument type-checking!
      local description, definition = next (t)
      if type (definition) == "function" then
	local example = { example = definition, line = line or "unknown" }

        table.insert (descriptions, description)
	if run_example (state, example, descriptions, fenv) == false then
          keepgoing = false
	end
	table.remove (descriptions)

      elseif type (definition) == "table" then
	local examples = {}
	for i, example in ipairs (definition) do
	  k, v = next (example)
	  examples[i] = { [k] = { example = v, line = line or "unknown" } }
	end

        table.insert (descriptions, (description))
        if run_examples (state, examples, descriptions, fenv) == false then
          keepgoing = false
        end
	table.remove (descriptions)

      end

      -- Make sure we don't leak status into the calling or following
      -- example, since this `examples` invocation is from inside
      -- `run_examples`.
      expect.init (state)
    end
    setfenv (fenv.examples, fenv)

    initenv (state, fenv)

    if examples.before ~= nil then
      setfenv (examples.before.example, fenv)
      examples.before.example ()
    end

    if definition.example then
      -- An example, execute it.
      table.insert (descriptions, description)
      if run_example (state, definition, descriptions, fenv) == false then
	keepgoing = false
      end
      table.remove (descriptions)
    else
      -- A nested context, revert back to run_contexts.
      if run_contexts (state, example, descriptions, fenv) == false then
        keepgoing = false
      end
    end

    if examples.after ~= nil then
      setfenv (examples.after.example, fenv)
      examples.after.example ()
    end

    -- Now after's have executed, return false for --fail-fast.
    if keepgoing == false then return false end
  end

  for _, example in ipairs (examples) do
    setfenv (block, env)
    if block (example, env) == false then
      -- Return false immediately for --fail-fast.
      return false
    end
  end
end


-- Run each of CONTEXTS under ENV in order.
function run_contexts (state, contexts, descriptions, env)
  local formatter = state.opts.formatter
  for description, examples in pairs (contexts) do
    table.insert (descriptions, description)
    state:accumulator (formatter.spec (descriptions, state.opts))
    local status = run_examples (state, examples, descriptions, env)
    table.remove (descriptions)

    -- Return false immediately for a failed expectation if --fail-fast
    -- was given.
    if status == false then return false end
  end
end


-- Run `specs` from `state`.
function run (state)
  local formatter = state.opts.formatter

  state.sidefx = {}
  state.accumulator = accumulator -- so we can pass self with ':'
  state.accumulated = nil

  -- Run compiled specs, in order.
  state:accumulator (formatter.header (state.stats, state.opts))
  for _, spec in ipairs (state.specs) do
    state.spec = spec

    -- Return false immediately for a failed expectation if --fail-fast
    -- was given.
    if run_examples (state, spec.examples, {}, state.sandbox) == false then
      break
    end
  end

  formatter.footer (state.stats, state.accumulated, state.opts)
  return state.stats.fail ~= 0 and 1 or 0
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  run         = run,
}


return M
