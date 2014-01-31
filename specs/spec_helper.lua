local hell = require "specl.shell"
local std  = require "specl.std"
local path = std.io.catfile ("lib", std.package.path_mark .. ".lua")

package.path = std.package.normalize (path, package.path)

local Object = std.Object

function run_spec (params)
  local SPECL = os.getenv ("SPECL") or "bin/specl"

  -- If params is a string, it is the input text for the subprocess.
  if type (params) == "string" then
    return hell.spawn {
      SPECL, "--color=no";
      stdin = params,
      env = { LUA_PATH=package.path },
    }
  end

  -- If params is a table, fill in the gaps in parameters it names.
  if type (params) == "table" then
    -- The command is made from the array part of params table.
    local cmd = table.concat (params, " ")

    -- But is just options to specl if it begins with a '-'.
    if cmd:sub (1, 1) == "-" then
      cmd = SPECL .. " --color=no " .. cmd
    end

    -- Must pass our package.path through to inferior Specl process.
    local env = params.env or {}
    env.LUA_PATH = env.LUA_PATH or package.path

    return hell.spawn {cmd; env = env, stdin = params.stdin}
  end

  error ("run_spec was expecting a string or table, but got a "..type (params))
end



--[[ ================ ]]--
--[[ Tmpfile manager. ]]--
--[[ ================ ]]--


Tmpfile = Object {
  _type = "Tmpfile",

  _init = function (self, content)
    self.path = os.tmpname ()
    if type (content) == "string" then
      local fh = io.open (self.path, "w")
      fh:write (content)
      fh:close ()
    end
    return self
  end,

  dirname = function (self)
    return self.path:gsub ("/[^/]*$", "", 1)
  end,

  basename = function (self)
    return self.path:gsub (".*/", "")
  end,

  append = function (self, s)
    local fh = io.open (self.path, "a")
    fh:write (s)
    fh:close ()
  end,

  remove = function (self)
    os.remove (self.path)
  end,
}



--[[ ==================== ]]--
--[[ Additional Matchers. ]]--
--[[ ==================== ]]--


do
  local matchers = require "specl.matchers"

  local Matcher, matchers, q =
        matchers.Matcher, matchers.matchers, matchers.stringify

  -- Matches if the type of <actual> is <expect>.
  matchers.instantiate_a = Matcher {
    function (actual, expect)
      return (Object.type (actual) == expect)
    end,

    format_actual = function (actual)
      return " a " .. Object.type (actual)
    end,

    format_expect = function (expect)
      return " a " .. expect .. ", "
    end,
  }
end
