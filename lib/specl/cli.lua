--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

--[[--
 The entry point of the single file `specl` that smush bundles.

 @module specl.cli
]]

return {
   -- Run specl with the command line *arg*, which exits with its status.
   main = function(arg)
      return require 'specl.main'(arg):execute()
   end,
}
