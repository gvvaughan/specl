-- Specification testing framework.
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



local _	= {
  compat	= require "specl.compat",
  matchers	= require "specl.matchers",
  sandbox	= require "specl.sandbox",
  std		= require "specl.std",
  util		= require "specl.util",
}

local _ENV = {
  error			= error,
  ipairs		= ipairs,
  next			= next,
  pairs			= pairs,
  require		= require,
  setmetatable		= setmetatable,
  tostring		= tostring,
  type			= type,

  insert		= table.insert,
  remove		= table.remove,

  matchers_init		= _.matchers.init,
  matchers_status	= _.matchers.status,
  sandbox_inner		= _.sandbox.inner,
  sandbox_new		= _.sandbox.new,
  slurp			= _.std.io.slurp,
  split			= _.std.string.split,
  merge			= _.std.table.merge,
  deepcopy		= _.util.deepcopy,
  examplename		= _.util.examplename,

  setfenv		= function () end,
}
setfenv (1, _ENV)
local setfenv = _.compat.setfenv
_ = nil


-- Forward declarations
local run_example, run_examples, run_contexts, run



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


-- Append non-nil ARG to HOLDER.accumulated.
-- If ARG is a table, values for all keys in ARG are accumulated in
-- equivalent HOLDER keys.
-- Used to collect output from formatter calls, to be saved for footer.
local function accumulator (self, arg)
  if arg ~= nil then
    if type (arg) == "table" then
      self.accumulated = self.accumulated or {}
      for k, v in pairs (arg) do
        self.accumulated[k] = (self.accumulated[k] or "") .. tostring(v)
      end
    else
      self.accumulated = (self.accumulated or "") .. arg
    end
  end
end


--[[ ============= ]]--
--[[ Spec' Runner. ]]--
--[[ ============= ]]--


-- Execute an example in a clean new sub-environment; as long as there
-- are no filters, or the filters for the source line of this definition
-- or inclusive example pattern is true.
function run_example (state, definition, descriptions, fenv)
  local formatter = state.opts.formatter
  local filters   = state.spec.filters
  local inclusive = (filters == nil) or (filters[definition.line])
  local keepgoing = true

  if not inclusive then
    local title = examplename (descriptions)
    for _, pattern in ipairs (filters.inclusive or {}) do
      if title:match (pattern) then
        inclusive = true
        break
      end
    end
  end

  if inclusive then
    matchers_init (state)

    -- Propagate nested environments to functions that might be called
    -- from inside the example.
    local badargs  = require "specl.badargs"
    setfenv (badargs.diagnose, fenv)
    setfenv (definition.example, fenv)
    definition.example ()

    local status = merge ({
      filename = state.spec.filename,
      line     = definition.line,
    }, matchers_status (state))
    state:accumulator (formatter.expectations (status, descriptions, state.opts))

    if state.opts.fail_fast then
      for _, expectation in ipairs (status.expectations) do
        -- don't stop for passing or even failing pending examples
        if not (expectation.status or expectation.pending) then
          keepgoing = false
        end
      end
    end
  end

  return keepgoing
end


-- Run each of EXAMPLES under ENV in order.
function run_examples (state, examples, descriptions, env)
  local before = examples.before
  local after = examples.after

  for _, example in ipairs (examples) do
    local keepgoing = true
    local fenv = sandbox_inner (state, env)

    -- There is only one, otherwise we can't maintain example order.
    local description, definition = next (example)
    local line = definition.line

    fenv.examples = function (t)
      -- FIXME: robust argument type-checking!
      local description, definition = next (t)
      if type (definition) == "function" then
        local example = { example = definition, line = line or "unknown" }

        insert (descriptions, description)
        if run_example (state, example, descriptions, fenv) == false then
          keepgoing = false
        end
        remove (descriptions)

      elseif type (definition) == "table" then
        local examples = {}
        for i, example in ipairs (definition) do
          k, v = next (example)
          examples[i] = { [k] = { example = v, line = line or "unknown" } }
        end

        insert (descriptions, (description))
        if run_examples (state, examples, descriptions, fenv) == false then
          keepgoing = false
        end
        remove (descriptions)
      end

      -- Make sure we don't leak status into the calling or following
      -- example, since this `examples` invocation is from inside
      -- `run_examples`.
      matchers_init (state)
    end

    if before ~= nil then
      setfenv (before.example, fenv)
      before.example ()
    end

    if definition.example then
      -- An example, execute it.
      insert (descriptions, description)
      if run_example (state, definition, descriptions, fenv) == false then
	keepgoing = false
      end
      remove (descriptions)
    else
      -- A nested context, revert back to run_contexts.
      if run_contexts (state, example, descriptions, fenv) == false then
        keepgoing = false
      end
    end

    if after ~= nil then
      setfenv (after.example, fenv)
      after.example ()
    end

    -- Now after's have executed, return false for --fail-fast.
    if keepgoing == false then return false end
  end
end


-- Run each of CONTEXTS under ENV in order.
function run_contexts (state, contexts, descriptions, env)
  local formatter = state.opts.formatter
  for description, examples in pairs (contexts) do
    insert (descriptions, description)
    state:accumulator (formatter.spec (descriptions, state.opts))
    local status = run_examples (state, examples, descriptions, env)
    remove (descriptions)

    -- Return false immediately for a failed expectation if --fail-fast
    -- was given.
    if status == false then return false end
  end
end


-- Run `specs` from `state`.
function run (state)
  local formatter = state.opts.formatter

  state.accumulator = accumulator -- so we can pass self with ':'
  state.accumulated = nil

  -- Outermost execution environment.
  state.sandbox = sandbox_new (state, state.env)

  -- Run compiled specs, in order.
  state:accumulator (formatter.header (state.stats, state.opts))
  for _, spec in ipairs (state.specs) do
    state.spec = spec

    -- Return false immediately for a failed expectation if --fail-fast
    -- was given.
    if run_examples (state, spec.examples, {}, state.sandbox) == false then
      break
    end
  end

  formatter.footer (state.stats, state.accumulated, state.opts)
  return state.stats.fail ~= 0 and 1 or 0
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  run         = run,
}


return M
