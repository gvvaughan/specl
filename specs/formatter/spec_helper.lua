local hell = require "specl.shell"

local SPECL = os.getenv ("SPECL") or "bin/specl"

function run_spec (argt)
  -- $SPECL <argt> --color=no -
  local t = {SPECL, "--color=no", "-", stdin = argt.stdin}

  -- inject passed argt elements just before the last element ("-").
  for _, e in ipairs (argt) do table.insert (t, #t,  e) end

  return hell.spawn (t)
end
