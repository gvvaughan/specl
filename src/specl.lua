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

require "std"



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



--[[ =========== ]]--
--[[ Formatters. ]]--
--[[ =========== ]]--


local report = {
  header = function ()
  end,

  spec = function (spec)
    print (spec)
  end,

  example = function (example)
    print (example)
  end,

  expectations = function (expectations, indent)
    indent = indent or ""
    for i, expectation in ipairs (expectations) do
      if expectation.status ~= true then
        print (indent .. "- FAILED expectation " .. i .. ": " ..
	       expectation.message:gsub ("\n", "%0" .. indent .. "  "))
      end
    end
  end,

  footer = function (stats)
    local total   = stats.pass + stats.fail
    local percent = 100 * stats.pass / total

    print ()
    print (string.format ("Met %.2f%% of %d expectations.", percent, total))
    print (stats.pass .. " passed, and " ..
           stats.fail .. " failed in " ..
	   (os.clock () - stats.starttime) .. " seconds.")
  end,
}


local progress = {
  header = function ()
    io.write (">")
    io.flush ()
  end,

  spec = function (spec)
  end,

  example = function (example)
  end,

  expectations = function (expectations, indent)
    io.write ("\08")
    for i, expectation in ipairs (expectations) do
      if expectation.status == true then
        io.write (".")
      else
        io.write ("F")
      end
    end
    io.write (">")
    io.flush ()
  end,

  footer = function (stats)
    io.write ("\08 \n")

    if stats.fail == 0 then
      io.write ("All expectations met, ")
    else
      io.write (stats.pass .. " passed, and " ..  stats.fail .. " failed ")
    end
    io.write ("in " ..  (os.clock () - stats.starttime) .. " seconds.\n")
  end,
}


-- Use the simple progress formatter by default.  Can be changed by run().
local formatter = progress



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


local function objcmp (o1, o2)
  local type1, type2 = type (o1), type (o2)
  if type1 ~= type2 then return false end
  if type1 ~= "table" or type2 ~= "table" then return o1 == o2 end

  for k, v in pairs (o1) do
    if o2[k] == nil or not objcmp (v, o2[k]) then return false end
  end
  -- any keys in o2, not already compared above denote a mismatch!
  for k, _ in pairs (o2) do
    if o1[k] == nil then return false end
  end
  return true
end


-- Quote strings nicely, and coerce non-strings into strings.
local function q (obj)
  if type (obj) == "string" then
    return '"' .. obj:gsub ('[\\"]', "\\%0") .. '"'
  end
  return tostring (obj)
end


local matchers = {
  -- Deep comparison, matches if VALUE and EXPECTED share the same
  -- structure.
  equal = function (value, expected)
    local m = "expecting " .. q(expected) .. ", but got ".. q(value)
    return (objcmp (value, expected) == true), m
  end,

  -- Identity, only match if VALUE and EXPECTED are the same object.
  be = function (value, expected)
    local m = "expecting exactly " .. q(expected) .. ", but got " .. q(value)
    return (value == expected), m
  end,

  -- Matches if FUNC raises any error.
  ["error"] = function (expected, ...)
    local ok, err = pcall (...)
    if not ok then -- "not ok" means an error occurred
      local pattern = ".*" .. expected:gsub ("%W", "%%%0") .. ".*"
      ok = not err:match (pattern)
    end
    return not ok, "expecting an error containing " .. q(expected) .. ", and got\n" .. q(err)
  end,

  -- Matches if VALUE matches regular expression PATTERN.
  match = function (value, pattern)
    if type (value) ~= "string" then
      error ("'match' matcher: string expected, but got " .. type (value))
    end
    local m = "expecting string matching " .. q(pattern) .. ", but got " .. q(value)
    return (value:match (pattern) ~= nil), m
  end,

  -- Matches if VALUE contains EXPECTED.
  contain = function (value, expected)
    if type (value) == "string" and type (expected) == "string" then
      -- Look for a substring if VALUE is a string.
      local pattern = expected:gsub ("%W", "%%%0")
      local m = "expecting string containing " .. q(expected) .. ", but got " .. q(value)
      return (value:match (pattern) ~= nil), m
    elseif type (value) == "table" then
      -- Do deep comparison against keys and values of the table.
      local m = "expecting table containing " .. q(expected) .. ", but got " .. q(value)
      for k, v in pairs (value) do
        if objcmp (k, expected) or objcmp (v, expected) then
          return true, m
        end
      end
      return false, m
    end
    error ("'contain' matcher: string or table expected, but got " .. type (value))
  end,
}


