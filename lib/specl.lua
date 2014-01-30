-- Specification testing framework.
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


-- Use the simple progress formatter by default.  Can be changed by run().
local formatter  = require "specl.formatter.progress"
local matchers   = require "specl.matchers"
local std        = require "specl.std"
local util       = require "specl.util"


from std.string import slurp, split


--[[ ================================= ]]--
--[[ Compatibility between 5.1 and 5.2 ]]--
--[[ ================================= ]]--


-- From http://lua-users.org/lists/lua-l/2010-06/msg00313.html
setfenv = setfenv or function(f, t)
  local name
  local up = 0
  repeat
    up = up + 1
    name = debug.getupvalue (f, up)
  until name == '_ENV' or name == nil
  if name then
    debug.upvaluejoin (f, up, function () return name end, 1)
    debug.setupvalue (f, up, t)
  end
  return f
end


loadstring = loadstring or function (chunk, chunkname)
  return load (chunk, chunkname)
end



--[[ ============= ]]--
--[[ Spec' Runner. ]]--
--[[ ============= ]]--


-- Append non-nil ARG to HOLDER.accumulated.
-- If ARG is a table, values for all keys in ARG are accumulated in
-- equivalent HOLDER keys.
-- Used to collect output from formatter calls, to be saved for footer.
local function accumulator (holder, arg)
  if arg ~= nil then
    if type (arg) == "table" then
      holder.accumulated = holder.accumulated or {}
      for k, v in pairs (arg) do
        holder.accumulated[k] = (holder.accumulated[k] or "") .. tostring(v)
      end
    else
      holder.accumulated = (holder.accumulated or "") .. arg
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


-- A map of module name to global symbol side effects.
-- We keep track of these so that they can be injected into an
-- execution environment that requires a module.
local sidefx = {}


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function initenv (env)
  for _, intercept in pairs { "load", "loadfile", "loadstring" } do
    env[intercept] = function (...)
      local fn = core[intercept] (...)
      return function ()
        setfenv (fn, env)
        return fn ()
      end
    end
  end

  -- For a not-yet-{pre,}loaded module, try to find it on `package.path`
  -- and load it with `loadstring`, so that any symbols that leak out
  -- (the side effects) are cached, and then copied into the example
  -- block environment, for this and subsequent examples that load it.
  env.require = function (m)
    local errmsg, import, loaded, loadfn

    -- We can have a spec_helper.lua in each spec directory, so don't
    -- cache the side effects of a random one!
    if m ~= "spec_helper" then
      loaded, loadfn = package.loaded[m], package.preload[m]
      import = sidefx[m]
    end

    if import == nil then
      -- Not preloaded, so search package.path.
      if loadfn == nil then
        for _, path in pairs (split (package.path, ";")) do
          local filename = path:gsub ("%?", (m:gsub ("%.", "/")))
          local s = slurp (filename)
          if s ~= nil then
            loadfn, errmsg = loadstring (s, filename)
	    break
          end
        end
      end
      if errmsg ~= nil then return error (errmsg) end

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

    sidefx[m] = import
    package.loaded[m] = package.loaded[m] or loaded or nil

    -- Use the system require if loadstring failed (e.g. C module).
    return package.loaded[m] or core.require (m)
  end
end


local run_examples, run_contexts, run


-- Run each of EXAMPLES under ENV in order.
function run_examples (examples, descriptions, env)
  local block = function (example, blockenv)
    local metatable = { __index = blockenv }
    local fenv = { expect = matchers.expect, pending = matchers.pending }

    setmetatable (fenv, metatable)
    initenv (fenv)

    if examples.before ~= nil then
      setfenv (examples.before, fenv)
      examples.before ()
    end

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    if type (definition) == "table" then
      -- A nested context, revert back to run_contexts.
      run_contexts (example, descriptions, fenv)

    elseif type (definition) == "function" then
      -- An example, execute it in a clean new sub-environment.
      table.insert (descriptions, description)

      matchers.init ()

      setfenv (definition, fenv)
      definition ()
      accumulator (formatter,
                   formatter.expectations (matchers.status (), descriptions))
      table.remove (descriptions)
    end

    if examples.after ~= nil then
      setfenv (examples.after, fenv)
      examples.after ()
    end
  end

  for _, example in ipairs (examples) do
    -- Also, run every block in a sub-environment, so that before() and
    -- after() calls from one block don't affect any other.
    local fenv = setmetatable ({}, { __index = env })
    setfenv (block, fenv)
    block (example, fenv)
  end
end


-- Run each of CONTEXTS under ENV in order.
function run_contexts (contexts, descriptions, env)
  for description, examples in pairs (contexts) do
    table.insert (descriptions, description)
    accumulator (formatter, formatter.spec (descriptions))
    run_examples (examples, descriptions, env)
    table.remove (descriptions)
  end
end


-- Run SPECS, according to OPTS and ENV.
function run (specs, env)
  formatter = opts.formatter or formatter

  -- Run compiled specs, in order.
  accumulator (formatter, formatter.header (matchers.stats))
  for _, spec in ipairs (specs) do
    run_examples (spec, {}, env)
  end
  formatter.footer (matchers.stats, formatter.accumulated)
  return matchers.stats.fail ~= 0 and 1 or 0
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  run       = run,
}


return M
