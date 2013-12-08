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
local std   = require "specl.std"
local util  = require "specl.util"

from std        import Object
from std.string import chomp, escape_pattern, prettytostring, tostring
from std.table  import clone, empty, size, totable

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
  return tostring (obj)
end


-- Call util.concat with an infix appropriate to ADAPTOR.
local function concat (alternatives, adaptor, quoted)
  local infix
  if adaptor == "a permutation of" then
    infix = " and "
  elseif adaptor == "all of" then
    infix = " and "
  elseif adaptor == "any of" then
    infix = " or "
  end

  return util.concat (alternatives, infix, quoted)
end


local function alternatives_msg (object, adaptor, alternatives, actual, expect, ...)
  local m

  if #alternatives == 1 then
    m = "expecting" .. object.format_expect (alternatives[1], actual, ...) ..
        "but got" .. object.format_actual (actual, expect, ...)
  else
    m = "expecting" ..
        object.format_alternatives (adaptor, alternatives, actual, ...) ..
        "but got" .. object.format_actual (actual, expect, ...)
  end

  return m
end


-- The `Matcher` object assembles a self type checking function
-- for assignment to the matchers table.
local Matcher = Object {
  _type = "Matcher",

  _init = function (self, parms)
    self.matchp = parms[1]
    util.type_check ("Matcher", {self.matchp}, {"function"})

    -- Overwrite defaults with specified values.
    self = merge_hash (self, parms)

    return self
  end,

  -- Respond to `should_`s and `should_not`s.
  match = function (self, actual, expect, ...)
    util.type_check (self.name, {actual}, {self.actual_type})

    -- Pass all parameters to both formatters!
    local m = "expecting" .. self.format_expect (expect, actual, ...) ..
              "but got" .. self.format_actual (actual, expect, ...)
    return self.matchp (actual, expect, ...), m
  end,


  -- Adaptors:

  ["all_of?"] = function (self, actual, alternatives, ...)
    util.type_check (self.name, {actual}, {self.actual_type})
    util.type_check (self.name .. ".all_of", {alternatives}, {"#table"})

    local success
    for _, expect in ipairs (alternatives) do
      success = self.matchp (actual, expect, ...)
      if not success then break end
    end

    return success, alternatives_msg (self, "all of", alternatives,
                                      actual, expect, ...)
  end,

  ["any_of?"] = function (self, actual, alternatives, ...)
    util.type_check (self.name, {actual}, {self.actual_type})
    util.type_check (self.name .. ".any_of", {alternatives}, {"#table"})

    local success
    for _, expect in ipairs (alternatives) do
      success = self.matchp (actual, expect, ...)
      if success then break end
    end

    return success, alternatives_msg (self, "any of", alternatives,
                                      actual, expect, ...)
  end,

  -- Defaults:
  actual_type   = "any",

  format_actual = function (actual) return " " .. q(actual) end,

  format_expect = function (expect) return " " .. q(expect) .. ", " end,

  format_alternatives = function (adaptor, alternatives)
    return " " .. adaptor .. " " ..
           concat (alternatives, adaptor, util.QUOTED) .. ", "
  end,
}



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


-- Only allow Matcher objects to be assigned to a slot in this table.
-- The actual entries are stored in a subtable to ensure that __newindex
-- always fires, the type of new assignments is always checked, and the
-- name field is always set.
local matchers = setmetatable ({content = {}}, {
  __index = function (self, name) return rawget (self.content, name) end,

  __newindex = function (self, name, matcher)
    util.type_check ("matchers." .. name, {matcher}, {"Matcher"})
    rawset (self.content, name, matcher)
    rawset (matcher, "name", name)
  end,
})


-- color sequences escaped for use as literal strings in Lua patterns.
local escape = {
  reset = escape_pattern (color.reset),
  match = escape_pattern (color.match),
}


-- Reformat text into "
-- | %{match}first line of <text>%{reset}
-- | %{match}next line of <text>%{reset}
-- " etc.
local function _reformat (text, prefix)
  text = text or ""
  prefix = prefix or "| "
  return "\n" .. prefix .. color.match ..
         chomp (text):gsub ("\n",
           escape.reset .. "\n" .. prefix .. escape.match) ..
         color.reset
end


-- Reformat a list of alternatives into "
-- | %{match}as many lines of <list>[1] as provided%{reset}
-- or:
-- | %{match}lines from <list>[2]%}reset}
-- " etc.
local function reformat (list, adaptor, prefix)
  list, prefix = list or {""}, prefix or "| "
  if type (list) ~= "table" then
    list = {list}
  end

  local infix = "or:"
  if adaptor == "all of" then
    infix = "and:"
  elseif adaptor == "any of" then
    infix = "or:"
  end

  local s = ""
  for _, expect in ipairs (list) do
    s = s .. infix .. _reformat (expect, prefix) .. "\n"
  end
  -- strip the spurious <infix> from the start of the string.
  return s:gsub ("^" .. escape_pattern (infix), "")
end


