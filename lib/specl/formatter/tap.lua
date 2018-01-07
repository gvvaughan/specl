--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2013-2018 Francois Perrad
]]

-- Test Anything Protocol style formatter.

local util = require 'specl.util'

local examplename, nop = util.examplename, util.nop

local curr_test = 0


-- Diagnose any failed expectations in situ.
local function expectations(status, descriptions)
   local title = examplename(descriptions)

   if next(status.expectations) then
      for _, expectation in ipairs(status.expectations) do
         local fail = (expectation.status == false)
         curr_test = curr_test + 1
         if fail then io.write 'not ' end
         io.write('ok ' .. curr_test .. ' ' .. title)
         io.write '\n'
         if expectation.status == 'pending' then
            print '# PENDING expectation: Not Implemented Yet'
         end
         if fail then
            print('# ' .. expectation.message:gsub('\n', '\n# '))
         end
      end
   elseif status.ispending then
      print('#    ' .. tostring(curr_test):gsub('.', '-') .. ' ' ..
             title .. '\n#      PENDING example: Not Implemented Yet')
   end
end


-- Report statistics.
local function footer(stats)
   assert(curr_test == stats.pass + stats.pend + stats.fail)
   print('1..' .. curr_test)
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
   header = nop,
   spec = nop,
   expectations = expectations,
   footer = footer,
}

return M
