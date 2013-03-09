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

require "std"

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

M.expectations = {}
M.stats = { pass = 0, fail = 0, starttime = os.clock () }

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
	  M.stats.fail = M.stats.fail + 1
	else
	  M.stats.pass = M.stats.pass + 1
	end
        table.insert (M.expectations, { status = success, message = message })
      end
    end
  })
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


return table.merge (M, {
  expect       = expect,
  matchers     = matchers,
})