-- Recursively compare <o1> and <o2> for equivalence.
local function objcmp (o1, o2)
  -- cache extended types
  local type1, type2 = Object.type (o1), Object.type (o2)

  -- different types are unequal
  if type1 ~= type2 then return false end

  -- core types can be compared directly
  if type (o1) ~= "table" or type (o2) ~= "table" then return o1 == o2 end

  -- compare std.Objects according to table contents
  if type1 ~= "table" then o1 = totable (o1) end
  if type2 ~= "table" then o2 = totable (o2) end

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
        ok = not actual:match (".*" .. escape_pattern (expect) .. ".*")
      end
    end
    return not ok
  end,

  -- force a new-line, let the display engine take care of indenting.
  format_actual = function (actual, _, ok)
    if ok then
      return " no error"
    else
      return ":" .. reformat (actual)
    end
  end,

  format_expect = function (expect)
    if expect ~= nil then
      return " an error containing:" .. reformat (expect)
    else
      return " an error"
    end
  end,

  format_alternatives = function (adaptor, alternatives)
    return " an error containing " .. adaptor .. ":" ..
           reformat (alternatives, adaptor)
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

  format_alternatives = function (adaptor, alternatives)
    return " string matching " .. adaptor .. " " ..
           concat (alternatives, adaptor, util.QUOTED) .. ", "
  end,
}


-- Matches if <actual> contains <expect>.
matchers.contain = Matcher {
  function (actual, expect)
    if type (actual) == "string" and type (expect) == "string" then
      -- Look for a substring if VALUE is a string.
      return (actual:match (escape_pattern (expect)) ~= nil)
    end

    -- Coerce an object to a table.
    if util.type (actual) == "object" then
      actual = totable (actual)
    end

    if type (actual) == "table" then
      -- Do deep comparison against keys and values of the table.
      for k, v in pairs (actual) do
        if objcmp (k, expect) or objcmp (v, expect) then
          return true
        end
      end
      return false
    end

    -- probably an object with no __totable metamethod.
    return false
  end,

  -- Additional adaptor to match unordered tables (and strings!).
  ["a_permutation_of?"] = function (self, actual, expected, ...)
    util.type_check (self.name, {actual}, {self.actual_type})
    util.type_check (self.name .. ".a_permutation_of", {expected}, {{"string", "table"}})

    -- calculate failure output before coercing strings into tables
    local msg = "expecting" ..
                self.format_alternatives ("a permutation of", expected, actual, ...) ..
                "but got" .. self.format_actual (actual, expect, ...)

    if Object.type (actual) ~= "table" then actual = totable (actual) end
    if Object.type (expected) ~= "table" then expected = totable (expected) end

    if size (actual) == size (expected) then
      -- first, check whether expected values are a permutation of actual keys
      local unseen = clone (actual)
      for _, search in pairs (expected) do unseen[search] = nil end
      if empty (unseen) then return true, msg end

      -- else, check whether expected values are a permutation of actual values
      unseen = clone (actual)
      for _, search in pairs (expected) do
        for k, v in pairs (unseen) do
          if objcmp (v, search) then
            unseen[k] = nil
            break -- only remove one occurrence per search value!
          end
        end
      end
      if empty (unseen) then return true, msg end
    end

    return false, msg
  end,

  actual_type   = {"string", "table", "object"},

  format_actual = function (actual)
    if type (actual) == "string" then
      return " " .. q (actual)
    elseif util.type (actual) == "object" then
      return ":" .. reformat (prettytostring (totable (actual), "  "))
    else
      return ":" .. reformat (prettytostring (actual, "  "))
    end
  end,

  format_expect = function (expect, actual)
    if type (expect) == "string" and type (actual) == "string" then
      return " string containing " .. q(expect) .. ", "
    else
      return " " .. Object.type (actual) .. " containing " .. q(expect) .. ", "
    end
  end,

  format_alternatives = function (adaptor, alternatives, actual)
    if type (alternatives) == "string" then
      alternatives = ("%q"):format (alternatives)
    else
      alternatives = concat (alternatives, adaptor, util.QUOTED)
    end
    return " " .. Object.type (actual) .. " containing " ..
           adaptor .. " " .. alternatives .. ", "
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

M.stats = { pass = 0, pend = 0, fail = 0, starttime = util.gettimeofday () }

local function expect (ok, actual)
  return setmetatable ({}, {
    __index = function (_, matcher_name)
      local inverse = false
      if matcher_name:match ("^should_not_") then
        inverse, matcher_root = true, matcher_name:sub (12)
      else
        matcher_root = matcher_name:sub (8)
      end

      local matcher = matchers[matcher_root]

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

      -- Returns a functable...
      return setmetatable ({}, {
        --     (i) ...with a `__call` metamethod to respond to:
        --         | expect (foo).should_be (bar)
        __call = function (_, expected)
          score (matcher:match (actual, expected, ok))
        end,

        __index = function (_, adaptor_name)
          --  (ii) ...or else dynamic adapator lookup in the matcher object:
          --       | expect (foo).should_be.any_of {bar, baz, quux}
	  adaptor = matcher[adaptor_name .. "?"]
          if adaptor then
	    return function (alternatives)
              score (adaptor (matcher, actual, alternatives, ok))
	    end

          -- (iii) otherwise throw an error for unknown adaptors:
          else
            error ("unknown '" .. adaptor_name .. "' adaptor with '" ..
                   matcher_name .. "'")
          end
        end,
      })
    end
  })
end


local function pending (s)
  M.stats.pend = M.stats.pend + 1
  ispending  = s or "not yet implemented"
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return std.table.merge (M, {
  -- Prototypes:
  Matcher   = Matcher,

  -- API:
  concat    = concat,
  expect    = expect,
  reformat  = reformat,
  init      = init,
  matchers  = matchers,
  pending   = pending,
  status    = status,
  stringify = q,
})
