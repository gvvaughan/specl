-- Specification matchers.
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

local color = require "specl.color"
local util  = require "specl.util"

local M = {}


-- Merge only the hash part of table <u> into table <t>.
local function merge_hash (t, u)
  local ignore = {}
  for _, v in ipairs (u) do ignore[v] = true end

  for k, v in pairs (u) do
    if ignore[k] == nil then t[k] = v end
  end

  return t
end


-- Quote strings nicely, and coerce non-strings into strings.
local function q (obj)
  if type (obj) == "string" then
    return ("%q"):format (obj)
  end
  return util.tostring (obj)
end


-- The `Matcher` object assembles a self type checking function
-- for assignment to the matchers table.
local Matcher = util.Object {"matcher";
  _init = function (self, parms)
    local matchp = parms[1]
    util.type_check ("Matcher", {matchp}, {"function"})

    -- Overwrite defaults with specified values.
    self = merge_hash (self, parms)

    -- This wrapper function is called to respond to `should_`s.
    self["match?"] = function (name, actual, expect, ...)
      util.type_check (name, {actual}, {self.actual_type})

      -- Pass all parameters to both formatters!
      local m = "expecting" .. self.format_expect (expect, actual, ...) ..
                "but got" .. self.format_actual (actual, expect, ...)
      return matchp (actual, expect, ...), m
    end

    self["one_of?"] = function (name, actual, alternatives, ...)
      util.type_check (name, {actual}, {self.actual_type})
      util.type_check (name .. ".one_of", {alternatives}, {"#table"})

      local success
      for _, expect in ipairs (alternatives) do
	success = matchp (actual, expect, ...)
	if success then break end
      end

      local m
      if #alternatives == 1 then
	m = "expecting" .. self.format_expect (alternatives[1], actual, ...) ..
	    "but got" .. self.format_actual (actual, expect, ...)
      else
        m = "expecting" .. self.format_one_of (alternatives, actual, ...) ..
            "but got" .. self.format_actual (actual, expect, ...)
      end

      return success, m
    end

    return self
  end,

  -- Defaults:
  actual_type   = "any",

  format_actual = function (actual) return " " .. q(actual) end,

  format_expect = function (expect) return " " .. q(expect) .. ", " end,

  format_one_of = function (alternatives)
    return " one of " .. util.concat (alternatives, util.QUOTED) .. ", "
  end,
}



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


-- Only allow Matcher objects to be assigned to a slot in this table.
local matchers = setmetatable ({}, {
  __newindex = function (self, name, matcher)
    util.type_check ("matchers." .. name, {matcher}, {"matcher"})
    rawset (self, name, matcher)
  end,
})


-- color sequences escaped for use as literal strings in Lua patterns.
local escape = {
        reset = color.reset:gsub ("%W", "%%%0"),
        match = color.match:gsub ("%W", "%%%0"),
      }


-- Reformat text into "
-- | %{shell}first line of <text>%{reset}
-- | %{shell}next line of <text>%{reset}
-- " etc.
local function reformat (text, prefix)
  prefix = prefix or "| "
  return "\n" .. prefix .. color.match ..
         util.chomp (text):gsub ("\n",
	   escape.reset .. "\n" .. prefix .. escape.match) ..
         color.reset
end


-- Recursively compare <o1> and <o2> for equivalence.
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


-- Deep comparison, matches if <actual> and <expect> share the same
-- structure.
matchers.equal = Matcher {
  function (actual, expect)
    return (objcmp (actual, expect) == true)
  end,
}


-- Identity, only match if <actual> and <expect> are the same object.
matchers.be = Matcher {
  function (actual, expect)
    return (actual == expect)
  end,

  format_expect = function (expect)
    return " exactly " .. q(expect) .. ", "
  end,
}


-- Matches if any error is raised inside `expect`.
matchers.error = Matcher {
  function (actual, expect, ok)
    if expect ~= nil then
      if not ok then -- "not ok" means an error occurred
        local pattern = ".*" .. expect:gsub ("%W", "%%%0") .. ".*"
        ok = not actual:match (pattern)
      end
    end
    return not ok
  end,

  -- force a new-line, let the display engine take care of indenting.
  format_actual = function (actual)
    return ":" .. reformat (actual)
  end,

  format_expect = function (expect)
    if expect ~= nil then
      return " an error containing " .. q(expect) .. ", "
    else
      return "an error"
    end
  end,

  format_one_of = function (alternatives)
    return " an error containing one of " ..
           util.concat (alternatives, util.QUOTED) .. ", "
  end,
}


