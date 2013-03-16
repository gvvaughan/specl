-- Test Anything Protocol style formatter.
--

local curr_test = 0


local function header () end


local function spec (desc)
end


local function example (desc)
end


-- Diagnose any failed expectations in situ.
local function expectations (expectations, desc)
  local name = table.concat(desc, " ")
  for _, expectation in ipairs (expectations) do
    local fail = expectation.status ~= true
    curr_test = curr_test + 1
    print((fail and "not " or "") .. "ok " .. curr_test .. " " .. name)
    if fail then
      print("# " .. expectation.message:gsub("\n", "\n# "))
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
  header       = header,
  spec         = spec,
  example      = example,
  expectations = expectations,
  footer       = footer,
}

return M
