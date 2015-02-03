-- Specification matchers.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (c) 2013-2015 Gary V. Vaughan
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

--[[--
 Built in matchers for `expect`.

 This module implements the standard set of matchers that can be used
 with the result of `expect`.  There are also some general and matcher
 specific adaptors implemented here.  They are all available to use in
 your spec-files without having to require this module.

 If you implement custom matchers for your spec-files, the API is
 available from this module -- the same API used to implement the
 standard Specl matchers.

 @module specl.matchers
]]


local color = require "specl.color"
local std   = require "specl.std"
local util  = require "specl.util"

local getmetamethod, object, pairs, tostring =
  std.getmetamethod, std.object, std.pairs, std.tostring
local chomp, escape_pattern, prettytostring =
  std.string.chomp, std.string.escape_pattern, std.string.prettytostring
local clone, empty, merge, size, unpack =
  std.table.clone, std.table.empty, std.table.merge, std.table.size, std.table.unpack
local argcheck = std.debug.argcheck

local Object = object {}

local M = {}


-- Stdlib >= v41 objects do not support __totable metamethods.
local function totable (obj)
  local r, i
  if type (obj) == "table" or getmetamethod (obj, "__pairs") then
    -- Fetch all key:value pairs where possible...
    r = {}
    for k, v in pairs (obj) do r[k] = v end
  elseif type (obj) == "string" then
    -- ...or explode a raw string into a table of characters.
    r, i = {}, 1
    obj:gsub ("(.)", function (c) i, r[i] = i + 1, c end)
  end
  return r
end


--- Quote strings nicely, and coerce non-strings into strings.
-- @function stringify
-- @param x item to act on
-- @treturn string string representation of *x*
local function q (obj)
  if type (obj) == "string" then
    return ("%q"):format (obj)
  end
  return tostring (obj)
end


--- Format *alternatives* with an *adaptor* appropriate infix.
-- @function concat
-- @tparam table alternatives table of expectations
-- @string adaptor one of "all of", "any of" or "a permutation of"
-- @bool quoted whether to put quote marks around string values
local function concat (alternatives, adaptor, quoted)
  local infix
  if adaptor == "any of" then
    infix = " or "
  else
    infix = " and "
  end

  return util.concat (alternatives, infix, quoted)
end


local function comparative_msg (object, adaptor, actual, expect)
  return "expecting a " .. type (expect) .. " " .. adaptor .. " " ..
         q(expect) .. ", but got" .. object:format_actual (actual, expect)
end


local function alternatives_msg (object, adaptor, alternatives, actual, expect, ...)
  local m

  if #alternatives == 1 then
    m = "expecting" .. object:format_expect (alternatives[1], actual, ...) ..
        "but got" .. object:format_actual (actual, expect, ...)
  else
    m = "expecting" ..
        object:format_alternatives (adaptor, alternatives, actual, ...) ..
        "but got" .. object:format_actual (actual, expect, ...)
  end

  return m
end


--- Assembles a self type checking entry for the matchers table.
-- @object Matcher
-- @func matchp predicate function to determine whether a match occurred
-- @func format_expect format the expected result for display
-- @func format_actual format the actual result for display
-- @func format_alternatives format adaptor alternatives for display
local Matcher = Object {
  _type = "Matcher",

  _init      = {"matchp"},
  _parmnames = {"matchp",   "format_expect", "format_actual", "format_alternatives"},
  _parmtypes = {"function", "function",      "function",      "function"           },

  -- Respond to `to_`s and `not_to_`s.
  match = function (self, actual, expect, ...)
    argcheck (self.name, 1, self.actual_type, actual)

    -- Pass all parameters to both formatters!
    local m = "expecting" .. self:format_expect (expect, actual, ...) ..
              "but got" .. self:format_actual (actual, expect, ...)
    return self:matchp (actual, expect, ...), m
  end,


  -- General Adaptors:

  --- Matches if expectation matches all of the alternatives.
  -- @adaptor all_of
  -- @tparam list alternatives a list of match comparisons
  -- @usage
  --   expect (_G).to_contain.all_of {"io", "math", "os", "string", "table"}
  ["all_of?"] = function (self, actual, alternatives, ...)
    argcheck ("expect", 1, self.actual_type, actual)
    argcheck (self.name .. ".all_of", 1, "#table", alternatives)

    local success
    for _, expect in ipairs (alternatives) do
      success = self:matchp (actual, expect, ...)
      if not success then break end
    end

    return success, alternatives_msg (self, "all of", alternatives,
                                      actual, expect, ...)
  end,

  --- Matches if expectation matches any of the alternatives.
  -- @adaptor any_of
  -- @tparam list alternatives a list of match comparisons
  -- @usage
  --   expect (ctermid ()).to_match.any_of {"/.*tty%d+", "/.*pts%d+"}
  ["any_of?"] = function (self, actual, alternatives, ...)
    argcheck ("expect", 1, self.actual_type, actual)
    argcheck (self.name .. ".any_of", 1, "#table", alternatives)

    local success
    for _, expect in ipairs (alternatives) do
      success = self:matchp (actual, expect, ...)
      if success then break end
    end

    return success, alternatives_msg (self, "any of", alternatives,
                                      actual, expect, ...)
  end,

  -- Defaults:
  actual_type   = "?any",

  matchp        = function (self, actual, expect) return actual == expect end,

  format_actual = function (self, actual) return " " .. q(actual) end,

  format_expect = function (self, expect) return " " .. q(expect) .. ", " end,

  format_alternatives = function (self, adaptor, alternatives)
    return " " .. adaptor .. " " ..
           concat (alternatives, adaptor, ":quoted") .. ", "
  end,
}



