--- Load Lua stdlib into `specl.std` namespace.
-- Written by Gary V. Vaughan, 2014
--
-- Copyright (c) 2014-2015 Gary V. Vaughan
--
-- Specl is free software distributed under the terms of the MIT license;
-- it may be used for any purpose, including commercial purposes, at
-- absolutely no cost without having to ask permission.
--
-- The only requirement is that if you do use Specl, then you should give
-- credit by including the appropriate copyright notice somewhere in your
-- product or its documentation.
--
-- You should have received a copy of the MIT license along with this
-- program; see the file LICENSE.  If not, a copy can be downloaded from
-- <http://www.opensource.org/licenses/mit-license.html>.

-- First handle debug_init and _DEBUG, being careful not to affect
-- DEBUG disposition of subsequent example loaders for std.debug_init!
local _DEBUG = require "std.debug_init"._DEBUG
_DEBUG.argcheck = true


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
