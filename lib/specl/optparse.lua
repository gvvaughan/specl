-- Parse and process command line options.
-- Written by Gary V. Vaughan, 2013
--
-- Copyright (C) 2013-2014 Gary V. Vaughan
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
local optional, required, finished, flag, help, version
local boolean, file


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
	  if string.len (rest) > 0 then
            opt = "-" .. rest
	  else
	    opt = nil
	  end

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
  for opt = i + 1, #arglist do
    table.insert (parser.unrecognised, arglist[opt])
  end
  return 1 + #arglist
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
    value = value (parser, opt, nil)
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
  if optarg == nil then optarg = "1" end -- default to truthy
  local b = boolvals[tostring (optarg):lower ()]
  if b == nil then
    parser:opterr (optarg .. ": Not a valid argument to " ..opt[1] .. ".")
  end
  return b
end


-- Bail out with an error unless OPTARG is an existing file.
-- FIXME: this only checks whether the file has read permissions
function file (parser, opt, optarg)
  local h, errmsg = io.open (optarg, "r")
  if h == nil then
    parser:opterr (optarg .. ": " .. errmsg)
    return nil
  end
  h:close ()
  return optarg
end



--[[ =============== ]]--
--[[ Option Parsing. ]]--
--[[ =============== ]]--


local function opterr (parser, msg)
  local prog = parser.program
  -- Ensure final period.
  if msg:match ("%.$") == nil then msg = msg .. "." end
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
  handler = handler or flag -- unspecified options behave as flags

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
  parser.unrecognised = {}

  arglist = normalise (parser, arglist)

  local i = 1
  while i > 0 and i <= #arglist do
    local opt = arglist[i]

    if parser[opt] == nil then
      table.insert (parser.unrecognised, opt)
      i = i + 1

      -- Following non-'-' prefixed argument is an optarg.
      if i <= #arglist and arglist[i]:match "^[^%-]" then
        table.insert (parser.unrecognised, arglist[i])
        i = i + 1
      end

    -- Run option handler functions.
    else
      assert (type (parser[opt].handler) == "function")

      i = parser[opt].handler (parser, arglist, i, parser[opt].value)
    end
  end

  return parser.unrecognised, parser.opts
end


local M = {
  boolean  = boolean,
  file     = file,
  finished = finished,
  flag     = flag,
  help     = help,
  optional = optional,
  required = required,
  version  = version,

  on     = on,
  opterr = opterr,
  parse  = parse,
}


local function set_handler (current, new)
  assert (current == nil, "only one handler per option")
  return new
end


-- Instantiate a new parser, ready to parse the documented options in SPEC.
M.new = function (spec)
  local parser = setmetatable ({ opts = {} }, { __index = M })

  parser.versiontext, parser.version, parser.helptext, parser.program =
    spec:match ("^([^\n]-(%S+)\n.-)%s*([Uu]sage: (%S+).-)%s*$")

  if parser.versiontext == nil then
    error ("OptionParser spec argument must match '<version>\\n" ..
           "...Usage: <program>...'")
  end

  -- Collect helptext lines that begin with two or more spaces followed
  -- by a '-'.
  local specs = {}
  parser.helptext:gsub ("\n  %s*(%-[^\n]+)",
                        function (spec) table.insert (specs, spec) end)

  -- Register option handlers according to the help text.
  for _, spec in ipairs (specs) do
    local options, handler = {}

    -- Loop around each '-' prefixed option on this line.
    while spec:sub (1, 1) == "-" do

      -- Capture end of options processing marker.
      if spec:match "^%-%-,?%s" then
        handler = set_handler (handler, finished)

      -- Capture optional argument in the option string.
      elseif spec:match "^%-[%-%w]+=%[.+%],?%s" then
        handler = set_handler (handler, optional)

      -- Capture required argument in the option string.
      elseif spec:match "^%-[%-%w]+=%S+,?%s" then
        handler = set_handler (handler, required)

      -- Capture any specially handled arguments.
      elseif spec:match "^%-%-help,?%s" then
        handler = set_handler (handler, help)

      elseif spec:match "^%-%-version,?%s" then
        handler = set_handler (handler, version)
      end

      -- Consume argument spec, now that it was processed above.
      spec = spec:gsub ("^(%-[%-%w]+)=%S+%s", "%1 ")

      -- Consume short option.
      local _, c = spec:gsub ("^%-([-%w]),?%s+(.*)$",
                              function (opt, rest)
                                if opt == "-" then opt = "--" end
                                table.insert (options, opt)
                                spec = rest
                              end)

      -- Be careful not to consume more than one option per iteration,
      -- otherwise we might miss a handler test at the next loop.
      if c == 0 then
        -- Consume long option.
        spec:gsub ("^%-%-([%-%w]+),?%s+(.*)$",
                   function (opt, rest)
                     table.insert (options, opt)
                     spec = rest
                   end)
      end
    end

    -- Unless specified otherwise, treat each option as a flag.
    parser:on (options, handler or flag)
  end

  return parser
end


-- Support calling the returned table:
--   local OptionParser = require "specl.optparse"
--   local parser = OptionParser (helptext)
return setmetatable (M, {
  __call = function (self, ...)
             return self.new (...)
           end
})