-- Matches if <actual> matches <pattern>.
matchers.match = Matcher {
  function (actual, pattern)
    return (actual:match (pattern) ~= nil)
  end,

  actual_type   = "string",

  format_expect = function (pattern)
    return " string matching " .. q(pattern) .. ", "
  end,

  format_one_of = function (alternatives)
    return " string matching one of " ..
           util.concat (alternatives, util.QUOTED) .. ", "
  end,
}


-- Matches if <actual> contains <expect>.
matchers.contain = Matcher {
  function (actual, expect)
    if type (actual) == "string" and type (expect) == "string" then
      -- Look for a substring if VALUE is a string.
      local pattern = expect:gsub ("%W", "%%%0")
      return (actual:match (pattern) ~= nil)
    elseif type (actual) == "table" then
      -- Do deep comparison against keys and values of the table.
      for k, v in pairs (actual) do
        if objcmp (k, expect) or objcmp (v, expect) then
          return true
        end
      end
      return false
    end
  end,

  actual_type   = {"string", "table"},

  format_actual = function (actual)
    if type (actual) == "string" then
      return " " .. q (actual)
    else
      return ":" .. reformat (util.prettytostring (actual, "  "))
    end
  end,

  format_expect = function (expect, actual)
    if type (actual) == "string" and type (expect) == "string" then
      return " string containing " .. q(expect) .. ", "
    else
      return " table containing " .. q(expect) .. ", "
    end
  end,

  format_one_of = function (alternatives, actual)
    return " " .. util.typeof (actual) .. " containing one of " ..
           util.concat (alternatives, util.QUOTED) .. ", "
  end,
}



--[[ ============= ]]--
--[[ Expectations. ]]--
--[[ ============= ]]--


local expectations, ispending


-- Called at the start of each example block.
local function init ()
  expectations = {}
  ispending    = nil
end


-- Return status since last init.
local function status ()
  return { expectations = expectations, ispending = ispending }
end


-- Wrap <actual> in metatable that dynamically looks up an appropriate
-- matcher from the table above for comparison with the following
-- parameter. Matcher names containing '_not_' invert their results
-- before returning.
--
-- For example:                  expect ({}).should_not_be {}

M.stats = { pass = 0, pend = 0, fail = 0, starttime = os.time () }

local function expect (ok, actual)
  return setmetatable ({}, {
    __index = function (_, matcher_name)
      local inverse = false
      if matcher_name:match ("^should_not_") then
        inverse, matcher_name = true, matcher_name:sub (12)
      else
        matcher_name = matcher_name:sub (8)
      end

      local match = matchers[matcher_name]

      local function score (success, message)
	local pending

        if inverse then
	  success = not success
	  message = message and ("not " .. message)
	end

	if ispending ~= nil then
	  -- stats.pend is updated by pending ()
	  -- +1 per pending example, not per expectation in pending examples
	  pending = ispending
	elseif success ~= true then
	  M.stats.fail = M.stats.fail + 1
	else
	  M.stats.pass = M.stats.pass + 1
	end
        table.insert (expectations, {
	  message = message,
	  status  = success,
	  pending = pending,
        })
      end

      -- Returns a functable:
      return setmetatable ({
	--  (i) with a `one_of` field to respond to:
	--      | expect (foo).should_be.one_of {bar, baz, quux}
	one_of = function (alternatives)
	  score (match["one_of?"] (matcher_name, actual, alternatives, ok))
	end,
      }, {
	-- (ii) and a `__call` metamethod to respond to:
	--      | expect (foo).should_be (bar)
        __call = function (_, expected)
          score (match["match?"] (matcher_name, actual, expected, ok))
        end,
      })
    end
  })
end


local function pending (s)
  M.stats.pend = M.stats.pend + 1
  ispending  = s or true
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return util.merge (M, {
  -- Prototypes:
  Matcher   = Matcher,

  -- API:
  expect    = expect,
  reformat  = reformat,
  init      = init,
  matchers  = matchers,
  pending   = pending,
  status    = status,
  stringify = q,
})
