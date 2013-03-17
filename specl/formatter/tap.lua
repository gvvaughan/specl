-- Test Anything Protocol style formatter.
--

local curr_test = 0


-- Map function F over elements of T and return a table of results.
local function map (f, t)
  local r = {}
  for _, v in pairs (t) do
    local o = f (v)
    if o then
      table.insert (r, o)
    end
  end
  return r
end


-- Return S with the first word and following whitespace stripped.
local function strip1st (s)
  return s:gsub ("%w+%s*", "", 1)
end


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

local function nop (...) end

local M = {
  header       = nop,
  spec         = nop,
  example      = nop,
  expectations = expectations,
  footer       = footer,
}

return M
