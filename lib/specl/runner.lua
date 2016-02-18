-- Specification testing framework.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2016 Gary V. Vaughan
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


local _G		= _G
local error		= error
local ipairs		= ipairs
local load		= load
local loadfile		= loadfile
local loadstring	= loadstring or load
local next		= next
local package		= package
local pairs		= pairs
local type		= type
local rawset		= rawset
local require		= require
local setfenv		= setfenv or function () end
local setmetatable	= setmetatable
local tostring		= tostring

local table_insert	= table.insert
local table_remove	= table.remove

local  matchers		= require "specl.matchers"

local _	= {
  compat		= require "specl.compat",
  std			= require "specl.std",
  util			= require "specl.util",
}

local _ENV		= {}
setfenv (2, _ENV)

local deepcopy		= _.util.deepcopy
local examplename	= _.util.examplename
local intercept_loaders	= _.compat.intercept_loaders
local merge		= _.std.table.merge
local setfenv		= _.compat.setfenv
local slurp		= _.std.io.slurp
local split		= _.std.string.split

_ = nil


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


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function initenv (state, env)
  -- Don't let _G (or _ENV) assignments leak into outer tables.
  rawset (env, "_G", env)
  if env._ENV then rawset (env, "_ENV", env) end

  for _, intercept in pairs { "load", "loadfile", "loadstring" } do
    env[intercept] = function (...)
      local fn = _G[intercept] (...)
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
    matchers.init (state)

    -- Propagate nested environments to functions that might be called
    -- from inside the example.
    local badargs  = require "specl.badargs"
    setfenv (badargs.diagnose, fenv)
    setfenv (definition.example, fenv)
    definition.example ()

    local status = merge ({
      filename = state.spec.filename,
      line     = definition.line,
    }, matchers.status (state))
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
    local fenv = deepcopy (blockenv)

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)
    local line = definition.line

    fenv.expect = function (...)
      return matchers.expect (state, ...)
    end
    setfenv (fenv.expect, fenv)

    fenv.pending = function (...)
      return matchers.pending (state, ...)
    end
    setfenv (fenv.pending, fenv)

    fenv.examples = function (t)
      -- FIXME: robust argument type-checking!
      local description, definition = next (t)
      if type (definition) == "function" then
	local example = { example = definition, line = line or "unknown" }

        table_insert (descriptions, description)
	if run_example (state, example, descriptions, fenv) == false then
          keepgoing = false
	end
	table_remove (descriptions)

      elseif type (definition) == "table" then
	local examples = {}
	for i, example in ipairs (definition) do
	  k, v = next (example)
	  examples[i] = { [k] = { example = v, line = line or "unknown" } }
	end

        table_insert (descriptions, (description))
        if run_examples (state, examples, descriptions, fenv) == false then
          keepgoing = false
        end
	table_remove (descriptions)

      end

      -- Make sure we don't leak status into the calling or following
      -- example, since this `examples` invocation is from inside
      -- `run_examples`.
      matchers.init (state)
    end
    setfenv (fenv.examples, fenv)

    initenv (state, fenv)

    if examples.before ~= nil then
      setfenv (examples.before.example, fenv)
      examples.before.example ()
    end

    if definition.example then
      -- An example, execute it.
      table_insert (descriptions, description)
      if run_example (state, definition, descriptions, fenv) == false then
	keepgoing = false
      end
      table_remove (descriptions)
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
    table_insert (descriptions, description)
    state:accumulator (formatter.spec (descriptions, state.opts))
    local status = run_examples (state, examples, descriptions, env)
    table_remove (descriptions)

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
