local hell = require "specl.shell"
local util = require "specl.util"

local object = util.object

function run_spec (params)
  local SPECL = "specs/specl --color=no"

  -- If params is a string, it is the input text for the subprocess.
  if type (params) == "string" then
    return hell.spawn {SPECL; stdin = params}
  end

  -- If params is a table, fill in the gaps in parameters it names.
  if type (params) == "table" then
    -- The command is made from the array part of params table.
    local cmd = table.concat (params, " ")

    -- But is just options to specl if it begins with a '-'.
    if cmd:sub (1, 1) == "-" then
      cmd = SPECL .. " " .. cmd
    end

    return hell.spawn {cmd; env = params.env, stdin = params.stdin}
  end

  error ("run_spec was expecting a string or table, but got a "..type (params))
end



--[[ ==================== ]]--
--[[ Additional Matchers. ]]--
--[[ ==================== ]]--


do
  local matchers = require "specl.matchers"

  local Matcher, matchers, q =
        matchers.Matcher, matchers.matchers, matchers.stringify

  -- Matches if the type of <actual> is <expect>.
  matchers.instantiate_a = Matcher {
    function (actual, expect)
      return (object.type (actual) == expect)
    end,

    format_actual = function (actual)
      return "a " .. object.type (actual)
    end,

    format_expect = function (expect)
      return "a " .. expect
    end,
  }
end
