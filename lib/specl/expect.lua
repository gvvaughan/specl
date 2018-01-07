--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2015-2018 Gary V. Vaughan
]]

local _ENV = {
   error = error,
   select = select,
   setfenv = function() end,
   setmetatable = setmetatable,
   tostring = tostring,
   type = type,

   insert = table.insert,

   define = require 'macro'.define,
   getmatcher = require 'specl.matchers'.getmatcher,
}
setfenv(1, _ENV)


--[[ ============== ]]--
--[[ Reader Macros. ]]--
--[[ ============== ]]--


define('expect', function(get)
   local expr
   local tk, v = get:peek(1)
   if v == '(' then
      get:next()
      expr = tostring(get:upto ')')
   elseif v == '{' then
      get:next()
      expr = '{' .. tostring(get:upto '}') .. '}'
   elseif tk == 'string' then
      tk, expr = get:next()
   end
   if expr == nil then -- pass through 'expect' token
      return nil, true
   end
   return '(pcall(function() return ' .. expr .. ' end))', true
end)


-- Transform between decorators.
define('between', function(get)
   local expr
   local tk, v = get:peek(1)
   if v == '(' then
      get:next()
      expr = '(' .. tostring(get:upto ')') .. ')'
   elseif v == '{' then
      get:next()
      expr = '{' .. tostring(get:upto '}') .. '}'
   elseif tk == 'string' then
      tk, expr = get:next()
   end
   if expr == nil then -- pass through 'between' token
      return nil, true
   end
   tk, v = get:peek(1)
   if v ~= '.' then return ' ' .. expr, true end
   get:next() -- consume '.'
   tk, v = get:next()
   if tk ~= 'iden' then return ' ' .. expr .. '.', true end
   return 'between_' .. v .. ' ' .. expr
end)



--[[ ============= ]]--
--[[ Expectations. ]]--
--[[ ============= ]]--


--- Called at the start of each example block.
-- @tparam table state reinitialise status table for next example
-- @int line line number from the spec file definition
local function init(state, line)
   state.stats.status = {
      expectations = {},
      filename = state.spec.filename,
      ispending = nil,   -- we care about this key's value!
      line = line,
   }
end


--- Return status since last init.
-- @tparam table state shared with formatters
-- @treturn table count of completed and pending expectations
local function status(state)
   return state.stats.status
end


--- Save results from an expectation into formatter state.
-- @tparam table state shared with formatters
-- @bool inverse whether this is the result from a 'not' match
-- @bool success whether this expectation succeeded
-- @string message failure message for this expectation
local function score(state, inverse, success, message)
   local pending

   if inverse then
      success = not success
      message = message and('not ' .. message)
   end

   local stats = state.stats
   local status = stats.status
   local expectations, ispending = status.expectations, status.ispending

   if ispending ~= nil then
      -- stats.pend is updated by pending()
      -- +1 per pending example, not per expectation in pending examples
      pending = ispending
   elseif success ~= true then
      stats.fail = stats.fail + 1
   else
      stats.pass = stats.pass + 1
   end
   insert(expectations, {
      message = message,
      status = success,
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
-- @usage expect({}).not_to_be {}
local function expect(state, ok, actual, ...)
   if select('#', ...) > 0 then actual = {actual, ...} end

   return setmetatable({}, {
      __index = function(_, verb)
         local matcher, inverse = getmatcher(verb)

         local vtable = {
             score = function(success, msg)
                return score(state, inverse, success, msg)
             end,
         }

         -- Returns a functable...
         return setmetatable({}, {
            -- `expect(actual).to_be(expected)`
            __call = function(self, expected, ...)
               if select('#', ...) > 0 then expected = {expected, ...} end
               local success, msg = matcher:match(actual, expected, ok)
               if type(success) == 'boolean' then
                   vtable.score(success, msg)
               end
               return success
            end,

            -- `expect(actual).to_be.adaptor(expected)`
            __index = function(self, adaptor)
               local fn = matcher[adaptor .. '?']
               if fn then
                  return function(expected, ...)
                     if select('#', ...) > 0 then expected = {expected, ...} end
                     local success, msg = fn(matcher, actual, expected, ok, vtable)
                     if type(success) == 'boolean' then
                        vtable.score(success, msg)
                     end
                     return success
                  end
               else
                  error("unknown '" .. adaptor .. "' adaptor with '" .. verb .. "'")
               end
            end,
         })
      end
   })
end


--- Mark an example as pending.
-- @function pending
-- @tparam table state shared with formatters
-- @string[opt='not yet implemented'] s reason for pending example
local function pending(state, s)
   local stats = state.stats
   stats.pend = stats.pend + 1
   stats.status.ispending = s or 'not yet implemented'
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   expect = expect,
   init = init,
   pending = pending,
   status = status,
}
