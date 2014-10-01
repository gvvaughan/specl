--- Load Lua stdlib into `specl.std` namespace.

-- First handle debug_init and _DEBUG, being careful not to affect
-- DEBUG disposition of subsequent example loaders for std.debug_init!
local init = require "std.debug_init"
init._DEBUG = false


-- Handle to the stdlib modules.
local M = require "std"

-- Check minimum version requirement.
M.string.require_version ("std", "40")


local F = M.functional
local filter, lambda, map = F.filter, F.lambda, F.map
local elems = M.list.elems


-- Cache submodule handles into local `std` above.
map (function (n) M[n] = require ("std." .. n) end, elems, {
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


M.io.dirname = M.io.dirname or function (path)
  return path:gsub (M.io.catfile ("", "[^", "]*$"), "")
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--

-- Don't prevent examples from loading a different stdlib.
map (function (e) package.loaded[e] = nil end, M.list.elems,
     filter (function (k) return (k == "std") or (k:match "^std%.") end, pairs,
             package.loaded))

return M
