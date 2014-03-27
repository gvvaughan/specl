local hell = require "specl.shell"
local std  = require "specl.std"

package.path = std.package.normalize ("lib/?.lua", package.path)

local Object = std.Object

function spawn_specl (params)
  local SPECL = os.getenv ("SPECL") or "bin/specl"

  -- If params is a string, it is the input text for the subprocess.
  if type (params) == "string" then
    return hell.spawn {
      SPECL, "--color=no", "-";
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

    if params.stdin then cmd = cmd .. " -" end

    -- Must pass our package.path through to inferior Specl process.
    local env = params.env or {}
    env.LUA_PATH = env.LUA_PATH or package.path

    return hell.spawn {cmd; env = env, stdin = params.stdin}
  end

  error ("run_spec was expecting a string or table, but got a "..type (params))
end


local inprocess = require "specl.inprocess"
local Main      = require "specl.main"

function run_spec (params)
  -- If params is a string, it is the input text for the subprocess.
  if type (params) == "string" then
    return inprocess.call (Main, {"--color=no", "-"}, params)
  end

  -- If params is a table, fill in the gaps in parameters it names.
  if type (params) == "table" then
    -- The command is made from the array part of params table.
    local argt = {"--color=no"}
    for _, e in ipairs (params) do argt[#argt + 1] = e end

    if params.stdin then argt[#argt + 1] = "-" end

    local proc = inprocess.call (Main, argt, params.stdin)
    return proc
  end

  error ("inprocess_spec was expecting a string or table, but got a "..type (params))
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
    function (self, actual, expect)
      return (Object.type (actual) == expect)
    end,

    format_expect = function (self, expect)
      return " a " .. expect .. ", "
    end,

    format_actual = function (self, actual)
      return " a " .. Object.type (actual)
    end,
  }
end
