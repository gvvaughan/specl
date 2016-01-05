-- Bad argument diagnosis helpers.
-- Written by Gary V. Vaughan, 2014
--
-- Copyright (c) 2014-2016 Gary V. Vaughan
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

--[[--
 Additional commands useful for writing API argument specs.

 @module specl.badargs
]]


local std    = require "specl.std"

local split  = std.string.split
local invert, unpack = std.table.invert, std.table.unpack
local getfenv, parsetypes, setfenv, typesplit =
  std.debug.getfenv, std.debug.parsetypes, std.debug.setfenv, std.debug.typesplit


-- Protect against examples misusing or resetting keywords.
local ipairs, pairs, type = ipairs, pairs, type


--- Format typestrings and typelists suitably for display to the user.
-- @tparam string|table types either `?bool|:plain` or `{"bool", ":plain", "nil"}`
-- @treturn string a comma (and or) separated list of any types given
local function showarg (types)
  local argtypes = typesplit (types)

  local t = {}
  for i, argtype in ipairs (argtypes) do
    local container, things = argtype:match "(%S+) of (%S+)"
    if container ~= nil then argtype = container end

    if argtype:match "^#" then
      t[i] = argtype:gsub ("#", "non-empty ")
    elseif argtype == "nil" then
      t[i] = "nil"
    elseif argtype == "any" then
      t[i] = "any value"
    elseif argtype == "func" then
      t[i] = "function"
    elseif argtype == "file" then
      t[i] = "FILE*"
    else
      t[i] = argtype
    end
  end

  local r = table.concat (t, ", "):gsub (", ([^,]+)$", " or %1")
  if r == "nil" then r = "no value" end
  return r
end


--- Return a formatted bad argument string.
-- @string fname base-name of the erroring function
-- @int i argument number
-- @string want expected argument type
-- @string[opt] field field name for error message
-- @string[opt="no value"] got actual argument type
-- @usage
--   expect (fn ()).to_error (badargs.format (fname, 1, "function"))
local function format (fname, i, want, field, got)
  if want == nil and field ~= nil then
    local s = "bad argument #%d to '%s' (invalid field name '%s')"
    return s:format (i, fname, field)
  end

  if got == nil then field, got = nil, field end -- field is optional
  if want == nil then i, want = i - 1, i end     -- numbers only for narg error

  if got == nil and type (want) == "number" then
    local s = "bad argument #%d to '%s' (no more than %d argument%s expected, got %d)"
    return s:format (i + 1, fname, i, i == 1 and "" or "s", want)
  elseif field ~= nil then
    local s = "bad argument #%d to '%s' (%s expected for field '%s', got %s)"
    return s:format (i, fname, want, field, got or "no value")
  end
  return string.format ("bad argument #%d to '%s' (%s expected, got %s)",
                        i, fname, showarg (want), got or "no value")
end


--- Return a formatted bad result string.
-- @string fname base-name of the orroring function
-- @int i result number
-- @string want expected result type
-- @string[opt="no value"] got actual result type
-- @usage
--   expect (fn ()).to_error (badargs.result (fname, 1, "int"))
local function result (fname, i, want, got)
  if want == nil then i, want =  i - 1, i end -- numbers only for narg error

  if got == nil and type (want) == "number" then
    local s = "bad result #%d from '%s' (no more than %d result%s expected, got %d)"
    return s:format (i + 1, fname, i, i == 1 and "" or "s", want)
  end
  return string.format ("bad result #%d from '%s' (%s expected, got %s)",
                        i, fname, showarg (want), got or "no value")
end


--- Return `true` if *t* contains "nil".
-- @tparam table t a table of type names
-- @treturn boolean non-`true` if *t* does not contain "nil"
local function nilok (t)
  for _, v in ipairs (t) do
    if v == "nil" then return true end
  end
end


--- Return `true` if *t* contains "any".
-- @tparam table t a table of type names
-- @treturn boolean non-`true` if *t* does not contain "any"
local function anyok (t)
  for _, v in ipairs (t) do
    if v == "any" then return true end
  end
end


