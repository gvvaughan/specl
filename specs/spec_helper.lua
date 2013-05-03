local hell = require "specl.shell"
local util = require "specl.util"

function run_spec (params)
  local SPECL = "bin/specl --color=no"

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


local matchers = require "specl.matchers"

local q = matchers.q

matchers.matchers.instantiate_a = function (value, expected)
  local m = "expecting a " .. q(expected) .. ", but got a " .. q(util.typeof (value))
  return (util.typeof (value) == expected), m
end
