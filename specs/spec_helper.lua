local hell = require "specl.shell"
local std  = require "specl.std"

math.randomseed (os.time ())

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


TMPDIR = os.getenv "TMPDIR" or os.getenv "TMP" or "/tmp"


local function append (path, ...)
  local n = select ("#", ...)
  if n > 0 then
    local fh = io.open (path, "a")
    std.io.writelines (fh, ...)
    fh:close ()
  end
  return n
end


-- Create a temporary file.
-- @usage
--   h = Tmpfile ()        -- empty generated filename
--   h = Tmpfile (content) -- save *content* to generated filename
--   h = Tmpfile (name, line, line, line) -- write *line*s to *name*
Tmpfile = Object {
  _type = "Tmpfile",

  path = nil,

  _init = function (self, path, ...)
    if select ("#", ...) == 0 then
      self.path = os.tmpname ()
      append (self.path, path, ...)
    else
      self.path = path
      append (path, ...)
    end
    return self
  end,

  dirname = function (self)
    return self.path:gsub ("/[^/]*$", "", 1)
  end,

  basename = function (self)
    return self.path:gsub (".*/", "")
  end,

  append = function (self, ...)
    return append (self.path, ...)
  end,

  remove = function (self)
    return os.remove (self.path)
  end,
}


Tmpdir = Object {
  _type = "Tmpdir",

  tmpdir = std.io.catfile (TMPDIR, "specl_" .. math.random (65536)),

  path = nil,

  _init = function (self, dirname)
    self.path = dirname or self.tmpdir
    os.execute ("mkdir " .. self.path)
    return self
  end,

  file = function (self, name, ...)
    return Tmpfile (std.io.catfile (self.path, name), ...)
  end,

  subdir = function (self, name)
    return Tmpdir (std.io.catfile (self.path, name))
  end,

  remove = function (self)
    return os.remove (self.path)
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
