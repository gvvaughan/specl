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

local util = require "specl.util"

local M = {}


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
  return util.tostring (obj)
end


M.matchers = {
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
  ["error"] = function (value, expected, ok)
    local m = ""

    if expected ~= nil then
      if not ok then -- "not ok" means an error occurred
        local pattern = ".*" .. expected:gsub ("%W", "%%%0") .. ".*"
        ok = not value:match (pattern)
      end
      m = " containing " .. q(expected)
    end

    return not ok, "expecting an error" .. m .. ", but got\n" .. q(value)
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


-- Called at the start of each example block.
function M.init ()
  M.expectations = {}
  M.ispending = nil
end


-- Return status since last init.
function M.status ()
  return { expectations = M.expectations, ispending = M.ispending }
end


-- Wrap TARGET in metatable that dynamically looks up an appropriate
-- matcher from the table above for comparison with the following
-- parameter. Matcher names containing '_not_' invert their results
-- before returning.
--
-- For example:                  expect ({}).should_not_be {}

M.stats = { pass = 0, pend = 0, fail = 0, starttime = os.clock () }

function M.expect (ok, target)
  return setmetatable ({}, {
    __index = function (_, matcher)
      local inverse = false
      if matcher:match ("^should_not_") then
        inverse, matcher = true, matcher:sub (12)
      else
        matcher = matcher:sub (8)
      end
      return function (expected)
        local success, message = M.matchers[matcher](target, expected, ok)
	local pending

        if inverse then
	  success = not success
	  message = message and ("not " .. message)
	end

	if M.ispending ~= nil then
	  -- stats.pend is updated by M.pending ()
	  -- +1 per pending example, not per expectation in pending examples
	  pending = M.ispending
	elseif success ~= true then
	  M.stats.fail = M.stats.fail + 1
	else
	  M.stats.pass = M.stats.pass + 1
	end
        table.insert (M.expectations, {
	  message = message,
	  status = success,
	  pending = pending,
        })
      end
    end
  })
end


function M.pending (s)
  M.stats.pend = M.stats.pend + 1
  M.ispending  = s or true
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return M