--- Extend argument list to satisfy given argument types.
-- @tparam list arglist list of arguments to extend
-- @int i position in *list* to update
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
local function extendarglist (arglist, i, argtype)
  -- extend with the first valid argument type
  argtype = typesplit (argtype)[1]

  local container, thing = (argtype or ""):match "(%S+) of (%S+)"
  if container ~= nil then argtype = container end

  if argtype == nil then
    arglist[i] = nil
  elseif argtype:sub (1, 1) == ":" then
    arglist[i] = argtype
  elseif argtype == "any" then
    arglist[i] = ":any"
  elseif argtype == "boolean" then
    arglist[i] = true
  elseif argtype == "file" then
    arglist[i] = io.stderr
  elseif argtype == "func" or argtype == "function" then
    arglist[i] = ipairs
  elseif argtype == "int" then
    arglist[i] = 42
  elseif argtype:sub (1, 1) == "#" then
    arglist[i] = {}
  elseif argtype == "list" or argtype == "table" then
    arglist[i] = {}
  elseif argtype == "number" then
    arglist[i] = 2.718281828
  elseif argtype == "string" then
    arglist[i] = "foo"
  elseif argtype == "object" then
    arglist[i] = setmetatable ({}, {_type = "Fnord"})
  elseif argtype:match "^_*[A-Z]" then
    -- Assume an object of type 'argtype' was expected.
    arglist[i] = setmetatable ({}, {_type = argtype})
  end

  if (argtype or ""):sub (1, 1) == "#" then
    thing = thing or "Fnord"
    extendarglist (arglist[i], 1, thing)
    if arglist[i][1] == nil then
      extendarglist (arglist[i], 1, thing:match "(%S+)s$")
    end
  end
end


--- Extend argument list to not match any given argument types.
-- @tparam list arglist list of arguments to extend
-- @int i position in *list* to update
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
local function poisonarglist (arglist, i, argtype)
  local argtypes = {}
  for i, v in ipairs (typesplit (argtype)) do argtypes[v] = i end

  if argtypes.boolean == nil then
    arglist[i] = false
  elseif argtypes.int == nil then
    arglist[i] = -1
  elseif argtypes.number == nil then
    arglist[i] = -1.234
  elseif argtypes.string == nil then
    arglist[i] = "foo"
  elseif argtypes.table == nil and argtypes.list == nil then
    arglist[i] = {}
  elseif argtypes["#table"] == nil then
    arglist[i] = {key = "value"}
  elseif argtypes["#list"] == nil then
    arglist[i] = {"element"}
  elseif argtypes.file == nil then
    arglist[i] = io.stderr
  elseif argtypes.any == nil then
    arglist[i] = nil
  end
end


--- Extend argument list container to not match any given argument types.
-- @tparam list arglist list of arguments to extend
-- @int i position in *list* to with container
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
local function poisoncontainerarglist (arglist, i, argtype)
  local container, thing
  for i, v in ipairs (typesplit (argtype)) do
    container, thing = v:match "(%S+) of (%S+)"
    if container ~= nil then break end
  end

  if container == nil then return nil end

  local poison = setmetatable ({}, { _type = container })
  extendarglist (poison, 1, thing)
  if poison[1] == nil then
    extendarglist (poison, 1, thing:match "(%S+)s$")
  end
  poisonarglist (poison, 2, thing)
  if poison[2] == nil then
    poisonarglist (poison, 2, thing:match "(%S+)s$")
  end
  arglist[i] = poison
  return (container .. " of " .. thing)
end


--- Return a suitable bad argument error string.
-- @int i bad argument index
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
-- @treturn string nicely formatted bad argument error string
local function diagnose_badarg_description (i, argtype)
  return "it diagnoses argument #" .. tostring (i) .. " type not " .. showarg (argtype)
end


