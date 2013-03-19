-- Test Anything Protocol style formatter.
--

local util = require "specl.util"

local map, nop, strip1st = util.map, util.nop, util.strip1st

local curr_test = 0


-- Diagnose any failed expectations in situ.
local function expectations (status, descriptions)
  local name = table.concat (map (strip1st, descriptions), " ")

  if next (status.expectations) then
    for _, expectation in ipairs (status.expectations) do
      local fail = (expectation.status == false)
      curr_test = curr_test + 1
      if fail then io.write "not " end
      io.write ("ok " .. curr_test .. " " .. name)
      if expectation.status == "pending" then
	io.write " (Pending: Not Implemented Yet)"
      end
      io.write "\n"
      if fail then
        print ("# " .. expectation.message:gsub ("\n", "\n# "))
      end
    end
  elseif status.ispending then
    curr_test = curr_test + 1
    print ("ok " .. curr_test .. " " .. name .. " (Pending: Not Implemented Yet)")
  end
end


-- Report statistics.
local function footer (stats)
  assert(curr_test == stats.pass + stats.pend + stats.fail)
  print("1.." .. curr_test)
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
  name         = "tap",
  header       = nop,
  spec         = nop,
  expectations = expectations,
  footer       = footer,
}

return M
