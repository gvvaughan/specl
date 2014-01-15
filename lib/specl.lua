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
local util       = require "specl.util"



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


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function initenv (env)
  for _, intercept in pairs { "load", "loadfile", "loadstring" } do
    env[intercept] = function (...)
      local fn = env.specl["_" .. intercept] (...)
      return function ()
        setfenv (fn, env)
        return fn ()
      end
    end
  end

  -- Manually walk the package path, and `loadstring(f)` what we find...
  --   * setfenv prior to running loadstring returned function, which
  --     imports any global symbols from <f> into the local env;
  --   * (re)load the module with the system loader so that specl itself
  --     can find all the symbols it needs without digging through nested
  --     sandbox environments.
  env.require = function (f)
    local fn, errmsg = package.preload[f], "could not load " .. f

    if fn == nil then
      local h, filename

      for path in string.gmatch (package.path .. ";", "([^;]*);") do
        filename = path:gsub ("%?", (f:gsub ("%.", "/")))
        h = io.open (filename, "rb")
        if h then break end
      end

      -- Manually load into a local function, if we found it.
      if h ~= nil then
	local s = h:read "*a"
        h:close ()

        if s ~= nil then fn, errmsg = loadstring (s, filename) end

        if errmsg ~= nil then error (errmsg) end

	if f:match "spec_helper" == nil and f:match "^lua_......$" == nil then
	  package.preload[f] = fn
	end
      end
    end

    if fn ~= nil then
      -- Ensure any global symbols arrive in <env>.
      setfenv (fn, env)
      fn ()
    end

    -- Return the package.loaded result.
    return env.specl._require (f)
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

  env.specl = {
    -- Environment access to core functions that we override to
    -- run within nested function environment later.
    _load       = load,
    _loadfile   = loadfile,
    _loadstring = loadstring,
    _require    = require,
  }

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
