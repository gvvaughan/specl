--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2015-2018 Gary V. Vaughan
]]

local inprocess = require "specl.inprocess"
local Main      = require "specl.main"

function run_spec (argt)
  local t = {"--color=no", "-"}
  for _, e in ipairs (argt) do table.insert (t, #t,  e) end
  return inprocess.call (Main, t, argt.stdin)
end