--[[ ========= ]]--
--[[ Matchers. ]]--
--[[ ========= ]]--


--- Master table of all active @{Matcher} objects.
-- Only allow Matcher objects to be assigned to a slot in this table.
-- The actual entries are stored in a subtable to ensure that __newindex
-- always fires, the type of new assignments is always checked, and the
-- name field is always set.
-- @table matchers
local matchers = setmetatable ({content = {}}, {
  __index = function (self, name) return rawget (self.content, name) end,

  __newindex = function (self, name, matcher)
    argcheck ("matchers." .. name, 2, "Matcher", matcher)
    rawset (self.content, name, matcher)
    rawset (matcher, "name", name)
  end,
})


-- color sequences escaped for use as literal strings in Lua patterns.
local escape = {
  reset = escape_pattern (color.reset),
  match = escape_pattern (color.match),
}


--- Reformat multi-line output text for output.
--
-- For example: "
-- | %{match}first line of <text>%{reset}
-- | %{match}next line of <text>%{reset}
-- " etc.
-- @string text string to act on
-- @string[opt="| "] prefix output this at the start of every line
-- @treturn string reformatted *text*
local function _reformat (text, prefix)
  text = text or ""
  prefix = prefix or "| "
  return "\n" .. prefix .. color.match ..
         chomp (text):gsub ("\n",
           escape.reset .. "\n" .. prefix .. escape.match) ..
         color.reset
end


--- Reformat a list of alternatives for output.
--
-- For example: "
-- | %{match}as many lines of <list>[1] as provided%{reset}
-- or:
-- | %{match}lines from <list>[2]%}reset}
-- " etc.
-- @function reformat
-- @tparam table list of alternatives to act on
-- @string adaptor one of "all of", "any of" or "a permutation of"
-- @string[opt="| "] prefix output this at the start of every line
-- @treturn string reformatted *text*
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
  -- If they are the same object (number, interned string, table etc),
  -- or they shara a metatable with an __eq metamethod that says they
  -- equal, then they *are* the same... no need for more checking.
  if o1 == o2 then return true end

  -- Non-table types at this point must differ.
  if type (o1) ~= "table" or type (o2) ~= "table" then return false end

  -- cache extended types
  local type1, type2 = object.type (o1), object.type (o2)

  -- different types are unequal
  if type1 ~= type2 then return false end

  -- compare std.Objects according to table contents
  if type1 ~= "table" then o1 = totable (o1) end
  if type2 ~= "table" then o2 = totable (o2) end

  local subcomps = {}  -- keys requiring a recursive comparison
  for k, v in pairs (o1) do
    if o2[k] == nil then return false end
    if v ~= o2[k] then
      if type (v) ~= "table" then return false end
      -- only require recursive comparisons for mismatched values
      table.insert (subcomps, k)
    end
  end
  -- any keys in o2, not already compared above denote a mismatch!
  for k in pairs (o2) do
    if o1[k] == nil then return false end
  end
  if #subcomps == 0 then return true end
  if #subcomps > 1 then
    -- multiple table-valued keys remain, so we have to recurse
    for _, k in ipairs (subcomps) do
      assert (o1[k] ~= nil and o2[k] ~= nil)
      if not objcmp (o1[k], o2[k]) then return false end
    end
    return true
  end
  -- use a tail call for arbitrary depth single-key subcomparison
  local _, k = next (subcomps)
  return objcmp (o1[k], o2[k])
