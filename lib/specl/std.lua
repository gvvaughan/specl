--- Load Lua stdlib into `specl.std` namespace.

-- First handle debug_init and _DEBUG, being careful not to affect
-- DEBUG disposition of subsequent example loaders for std.debug_init!
local _DEBUG = require "std.debug_init"._DEBUG
_DEBUG.argcheck = false


-- Handle to the stdlib modules.
local M = require "std"

-- Check minimum version requirement.
M.require ("std", "41")


local F = M.functional
local filter, lambda, map, reduce = F.filter, F.lambda, F.map, F.reduce
local set = M.operator.set


-- Cache submodule handles into local `std` above.
reduce (set, M,
  map (lambda '_2, require ("std." .. _2)', {
    "container",
    "debug",
    "functional",
    "io",
    "list",
    "math",
    "object",
    "optparse",
    "package",
    "set",
    "strbuf",
    "string",
    "table",
    "tree",
  })
)



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--

-- Don't prevent examples from loading a different stdlib.
map (function (e) package.loaded[e] = nil end,
     filter (lambda '|k| k:match "^std%." or k == "std"', package.loaded))

return M
