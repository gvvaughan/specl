local hell = require "specl.shell"

local SPECL = os.getenv ("SPECL") or "bin/specl"

function run_spec (yaml, ...)
  return hell.spawn {
    SPECL, "--color=no", "--formatter=report", ...;
    stdin = yaml,
  }
end
