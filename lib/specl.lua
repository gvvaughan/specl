-- Specification testing framework.
--
-- Copyright (c) 2013 Free Software Foundation, Inc.
-- Written by Gary V. Vaughan, 2013
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


local macro      = require "macro"

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


local compile_specs, compile_contexts, compile_examples, compile_example


-- These strings cannot be used for an example description.
local reserved = { before = true, after = true }


-- SPECS are compiled destructively in the specs table itself.
function compile_specs (specs)
  for i, spec in ipairs (specs) do
    specs[i] = compile_examples (spec)
  end
end


-- Return EXAMPLES table with all of the lua fragments compiled into
-- callable functions.
function compile_examples (examples)
  local compiled = {}

  -- Make sure we have a function for every reserved word.
  for s in pairs (reserved) do
    compiled[s] = compile_example (s, examples[s])
  end

  for _, example in ipairs (examples) do
    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    -- Undo any type coercion from YAML where a description looked like
    -- something else.
    description = tostring(description)

    if type (definition) == "string" then
      -- Uncompiled Lua code.
      if definition == "" then definition = "pending ()" end
      table.insert (compiled, { [description] = compile_example (description, definition) })

    elseif type (definition) == "table" then
      -- A nested context table.
      table.insert (compiled, compile_contexts (example))

    else
      -- Oh dear, most likely your nesting is not quite right!
      error ('malformed spec in "' .. tostring (description) .. '", a ' ..
             type (definition) .. " (expecting table or string)")
    end
  end

  return compiled
end


-- CONTEXTS are also compiled destructively in place.
function compile_contexts (contexts)
  for description, examples in pairs (contexts) do
    contexts[description] = compile_examples (examples)
  end
  return contexts
end


-- Capture errors thrown by expectations.
macro.define 'expect(expr)  _expect (pcall (function () return expr end))'

-- Compile S into a callable function.  If S is a reserved word,
-- then return a function that does nothing.
-- If FILENAME is passed, it is used in error messages from loadstring().
function compile_example (location, s)
  if s == nil then return util.nop end

  -- Wrap the fragment into a function that we can call later.
  local f, errmsg = loadstring ("return function () " ..
                      macro.substitute_tostring (s) .. "\nend", filename)

  if f == nil then
     local line, msg = errmsg:match ('%[string "[^"]*"%]:([1-9][0-9]*): (.*)$')
     if msg ~= nil then
       errmsg = location .. ":" .. line .. ": " .. msg
     end
     io.stderr:write (errmsg .. "\n")
     os.exit (1)
  end

  -- Execute the function from 'loadstring' or report an error right away.
  if f ~= nil then
    f, errmsg = f ()
  end
  if errmsg ~= nil then
    error (errmsg)
  end

  return f
end


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
    local h, filename

    for path in string.gmatch (package.path .. ";", "([^;]*);") do
      filename = path:gsub ("%?", (f:gsub ("%.", "/")))
      h = io.open (filename, "rb")
      if h then break end
    end

    -- Manually load into the local environment if we found it.
    if h ~= nil then
      local fn, errmsg = loadstring (h:read "*a", filename)
      h:close ()

      if fn == nil then error (errmsg) end

      -- Ensure any global symbols arrive in <env>.
      setfenv (fn, env)
      local import = fn ()
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
    local fenv = { _expect = matchers.expect, pending = matchers.pending }

    setmetatable (fenv, metatable)
    initenv (fenv)
    setfenv (examples.before, fenv)
    examples.before ()

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    if type (definition) == "string" then
      -- Uncompiled example.
      definition = compile_example (definition)
    end

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

    setfenv (examples.after, fenv)
    examples.after ()
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

  -- Precompile Lua code on initial pass.
  compile_specs (specs)

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


if _G._SPEC then
  -- Give specs access to some additional private access points.
  M._expect = matchers.expect
end

return M
