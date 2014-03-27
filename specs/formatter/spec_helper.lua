local inprocess = require "specl.inprocess"
local Main      = require "specl.main"

function run_spec (argt)
  local t = {"--color=no", "-"}
  for _, e in ipairs (argt) do table.insert (t, #t,  e) end
  return inprocess.call (Main, t, argt.stdin)
end
