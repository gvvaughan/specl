-- Parse and process command line options.
--
-- Copyright (C) 2013 Gary V. Vaughan
-- Written by Gary V. Vaughan, 2013
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- forward declarations
local optional, required, finished, flag, file, help, version


--[[ ----------------- ]]--
--[[ Helper Functions. ]]--
--[[ ----------------- ]]--


--- Normalise an argument list.
local function normalise (parser, arglist)
  -- First pass: Normalise to long option names, without '=' separators.
  local normal = {}
  local i = 0
  while i < #arglist do
    i = i + 1
    local opt = arglist[i]

    -- Split '--long-option=option-argument'.
    if opt:sub (1, 2) == "--" then
      local x = opt:find ("=", 3, true)
      if x then
        table.insert (normal, opt:sub (1, x - 1))
        table.insert (normal, opt:sub (x + 1))
      else
        table.insert (normal, opt)
      end

    elseif opt:sub (1, 1) == "-" and string.len (opt) > 2 then
      local rest
      repeat
        opt, rest = opt:sub (1, 2), opt:sub (3)

        table.insert (normal, opt)

        -- Split '-xyz' into '-x -yz', and reiterate for '-yz'
        if parser[opt].handler ~= optional and
           parser[opt].handler ~= required then
          opt = "-" .. rest

        -- Split '-xshortargument' into '-x shortargument'.
        else
          table.insert (normal, rest)
          opt = nil
        end
      until opt == nil
    else
      table.insert (normal, opt)
    end
  end

  normal[-1], normal[0]  = arglist[-1], arglist[0]
  return normal
end


local function set (parser, opt, value)
  local key = parser[opt].key

  if type (parser.opts[key]) == "table" then
    table.insert (parser.opts[key], value)
  elseif parser.opts[key] ~= nil then
    parser.opts[key] = { parser.opts[key], value }
  else
    parser.opts[key] = value
  end
end



--[[ ============= ]]--
--[[ Option Types. ]]--
--[[ ============= ]]--


-- Finish option processing.
function finished (parser, arglist, i)
  for opt = i, #arglist do
    table.insert (parser.unrecognized, arglist[i])
  end
  return #arglist
end


-- Option at ARGLIST[I} requires an argument.
function required (parser, arglist, i, value)
  local opt = arglist[i]
  if i + 1 > #arglist then
    parser:opterr ("option '" .. opt .. "' requires an argument")
    return i + 1
  end

  if type (value) == "function" then
    value = value (parser, opt, arglist[i + 1])
  elseif value == nil then
    value = arglist[i + 1]
  end

  set (parser, opt, value)
  return i + 2
end


-- Option at ARGLIST[I] will take an argument only if there is a
-- following entry that does not begin with a '-'.
function optional (parser, arglist, i, value)
  if i + 1 <= #arglist and arglist[i + 1]:sub (1, 1) ~= "-" then
    return parser:required (arglist, i, value)
  end

  if type (value) == "function" then
    value = value (parser, opt, true)
  elseif value == nil then
    value = true
  end

  set (parser, arglist[i], value)
  return i + 1
end


-- Option at ARGLIST[I] is a boolean switch.
function flag (parser, arglist, i, value)
  if type (value) == "function" then
    value = value (parser, opt, true)
  elseif value == nil then
    value = true
  end

  set (parser, arglist[i], value)
  return i + 1
end


function help (parser)
  print (parser.helptext)
  os.exit (0)
end


function version (parser)
  print (parser.versiontext)
  os.exit (0)
end



--[[ =============== ]]--
--[[ Argument Types. ]]--
--[[ =============== ]]--


local boolvals = {
  ["false"] = false, ["true"]  = true,
  ["0"]     = false, ["1"]     = true,
  no        = false, yes       = true,
  n         = false, y         = true,
}


-- Value is one of the keys in BOOLVALS above.
function boolean (parser, opt, optarg)
  return boolvals[optarg]
end


-- Bail out with an error unless OPTARG is an existing file.
function file (parser, opt, optarg)
  h = io.open (optarg)
  if h == nil then
    parser:opterr (optarg .. ": No such file or directory.")
  end
  h:close ()
  return filename
end





--[[ =============== ]]--
--[[ Option Parsing. ]]--
--[[ =============== ]]--


local function opterr (parser, msg)
  local prog = parser.program
  io.stderr:write (prog .. ": error: " .. msg .. "\n")
  io.stderr:write (prog .. ": Try '" .. prog .. " --help' for help.\n")
  os.exit (2)
end


-- Add option handlers to PARSER.
-- @param parser  the parser object
-- @param opts    name of the option as a string, or list of names in a table
-- @param handler callback function when given option is encountered
-- @param value   additional value passed to <handler>
local function on (parser, opts, handler, value)
  if type (opts) == "string" then opts = { opts } end

  normal = {}
  for _, optspec in ipairs (opts) do
    optspec:gsub ("(%S+)",
                  function (opt)
                    -- 'x' => '-x'
                    if string.len (opt) == 1 then
                      opt = "-" .. opt

                    -- 'option-name' => '--option-name'
                    elseif opt:match ("^[^%-]") ~= nil then
                      opt = "--" .. opt
                    end

                    if opt:match ("^%-[^%-]+") ~= nil then
                      -- '-xyz' => '-x -y -z'
                      for i = 2, string.len (opt) do
                        table.insert (normal, "-" .. opt:sub (i, i))
                      end
                    else
                      table.insert (normal, opt)
                    end
                  end)
  end

  -- strip leading '-', and convert non-alphanums to '_'
  key = normal[#normal]:match ("^%-*(.*)$"):gsub ("%W", "_")

  for _, opt in ipairs (normal) do
    parser[opt] = { key = key, handler = handler, value = value }
  end
end


-- Parse ARGLIST with PARSER.
local function parse (parser, arglist)
  local unrecognised = {}

  arglist = normalise (parser, arglist)

  local i = 1
  while i > 0 and i <= #arglist do
    local opt = arglist[i]

    if parser[opt] == nil then
      table.insert (unrecognised, opt)
      i = i + 1

      -- Following non-'-' prefixed argument is an optarg.
      if i <= #arglist and arglist[i]:match "^[^%-]" then
        table.insert (unrecognised, arglist[i])
        i = i + 1
      end

    -- Run option handler functions.
    else
      assert (type (parser[opt].handler) == "function")

      i = parser[opt].handler (parser, arglist, i, parser[opt].value)
    end
  end

  return unrecognised, parser.opts
end


local M = {
  boolean  = boolean,
  flag     = flag,
  finished = finished,
  help     = help,
  optional = optional,
  required = required,
  version  = version,

  on     = on,
  opterr = opterr,
  parse  = parse,
}


M.new = function (spec)
  local parser = setmetatable ({ opts = {} }, { __index = M })

  parser.versiontext, parser.version, parser.helptext, parser.program =
    spec:match ("^([^\n]-(%S+)\n.-)%s*([Uu]sage: (%S+).-)%s*$")

  if parser.versiontext == nil then
    error "OptionParser spec argument must match '<version>\n...Usage: <program>...'"
  end

  parser:on ({"f", "format", "formatter"}, required)
  parser:on ({"h", "help"},                help)
  parser:on ("version",                    version)
  parser:on ("color",                      required)
  parser:on ({"v", "verbose"},             flag)
  parser:on ("--",                         finished)

  return parser
end


return setmetatable (M, {
  __call = function (self, ...)
             return self.new (...)
           end
})
