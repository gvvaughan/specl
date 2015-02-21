-- `expect` expansion and execution.
-- Written by Gary V. Vaughan, 2015
--
-- Copyright (c) 2015 Gary V. Vaughan
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


local macro    = require "macro"
local matchers = require "specl.matchers"
local std      = require "specl.std"

local getmatcher = matchers.getmatcher



--[[ =============================================================== ]]--
--[[ @({'_'})@ patches for LuaMacro until next release is available. ]]--
--[[ =============================================================== ]]--

local TokenList = require "macro.TokenList"
local lexer = require "macro.lexer"

--- Get a list of consecutive matching tokens.
-- @param get token fetching function
-- @param[opt={space=true,comment=true}] accept set of token types
local function matching (get, accept)
  accept = accept or {space = true, comment = true}
  local tl = TokenList.new ()
  local t, v = get:peek (1, true)
  while accept[t] do
    t,v = get ()
    table.insert (tl, {t, v})
    t,v = get:peek (1, true)
  end
  return tl
end


--- Copy non-semantic tokens from *get* to *put*.
-- @param get token fetching function
-- @param put token writing function
local function spacing (get, put)
  return put:tokens (get:matching ())
end


-- Raise a syntax error().
-- @string msg error message
-- @param[opt] ... arguments for msg format
local function syntax_error (msg, ...)
  msg = string.format ("%s: %d: syntax error ", macro.filename, lexer.line) .. msg
  if select ("#", ...) == 0 then
    error (msg, 0)
  else
    error (string.format (msg, ...), 0)
  end
end



--[[ ============== ]]--
--[[ Reader Macros. ]]--
--[[ ============== ]]--


macro.define ("expect", function (get)
  local expr
  local tk, v = get:peek (1)
  if v == "(" then
    get:next ()
    expr = tostring (get:upto ")")
  elseif v == "{" then
    get:next ()
    expr = "{" .. tostring (get:upto "}") .. "}"
  elseif tk == "string" then
    tk, expr = get:next ()
  end
  if expr == nil then -- pass through 'expect' token
    return nil, true
  end
  return " (pcall (function () return " .. expr .. " end))", true
end)


-- Transform between decorators.
macro.define ("between", function (get)
  local expr
  local tk, v = get:peek (1)
  if v == "(" then
    get:next ()
    expr = "(" .. tostring (get:upto ")") .. ")"
  elseif v == "{" then
    get:next ()
    expr = "{" .. tostring (get:upto "}") .. "}"
  elseif tk == "string" then
    tk, expr = get:next ()
  end
  if expr == nil then -- pass through 'between' token
    return nil, true
  end
  tk, v = get:peek (1)
  if v ~= "." then return " " .. expr, true end
  get:next () -- consume '.'
  tk, v = get:next ()
  if tk ~= "iden" then return " " .. expr .. ".", true end
  return "between_" .. v .. " " .. expr
end)



--[[ ============= ]]--
--[[ Expectations. ]]--
--[[ ============= ]]--


--- Called at the start of each example block.
-- @tparam table state reinitialise status table for next example
-- @int line line number from the spec file definition
local function init (state, line)
  state.stats.status = {
    expectations = {},
    filename     = state.spec.filename,
    ispending    = nil,  -- we care about this key's value!
    line         = line,
  }
end


--- Return status since last init.
-- @tparam table state shared with formatters
-- @treturn table count of completed and pending expectations
local function status (state)
  return state.stats.status
end


--- Save results from an expectation into formatter state.
-- @tparam table state shared with formatters
-- @bool inverse whether this is the result from a "not" match
-- @bool success whether this expectation succeeded
-- @string message failure message for this expectation
local function score (state, inverse, success, message)
  local pending

  if inverse then
    success = not success
    message = message and ("not " .. message)
  end

  local stats  = state.stats
  local status = stats.status
  local expectations, ispending = status.expectations, status.ispending

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


-- Wrap *actual* in metatable for matcher lookups.
-- Dynamically look up an appropriate matcher from @{Matcher} for comparison
-- with the following parameter. Matcher names containing '_not_' invert
-- their results before returning.
--
-- Note this function called from the expansion of the `expect` loader
-- macro, which injects a pcall for capturing errors.
-- @tparam table state filled by formatters as expectations are run
-- @bool ok whether an error occurred
-- @param actual result of running expectation
-- @treturn table dynamic matcher lookup table for this result
-- @usage expect ({}).not_to_be {}
local function expect (state, ok, actual, ...)
  if select ("#", ...) > 0 then actual = {actual, ...} end

  return setmetatable ({}, {
    __index = function (_, verb)
      local matcher, inverse = getmatcher (verb)

      local vtable = {
         score = function (success, msg)
           return score (state, inverse, success, msg)
         end,
      }

      -- Returns a functable...
      return setmetatable ({}, {
        -- `expect (actual).to_be (expected)`
        __call = function (self, expected, ...)
	  if select ("#", ...) > 0 then expected = {expected, ...} end
	  local success, msg = matcher:match (actual, expected, ok)
	  if type (success) == "boolean" then
             vtable.score (success, msg)
	  end
	  return success
        end,

	-- `expect (actual).to_be.adaptor (expected)`
        __index = function (self, adaptor)
	  local fn = matcher[adaptor .. "?"]
          if fn then
	    return function (expected, ...)
	      if select ("#", ...) > 0 then expected = {expected, ...} end
              local success, msg = fn (matcher, actual, expected, ok, vtable)
	      if type (success) == "boolean" then
                vtable.score (success, msg)
	      end
	      return success
	    end
          else
            error ("unknown '" .. adaptor .. "' adaptor with '" .. verb .. "'")
          end
        end,
      })
    end
  })
end


--- Mark an example as pending.
-- @function pending
-- @tparam table state shared with formatters
-- @string[opt="not yet implemented"] s reason for pending example
local function pending (state, s)
  local stats = state.stats
  stats.pend = stats.pend + 1
  stats.status.ispending  = s or "not yet implemented"
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  expandmacros = expandmacros,
  expect       = expect,
  init         = init,
  pending      = pending,
  status       = status,
}
