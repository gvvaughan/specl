-- Test Anything Protocol style formatter.
--

local util = require "specl.util"

local map, nop, strip1st = util.map, util.nop, util.strip1st

local curr_test = 0


-- Diagnose any failed expectations in situ.
local function expectations (expectations, descriptions)
  local name = table.concat (map (strip1st, descriptions), " ")
  for _, expectation in ipairs (expectations) do
    local fail = expectation.status ~= true
    curr_test = curr_test + 1
    print ((fail and "not " or "") .. "ok " .. curr_test .. " " .. name)
    if fail then
      print ("# " .. expectation.message:gsub ("\n", "\n# "))
    end
  end
end


-- Report statistics.
local function footer (stats)
  assert(curr_test == stats.pass + stats.fail)
  print("1.." .. curr_test)
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  name         = "tap",
  header       = nop,
  spec         = nop,
  example      = nop,
  expectations = expectations,
  footer       = footer,
}

return M