--- Generate examples to ensure a function satisfies its type signature.
-- The *decl* string is a subset of the format used by`std.debug.argscheck`,
-- the function name expected from argument error messages followed by a
-- comma-delimited list of types in parentheses:
--
--     diagnose ("string.format (string, ?any...)", string.format)
--
-- A leading question mark denotes that a nil argument is acceptable in
-- that position, and the trailing `...` denotes that any number of
-- additional arguments that match this type may follow.  If an argument
-- can be omitted entirely, as opposed to passing a `nil`, then surround
-- it with brackets:
--
--     diagnose ("table.insert (table, [int], ?any)", table.insert)
--
-- Finally, if an argument may be one of several types, list all options
-- with `|` (pipe) between them:
--
--     diagnose ("string.gsub (string, string, string|func, [int])",
--               string.gsub)
--
-- Type names can be the name of a primitive Lua type, a stdlib object
-- name (stored in the `_type` field of the metatable, usually beginning
-- with an upper-case letter), or one of the special types below:
--
--     #table    accept any non-empty table
--     any       accept any non-nil argument type
--     file      accept an open file object
--     function  accept a function, or object with a __call metamethod
--     int       accept an integer valued number
--     list      accept a table where all keys are in a contiguous 1-base range
--     #list     accept any non-empty list
--     object    accept any std.Object derived type
--     :foo      accept only the exact string ":foo", for any :-prefix string
--
-- @tparam string decl argument type declaration
-- @func fn the function being specified
local function diagnose (decl, fn)
  -- Parse "fname (argtype, argtype, argtype...)".
  local fname = (decl:match "^%s*([%w_][%.%d%w_]*)") or "fn"
  local typelist = decl:match "%s*%(%s*(.-)%s*%)" or decl
  if typelist == "" then
    typelist = {}
  elseif typelist then
    typelist = split (typelist, "%s*,%s*")
  end

  local typemin, specs = #typelist, parsetypes (typelist)
  for _, v in pairs (typelist) do
    if v:match "%[.*%]" then typemin = typemin - 1 end
  end

  local fin = specs[#specs]

  -- Ensure the following functions are executed in the environment that
  -- this function is inside.
  setfenv (examples, getfenv ())
  setfenv (expect, getfenv ())

  local arglist = {}
  for i, argtype in ipairs (specs) do
    if not nilok (argtype) and i <= typemin and (not fin or i < typemin) then
      examples {
        ["it diagnoses missing argument #" .. tostring (i)] = function ()
          expect (fn (unpack (arglist))).to_raise.any_of {
	    format ("?", i, argtype),	-- recent LuaJIT
	    format (fname, i, argtype),	-- PUC-Rio Lua
          }
        end
      }
    end
    -- DRY! checking for nil valued arg diagnosis is the same as missing arg above
    if not anyok (argtype) then
      poisonarglist (arglist, i, argtype)
      examples {
	[diagnose_badarg_description (i, argtype)] = function ()
          expect (fn (unpack (arglist))).to_raise.any_of {
	    format ("?", i, argtype, showarg (type (arglist[i]))),
	    format (fname, i, argtype, showarg (type (arglist[i]))),
          }
	end
      }
      local containertype = poisoncontainerarglist (arglist, i, argtype)
      if containertype ~= nil then
	local s = "bad argument #%d to '%s' (%s expected, got %s at index 2"
        examples {
	  ["it diagnoses argument #" .. tostring (i) .. " type not " .. containertype] =
	    function ()
	      expect (fn (unpack (arglist))).to_raise.any_of {
	        s:format (i, "?", containertype, type (arglist[i][2])),
	        s:format (i, fname, containertype, type (arglist[i][2])),
	      }
	    end
	}
      end
    end
    extendarglist (arglist, i, argtype)
  end

  if specs.dots == nil then
    -- Check diagnosis of too many arguments when the final parameter
    -- does not end with a '...'.
    local max = #specs
    extendarglist (arglist, max, specs[#specs])
    arglist[max + 1] = false
    examples {
      ["it diagnoses more than maximum of " .. max .. " arguments"] = function ()
        expect (fn (unpack (arglist))).to_raise.any_of {
	  format (fname, max + 1),
	  format ("?", max + 1),
        }
      end
    }
  end
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


--- @export
return {
  diagnose = diagnose,
  format   = format,
  result   = result,
}
