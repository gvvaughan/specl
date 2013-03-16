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


-- Use the simple progress formatter by default.  Can be changed by run().
local formatter  = require "specl.formatter.progress"
local matchers   = require "specl.matchers"



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
  for i, contexts in ipairs (specs) do
    -- Compile every top-level context specification.
    specs[i] = compile_contexts (contexts)
  end
end


-- CONTEXTS are also compiled destructively in place.
function compile_contexts (contexts)
  for description, examples in pairs (contexts) do
    contexts[description] = compile_examples (examples)
  end
  return contexts
end


-- Return EXAMPLES table with all of the lua fragments compiled into
-- callable functions.
function compile_examples (examples)
  local compiled = {}

  -- Make sure we have a function for every reserved word.
  for s in pairs (reserved) do
    -- Lua specs save ready compiled functions to examples[s] already.
    compiled[s] = examples[s] or compile_example (s)
  end

  for _, example in ipairs (examples) do
    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    if reserved[description] then
      -- YAML specs store reserved words in the ordered example list,
      -- so we have to hoist them out where we can rerun them around
      -- each real example in the list, without digging through all the
      -- entries each time.
      compiled[description] = compile_example (definition)

    elseif type (definition) == "function" then
      -- Compiled Lua code.
      table.insert (compiled, { [description] = definition })

    elseif type (definition) == "string" then
      -- Uncompiled Lua code.
      table.insert (compiled, { [description] = compile_example (definition) })

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


local function nop () end

-- Compile S into a callable function.  If S is a reserved word,
-- then return a function that does nothing.
-- If FILENAME is passed, it is used in error messages from loadstring().
function compile_example (s, filename)
  if reserved[s] then return nop end

  -- Wrap the fragment into a function that we can call later.
  local f = loadstring ("return function () " .. s .. " end", filename)

  -- Execute the function from 'loadstring' or report an error right away.
  if f ~= nil then
    f, errmsg = f ()
  end
  if errmsg ~= nil then
    error (errmsg)
  end

  return f
end


local run_contexts, run_examples, run


-- Run each of CONTEXTS under ENV in order.
function run_contexts (contexts, desc, env)
  for description, examples in pairs (contexts) do
    table.insert(desc, (description:gsub ("^%w+%s+", "", 1)))
    formatter.spec (desc)
    run_examples (examples, desc, env)
    table.remove(desc)
  end
end


-- Intercept functions that normally execute in the global environment,
-- and run them in the example block environment to capture side-effects
-- correctly.
local function initenv (env)
  for _, intercept in pairs { "load", "loadfile", "loadstring" } do
    env[intercept] = function (...)
      local fn = env._specl[intercept] (...)
      return function ()
        setfenv (fn, env)
        return fn ()
      end
    end
  end
end


-- Run each of EXAMPLES under ENV in order.
function run_examples (examples, desc, env)
  local block = function (example, blockenv)
    local metatable = { __index = blockenv }
    local fenv = setmetatable ({ expect = matchers.expect }, metatable)

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
      run_contexts (example, desc, fenv)

    elseif type (definition) == "function" then
      -- An example, execute it in a clean new sub-environment.
      initenv (fenv)
      table.insert(desc, (description:gsub ("^%w+%s+", "", 1)))
      formatter.example (desc)

      matchers.expectations = {} -- each example may have several expectations
      setfenv (definition, fenv)
      definition ()
      formatter.expectations (matchers.expectations, desc)
      table.remove(desc)
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


-- Run SPECS, routing output to FORMAT formatter.
function run (specs, format, env)
  formatter = format or formatter

  -- Precompile Lua code on initial pass.
  compile_specs (specs)

  -- Environment access to core functions that we override to
  -- run within nested function environment later.
  env._specl = {
    load       = load,
    loadfile   = loadfile,
    loadstring = loadstring,
  }

  -- Run compiled specs, in order.
  formatter.header (matchers.stats)
  for _, contexts in ipairs (specs) do
    run_contexts (contexts, {}, env)
  end
  formatter.footer (matchers.stats)
  return matchers.stats.fail ~= 0 and 1 or 0
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local version = require "specl.version"

local M = {
  _VERSION  = version.VERSION,
  run       = run,
}


if _G._SPEC then
  -- Give specs access to some additional private access points.
  M._expect = matchers.expect
end

return M
