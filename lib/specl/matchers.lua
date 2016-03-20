-- Specification matchers.
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

local _ = {
  color = require "specl.color",
  std   = require "specl.std",
  util  = require "specl.util",
}

local _ENV = {
  error			= error,
  ipairs		= _.std.ipairs,
  pairs			= _.std.pairs,
  rawget		= rawget,
  rawset		= rawset,
  setfenv		= function () end,
  setmetatable		= setmetatable,
  tostring		= _.std.tostring,
  type			= type,

  format		= string.format,
  gsub			= string.gsub,
  sub			= string.sub,
  insert		= table.insert,

  Object		= _.std.object {},

  color_reset		= _.color.reset,
  color_match		= _.color.match,
  getmetamethod		= _.std.getmetamethod,
  objtype		= _.std.object.type,
  eqv			= _.std.operator.eqv,
  chomp			= _.std.string.chomp,
  escape_pattern	= _.std.string.escape_pattern,
  pickle		= _.std.string.pickle,
  prettytostring	= _.std.string.prettytostring,
  clone			= _.std.table.clone,
  empty			= _.std.table.empty,
  merge			= _.std.table.merge,
  size			= _.std.table.size,
  util_concat		= _.util.concat,
  util_type		= _.util.type,
  type_check		= _.util.type_check,
}
setfenv (1, _ENV)
_ = nil


local M = {}


-- Stdlib >= v41 objects do not support __totable metamethods.
local function totable (obj)
  local r, i
  if type (obj) == "table" or getmetamethod (obj, "__pairs") then
    -- Fetch all key:value pairs where possible...
    r = {}
    for k, v in pairs (obj) do
      if type (k) == "table" then k = pickle (k) end
      r[k] = v end
  elseif type (obj) == "string" then
    -- ...or explode a raw string into a table of characters.
    r, i = {}, 1
    gsub (obj, "(.)", function (c) i, r[i] = i + 1, c end)
  end
  return r
end


-- Quote strings nicely, and coerce non-strings into strings.
local function q (obj)
  if type (obj) == "string" then
    return format ("%q", obj)
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

  return util_concat (alternatives, infix, quoted)
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