end


local function between_inclusive (self, actual, expected)
  local ok, r = pcall (function ()
    local lower, upper = unpack (expected)
    return actual >= lower and actual <= upper
  end)
  local succeed = ok and r or false

  local msg = "expecting a " .. type (expected[1]) ..
              self:format_alternatives ("between_inclusive", expected, actual) ..
              "but got" .. self:format_actual (actual, expect)
  return succeed, msg
end

--- Identity, only match if *actual* and *expect* are the same object.
-- @matcher be
-- @param expect expected result
matchers.be = Matcher {
  function (self, actual, expect)
    return (actual == expect)
  end,

  --- `be` specific adaptor for range constraint.
  --
  -- The default is to do an inclusive check, which can be made
  -- explicit by appending the `.inclusive` decorator to the adaptor,
  -- or changed to an exclusive range with the `.exclusive` decorator.
  -- @adaptor be.between
  -- @param lower lower-bound for the range
  -- @param upper upper-bound for the range
  -- @usage
  --   expect (#s).to_be.between (8, 20).inclusive
  --   expect (2).to_be.between (1, 3).exclusive
  ["between?"] = between_inclusive,

  ["between_inclusive?"] = between_inclusive,

  ["between_exclusive?"] = function (self, actual, expected)
    local ok, r = pcall (function ()
      local lower, upper = unpack (expected)
      return actual > lower and actual < upper
    end)
    local succeed = ok and r or false

    local msg = "expecting a " .. type (expected[1]) ..
                self:format_alternatives ("between_exclusive", expected, actual) ..
                "but got" .. self:format_actual (actual, expect)
    return succeed, msg
  end,

  --- `be` specific adaptor for greater than comparison.
  -- @adaptor be.gt
  -- @param expected a primitive or object that the expect argument must
  --   always be greater than
  ["gt?"] = function (self, actual, expect)
     local ok, r = pcall (function () return actual > expect end)
     return ok and r or false, comparative_msg (self, ">", actual, expect)
  end,

  --- `be` specific adaptor for greater than or equal to comparison.
  -- @adaptor be.gte
  -- @param expected a primitive or object that the expect argument must
  --   always be greater than or equal to
  -- @usage
  --   function X (t)
  --     return setmetatable (t, {__lt = function (a,b) return #a<#b end})
  --   end
  --   expect (X {"a", "b"}).to_be.gte (X {"b", "a"})
  ["gte?"] = function (self, actual, expect)
     local ok, r = pcall (function () return actual >= expect end)
     return ok and r or false, comparative_msg (self, ">=", actual, expect)
  end,

  --- `be` specific adaptor for less than comparison.
  -- @adaptor be.lt
  -- @param expected a primitive or object that the expect argument must
  --   always be less than
  -- @usage
  --   expect (5).to_be.lt (42)
  ["lt?"] = function (self, actual, expect)
     local ok, r = pcall (function () return actual < expect end)
     return ok and r or false, comparative_msg (self, "<", actual, expect)
  end,

  --- `be` specific adaptor for less than or equal to comparison.
  -- @adaptor be.lte
  -- @param expected a primitive or object that the expect argument must
  --   always be less than or equal to
  -- @usage
  --   expect "abc".to_be.lte "abc"
  ["lte?"] = function (self, actual, expect)
     local ok, r = pcall (function () return actual <= expect end)
     return ok and r or false, comparative_msg (self, "<=", actual, expect)
  end,

  format_expect = function (self, expect)
    return " exactly " .. q(expect) .. ", "
  end,

  format_alternatives = function (self, adaptor, alternatives)
    local decorator = adaptor:match "^between_(%w+)$" or ""
    if decorator ~= "" then
      adaptor, decorator = "between", " " .. decorator
    end
    return " " .. adaptor .. " " ..
           concat (alternatives, adaptor, ":quoted") .. decorator .. ", "
  end,
}


--- Deep comparison, matches if *actual* and *expect* share the same structure.
-- @matcher equal
-- @param expect expected result
matchers.equal = Matcher {
  function (self, actual, expect)
    return (objcmp (actual, expect) == true)
  end,
}


--- Equal but not the same object.
-- @matcher copy
-- @param expect expected result
matchers.copy = Matcher {
  function (self, actual, expect)
    return (actual ~= expect) and (objcmp (actual, expect) == true)
  end,

  format_expect = function (self, expect)
    return " a copy of " .. q(expect) .. ", "
  end,

  format_alternatives = function (self, adaptor, alternatives)
    return " a copy of " .. adaptor .. " " ..
           concat (alternatives, adaptor, ":quoted") .. ", "
  end,
}


--- Matches if any error is raised inside `expect`.
-- @matcher raise
-- @string errmsg substring of raised error message
-- @usage expect (error "oh noes!").to_raise "oh no"
matchers.raise = Matcher {
  function (self, actual, expect, ok)
    if expect ~= nil then
      if not ok then -- "not ok" means an error occurred
        ok = not actual:match (escape_pattern (expect))
      end
    end
    return not ok
  end,

  -- force a new-line, let the display engine take care of indenting.
  format_actual = function (self, actual, _, ok)
    if ok then
      return " no error"
    else
      return ":" .. reformat (actual)
    end
  end,

  format_expect = function (self, expect)
    if expect ~= nil then
      return " an error containing:" .. reformat (expect)
    else
      return " an error"
    end
  end,

  format_alternatives = function (self, adaptor, alternatives)
    return " an error containing " .. adaptor .. ":" ..
           reformat (alternatives, adaptor)
  end,
}


--- Matches if a matching error is raised inside `expect`.
-- @matcher raise_matching
-- @string pattern error message must match this pattern
matchers.raise_matching = Matcher {
  function (self, actual, expect, ok)
    if expect ~= nil then
      if not ok then -- "not ok" means an error occurred
        ok = not actual:match (expect)
      end
    end
    return not ok
  end,

  -- force a new-line, let the display engine take care of indenting.
  format_actual = function (self, actual, _, ok)
    if ok then
      return " no error"
    else
      return ":" .. reformat (actual)
    end
  end,

  format_expect = function (self, expect)
    if expect ~= nil then
      return " an error matching:" .. reformat (expect)
    else
      return " an error"
    end
  end,

  format_alternatives = function (self, adaptor, alternatives)
    return " an error matching " .. adaptor .. ":" ..
           reformat (alternatives, adaptor)
  end,
}


-- For backwards compatibility:
matchers.error = matchers.raise


--- Matches if *actual* matches *pattern*.
-- @matcher match
-- @string pattern result must match this pattern
matchers.match = Matcher {
  function (self, actual, pattern)
    return (actual:match (pattern) ~= nil)
  end,

  actual_type   = "string",

  format_expect = function (self, pattern)
    return " string matching " .. q(pattern) .. ", "
  end,

  format_alternatives = function (self, adaptor, alternatives)
    return " string matching " .. adaptor .. " " ..
           concat (alternatives, adaptor, ":quoted") .. ", "
  end,
}


--- Matches if *actual* contains *expect*.
-- @matcher contain
-- @param content element to search for in string or table.
matchers.contain = Matcher {
  function (self, actual, expect)
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

  --- `contain` specific adaptor to match unordered tables (and strings!).
  -- @adaptor contain.a_permutation_of
  -- @tparam string|table expected result in any order
  -- @usage
  --   expect {[math.sin] = true, [math.cos] = true, [math.tan] = true}.
  --     to_contain.a_permutation_of {math.sin, math.cos, math.tan}
  ["a_permutation_of?"] = function (self, actual, expected)
    argcheck ("expect", 1, self.actual_type, actual)
    argcheck (self.name .. ".a_permutation_of", 1, "string|table", expected)

    -- calculate failure output before coercing strings into tables
    local msg = "expecting" ..
                self:format_alternatives ("a permutation of", expected, actual) ..
                "but got" .. self:format_actual (actual, expect)

    if object.type (actual) ~= "table" then actual = totable (actual) end
    if object.type (expected) ~= "table" then expected = totable (expected) end

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

  actual_type   = "string|table|object",

  format_actual = function (self, actual)
    if type (actual) == "string" then
      return " " .. q (actual)
    elseif util.type (actual) == "object" then
      return ":" .. reformat (prettytostring (totable (actual), "  "))
    else
      return ":" .. reformat (prettytostring (actual, "  "))
    end
  end,

  format_expect = function (self, expect, actual)
    if type (expect) == "string" and type (actual) == "string" then
      return " string containing " .. q(expect) .. ", "
    else
      return " " .. object.type (actual) .. " containing " .. q(expect) .. ", "
    end
  end,

  format_alternatives = function (self, adaptor, alternatives, actual)
    if type (alternatives) == "string" then
      alternatives = ("%q"):format (alternatives)
    else
      alternatives = concat (alternatives, adaptor, ":quoted")
    end
    return " " .. object.type (actual) .. " containing " ..
           adaptor .. " " .. alternatives .. ", "
  end,
}



--[[ ============= ]]--
--[[ Expectations. ]]--
--[[ ============= ]]--


--- Called at the start of each example block.
-- @tparam table formatter state to be reinitialised
local function init (formatter)
  formatter.expectations = {}
  formatter.ispending = nil
end


--- Return status since last init.
-- @tparam table formatter state shared with formatters
-- @treturn table count of completed and pending expectations
local function status (formatter)
  return { expectations = formatter.expectations, ispending = formatter.ispending }
end


--- Save results from an expectation into formatter state.
-- @tparam table formatter state shared with formatters
-- @bool inverse whether this is the result from a "not" match
-- @bool success whether this expectation succeeded
-- @string message failure message for this expectation
local function score (formatter, inverse, success, message)
  local pending

  if inverse then
    success = not success
    message = message and ("not " .. message)
  end

  local expectations, ispending, stats =
        formatter.expectations, formatter.ispending, formatter.stats

  if ispending ~= nil then
    -- stats.pend is updated by pending ()
    -- +1 per pending example, not per expectation in pending examples
    pending = ispending
  elseif success ~= true then
    stats.fail = stats.fail + 1
  else
    stats.pass = stats.pass + 1
  end
  table.insert (expectations, {
    message = message,
    status  = success,
    pending = pending,
  })
end


--- Return an appropriate matcher function, and whether it is inverted.
-- @string verb full argument to expect, e.g. "not_to_contain"
-- @treturn function registered matcher for *verb*
-- @treturn bool whether to invert the results from the matcher function
local function getmatcher (verb)
  local inverse, matcher_root = false
  if verb:match ("^should_not_") then
    inverse, matcher_root = true, verb:sub (12)
  elseif verb:match ("^to_not_") or verb:match ("^not_to_") then
    inverse, matcher_root = true, verb:sub (8)
  elseif verb:match ("^should_") then
    matcher_root = verb:sub (8)
  else
    matcher_root = verb:sub (4)
  end
  return matchers[matcher_root], inverse
end



-- Wrap *actual* in metatable for matcher lookups.
-- Dynamically look up an appropriate matcher from @{Matcher} for comparison
-- with the following parameter. Matcher names containing '_not_' invert
-- their results before returning.
--
-- Note this function called from the expansion of the `expect` loader
-- macro, which injects a pcall for capturing errors.
-- @tparam table formatter filled by formatters as expectations are run
-- @bool ok whether an error occurred
-- @param actual result of running expectation
-- @treturn table dynamic matcher lookup table for this result
-- @usage expect ({}).not_to_be {}
local function expect (formatter, ok, actual)
  return setmetatable ({}, {
    __index = function (_, verb)
      local matcher, inverse = getmatcher (verb)

      -- Returns a functable...
      return setmetatable ({}, {
        --     (i) ...with a `__call` metamethod to respond to:
        --         | expect (foo).to_be (bar)
        __call = function (_, expected)
          score (formatter, inverse, matcher:match (actual, expected, ok))
        end,

        __index = function (_, adaptor_name)
          --  (ii) ...or else dynamic adapator lookup in the matcher object:
          --       | expect (foo).to_be.any_of {bar, baz, quux}
	  adaptor = matcher[adaptor_name .. "?"]
          if adaptor then
	    return function (expected, ...)
	      if select ("#", ...) > 0 then
		expected = {expected, ...}
	      end
              score (formatter, inverse, adaptor (matcher, actual, expected, ok))
	    end

          -- (iii) otherwise throw an error for unknown adaptors:
          else
            error ("unknown '" .. adaptor_name .. "' adaptor with '" ..
                   verb .. "'")
          end
        end,
      })
    end
  })
end


--- Mark an example as pending.
-- @function pending
-- @tparam table formatter state shared with formatters
-- @string[opt="not yet implemented"] s reason for pending example
local function pending (formatter, s)
  formatter.stats.pend = formatter.stats.pend + 1
  formatter.ispending  = s or "not yet implemented"
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return merge (M, {
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