-- Wrap TARGET in metatable that dynamically looks up an appropriate
-- matcher from the table above for comparison with the following
-- parameter. Matcher names containing '_not_' invert their results
-- before returning.
--
-- For example:                  expect ({}).should_not_be {}

_G.expectations = {}
_G.stats = { pass = 0, fail = 0, starttime = os.clock () }

local function expect (target)
  return setmetatable ({}, {
    __index = function(_, matcher)
      local inverse = false
      if matcher:match ("^should_not_") then
        inverse, matcher = true, matcher:sub (12)
      else
        matcher = matcher:sub (8)
      end
      return function(...)
        local success, message = matchers[matcher](target, ...)

        if inverse then
	  success = not success
	  message = message and ("not " .. message)
	end

        if success ~= true then
	  _G.stats.fail = _G.stats.fail + 1
	else
	  _G.stats.pass = _G.stats.pass + 1
	end
        table.insert (_G.expectations, { status = success, message = message })
      end
    end
  })
end



--[[ ============= ]]--
--[[ Spec' Runner. ]]--
--[[ ============= ]]--


local compile_specs, compile_contexts, compile_examples, compile_example


-- These strings cannot be used for an example description.
local reserved = set.new { "before", "after" }


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
  for s in set.elems (reserved) do
    -- Lua specs save ready compiled functions to examples[s] already.
    compiled[s] = examples[s] or compile_example (s)
  end

  for _, example in ipairs (examples) do
    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    if reserved:member (description) then
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
-- If FILENAME is passed, it is used in error messages from load().
function compile_example (s, filename)
  if reserved:member (s) then return nop end

  -- Wrap the fragment into a function that we can call later.
  local f = load ("return function () " .. s .. " end", filename)

  -- Execute the function from 'load' or report an error right away.
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
-- INDENT is passed to the formatter, and expanded as we recurse.
function run_contexts (contexts, indent, env)
  indent = indent or ""
  for description, examples in pairs (contexts) do
    formatter.spec (indent .. description:gsub ("^%w+%s+", "", 1))
    run_examples (examples, indent .. "  ", env)
  end
end


-- Run each of EXAMPLES under ENV in order.
-- INDENT is passed to the formatter, and expanded as we recurse.
function run_examples (examples, indent, env)
  env = env or _G

  local block = function (example, blockenv)
    examples.before ()

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)

    if type (definition) == "string" then
      -- Uncompiled example.
      definition = compile_example (definition)
    end

    if type (definition) == "table" then
      -- A nested context, revert back to run_contexts.
      run_contexts (example, indent, env)

    elseif type (definition) == "function" then
      -- An example, execute it in a clean new sub-environment.
      local fenv = { expect = expect }
      formatter.example (indent .. description:gsub ("^%w+%s+", "", 1))
      setfenv (definition, setmetatable (fenv, { __index = blockenv }))

      _G.expectations = {} -- each example may have several expectations
      definition ()
      formatter.expectations (_G.expectations, "  " .. indent)
    end

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
function run (specs, format)
  formatter = format or formatter

  -- Precompile Lua code on initial pass.
  compile_specs (specs)

  -- Run compiled specs, in order.
  formatter.header (_G.stats)
  for _, contexts in ipairs (specs) do
    run_contexts (contexts)
  end
  formatter.footer (_G.stats)
  return _G.stats.fail == 0
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  _VERSION  = "0.1",

  matchers  = matchers,
  progress  = progress,
  report    = report,
  run       = run,
}


if _G._SPEC then
  -- Give specs access to some additional private access points.
  M = table.merge (M, { _expect = expect })
end

return M