-- The `Matcher` object assembles a self type checking function
-- for assignment to the matchers table.
local Matcher = Object {
  _type = "Matcher",

  _init      = {"matchp"},
  _parmnames = {"matchp",   "format_expect", "format_actual", "format_alternatives"},
  _parmtypes = {"function", "function",      "function",      "function"           },

  -- Respond to `to_`s and `not_to_`s.
  match = function (self, actual, expect, ...)
    type_check (self.name, {actual}, {self.actual_type})

    -- Pass all parameters to both formatters!
    local m = "expecting" .. self:format_expect (expect, actual, ...) ..
              "but got" .. self:format_actual (actual, expect, ...)
    return self:matchp (actual, expect, ...), m
  end,


  -- Adaptors:

  ["all_of?"] = function (self, actual, alternatives, ...)
    type_check (self.name, {actual}, {self.actual_type})
    type_check (self.name .. ".all_of", {alternatives}, {"#table"})

    local success
    for _, expect in ipairs (alternatives) do
      success = self:matchp (actual, expect, ...)
      if not success then break end
    end

    return success, alternatives_msg (self, "all of", alternatives,
                                      actual, expect, ...)
  end,

  ["any_of?"] = function (self, actual, alternatives, ...)
    type_check (self.name, {actual}, {self.actual_type})
    type_check (self.name .. ".any_of", {alternatives}, {"#table"})

    local success
    for _, expect in ipairs (alternatives) do
      success = self:matchp (actual, expect, ...)
      if success then break end
    end

    return success, alternatives_msg (self, "any of", alternatives,
                                      actual, expect, ...)
  end,

  -- Defaults:
  actual_type   = "any",

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


-- Only allow Matcher objects to be assigned to a slot in this table.
-- The actual entries are stored in a subtable to ensure that __newindex
-- always fires, the type of new assignments is always checked, and the
-- name field is always set.
local matchers = setmetatable ({content = {}}, {
  __index = function (self, name) return rawget (self.content, name) end,

  __newindex = function (self, name, matcher)
    type_check ("matchers." .. name, {matcher}, {"Matcher"})
    rawset (self.content, name, matcher)
    rawset (matcher, "name", name)
  end,
})


-- color sequences escaped for use as literal strings in Lua patterns.
local escape = {
  reset = escape_pattern (color_reset),
  match = escape_pattern (color_match),
}


-- Reformat text into "
-- | %{match}first line of <text>%{reset}
-- | %{match}next line of <text>%{reset}
-- " etc.
local function _reformat (text, prefix)
  text = text or ""
  prefix = prefix or "| "
  return "\n" .. prefix .. color_match ..
         chomp (text):gsub ("\n",
           escape.reset .. "\n" .. prefix .. escape.match) ..
         color_reset
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


-- Deep comparison, matches if <actual> and <expect> share the same
-- structure.
matchers.equal = Matcher {
  function (self, actual, expect)
    return eqv (actual, expect)
  end,
}


-- Identity, only match if <actual> and <expect> are the same object.
matchers.be = Matcher {
  function (self, actual, expect)
    return (actual == expect)
  end,

  format_expect = function (self, expect)
    return " exactly " .. q(expect) .. ", "
  end,
}


-- Equal but not the same object.
matchers.copy = Matcher {
  function (self, actual, expect)
    return (actual ~= expect) and eqv (actual, expect)
  end,

  format_expect = function (self, expect)
    return " a copy of " .. q(expect) .. ", "
  end,

  format_alternatives = function (self, adaptor, alternatives)
    return " a copy of " .. adaptor .. " " ..
           concat (alternatives, adaptor, ":quoted") .. ", "
  end,
}


-- Matches if any error is raised inside `expect`.
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


-- Matches if a matching error is raised inside `expect`.
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


-- Matches if <actual> matches <pattern>.
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


-- Matches if <actual> contains <expect>.
matchers.contain = Matcher {
  function (self, actual, expect)
    if type (actual) == "string" and type (expect) == "string" then
      -- Look for a substring if VALUE is a string.
      return (actual:match (escape_pattern (expect)) ~= nil)
    end

    -- Coerce an object to a table.
    if util_type (actual) == "object" then
      actual = totable (actual)
    end

    if type (actual) == "table" then
      -- Do deep comparison against keys and values of the table.
      for k, v in pairs (actual) do
        if eqv (k, expect) or eqv (v, expect) then
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
    type_check (self.name, {actual}, {self.actual_type})
    type_check (self.name .. ".a_permutation_of", {expected}, {{"string", "table"}})

    -- calculate failure output before coercing strings into tables
    local msg = "expecting" ..
                self:format_alternatives ("a permutation of", expected, actual, ...) ..
                "but got" .. self:format_actual (actual, expect, ...)

    if objtype (actual) ~= "table" then actual = totable (actual) end
    if objtype (expected) ~= "table" then expected = totable (expected) end

    if size (actual) == size (expected) then
      -- first, check whether expected values are a permutation of actual keys
      local unseen = clone (actual)
      for _, search in pairs (expected) do unseen[search] = nil end
      if empty (unseen) then return true, msg end

      -- else, check whether expected values are a permutation of actual values
      unseen = clone (actual)
      for _, search in pairs (expected) do
        for k, v in pairs (unseen) do
          if eqv (v, search) then
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

  format_actual = function (self, actual)
    if type (actual) == "string" then
      return " " .. q (actual)
    elseif util_type (actual) == "object" then
      return ":" .. reformat (prettytostring (totable (actual), "  "))
    else
      return ":" .. reformat (prettytostring (actual, "  "))
    end
  end,

  format_expect = function (self, expect, actual)
    if type (expect) == "string" and type (actual) == "string" then
      return " string containing " .. q(expect) .. ", "
    else
      return " " .. objtype (actual) .. " containing " .. q(expect) .. ", "
    end
  end,

  format_alternatives = function (self, adaptor, alternatives, actual)
    if type (alternatives) == "string" then
      alternatives = format ("%q", alternatives)
    else
      alternatives = concat (alternatives, adaptor, ":quoted")
    end
    return " " .. objtype (actual) .. " containing " ..
           adaptor .. " " .. alternatives .. ", "
  end,
}



--[[ ============= ]]--
--[[ Expectations. ]]--
--[[ ============= ]]--


-- Called at the start of each example block.
local function init (state)
  state.expectations = {}
  state.ispending = nil
end


-- Return status since last init.
local function status (state)
  return { expectations = state.expectations, ispending = state.ispending }
end


-- Wrap <actual> in metatable that dynamically looks up an appropriate
-- matcher from the table above for comparison with the following
-- parameter. Matcher names containing '_not_' invert their results
-- before returning.
--
-- For example:                  expect ({}).not_to_be {}
local function expect (state, ok, actual)
  return setmetatable ({}, {
    __index = function (_, verb)
      local inverse = false
      if verb:match ("^should_not_") then
        inverse, matcher_root = true, verb:sub (12)
      elseif verb:match ("^to_not_") or verb:match ("^not_to_") then
        inverse, matcher_root = true, verb:sub (8)
      elseif verb:match ("^should_") then
        matcher_root = verb:sub (8)
      else
        matcher_root = verb:sub (4)
      end

      local matcher = matchers[matcher_root]

      local function score (success, message)
        local pending

        if inverse then
          success = not success
          message = message and ("not " .. message)
        end

	local expectations, ispending, stats =
	  state.expectations, state.ispending, state.stats

        if ispending ~= nil then
          -- stats.pend is updated by pending ()
          -- +1 per pending example, not per expectation in pending examples
          pending = ispending
        elseif success ~= true then
          stats.fail = stats.fail + 1
        else
          stats.pass = stats.pass + 1
        end
        insert (expectations, {
          message = message,
          status  = success,
          pending = pending,
        })
      end

      -- Returns a functable...
      return setmetatable ({}, {
        --     (i) ...with a `__call` metamethod to respond to:
        --         | expect (foo).to_be (bar)
        __call = function (_, expected)
          score (matcher:match (actual, expected, ok))
        end,

        __index = function (_, adaptor_name)
          --  (ii) ...or else dynamic adapator lookup in the matcher object:
          --       | expect (foo).to_be.any_of {bar, baz, quux}
	  adaptor = matcher[adaptor_name .. "?"]
          if adaptor then
	    return function (alternatives)
              score (adaptor (matcher, actual, alternatives, ok))
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


local function pending (state, s)
  state.stats.pend = state.stats.pend + 1
  state.ispending  = s or "not yet implemented"
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
