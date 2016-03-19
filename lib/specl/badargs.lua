-- Bad argument diagnosis helpers.
-- Written by Gary V. Vaughan, 2014
--
-- Copyright (c) 2014-2016 Gary V. Vaughan
--
-- This program is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation; either version 3, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program; see the file COPYING.  If not, a copy can be downloaded from
-- <http://www.gnu.org/licenses/gpl.html>.

--[[--
 Additional commands useful for writing API argument specs.

 @module specl.badargs
]]


local _ = {
  compat	= require "specl.compat",
  std		= require "specl.std",
}

local _ENV = {
  getfenv	= _.compat.getfenv,
  ipairs	= ipairs,
  pairs		= pairs,
  setfenv	= setfenv or function () end,
  setmetatable	= setmetatable,
  type		= type,

  STDERR	= io.stderr,
  INF		= math.huge,
  format	= string.format,
  gsub		= string.gsub,
  match		= string.match,
  sub		= string.sub,
  concat	= table.concat,
  insert	= table.insert,
  remove	= table.remove,
  unpack	= table.unpack or unpack,

  invert	= _.std.table.invert,
  split		= _.std.string.split,
}
setfenv (1, _ENV)
local setfenv = _.compat.setfenv
_ = nil



--- Return the last element of a list-like table.
-- @tparam list l a list-like table
-- @return the last element of *l*
local function last (l)
  return l[#l]
end


--- Efficiently return a shallow copy of a table.
-- @tparam table t a table
-- @treturn table a new table with a shallow copy of elements from *t*
local function copy (t)
  local r = {}
  for k, v in pairs (t) do r[k] = v end
  return r
end


--- Return a normalized list of types.
-- Initial "?' in any list element is removed, but causes a "nil" item
-- to be added to the normalized list; "func" is expanded to "function",
-- "bool" to "booleand" and then an ordered list of resulting unique type
-- names returned.
-- @tparam list typelist a list of type names
-- @treturn table an ordered list of unique type names
local function normalize (typelist)
  local i, r, add_nil = 1, {}, false
  for _, v in ipairs (typelist) do
    if match (v, "^%?(.+)") then
      add_nil = true
      v = sub (v, 2)
    end
    v = ({ func = "function", bool = "boolean" })[v] or v
    if not r[v] then
      r[v] = i
      i = i + 1
    end
  end
  if add_nil then
    r["nil"] = r["nil"] or i
  end
  return invert (r)
end


--- Merge and normalize any number of type list and type strings.
-- @tparam string|table ... either `?bool|:plain` or `{"bool", ":plain", "nil"}`
-- @treturn table an ordered list of unique type names from all
--   arguments
local function merge (...)
  local i, t = 1, {}
  for _, v in ipairs {...} do
    if type (v) == "table" then v = concat (v, "|") end
    gsub (v, "([^|]+)", function (m) t[i] = m; i = i + 1 end)
  end
  return normalize (t)
end


--- Return a list of valid argument type permutations from a typelist.
-- Elements in square brackets denote optional parameters, which can be
-- omitted from the calling argument list, causing the following
-- parameters to be bound as if `nil` had been passed to the bracketed
-- parameter. Consequently, there can be several valid argument type
-- lists for such a function; all of which are returned by this
-- function.
-- @tparam list typelist a normalized list of type names
-- @treturn list all valid permutations of *typelist*
local function permutations (typelist)
  local p, sentinel = {{}}, {"optional arg"}
  for i, v in ipairs (typelist) do
    -- Remove sentinels before appending 'v' to each list.
    for _, v in ipairs (p) do
      if v[#v] == sentinel then remove (v) end
    end

    local opt = match (v, "%[(.+)%]")
    if opt == nil then
      -- Append non-optional type-spec to each permutation.
      for b = 1, #p do insert (p[b], v) end
    else
      -- Duplicate all existing permutations, and add optional type-spec
      -- to the unduplicated permutations.
      local o = #p
      for b = 1, o do
        p[b + o] = copy (p[b])
	insert (p[b], opt)
      end

      -- Leave a marker for optional argument in final position.
      for _, v in ipairs (p) do
        insert (v, sentinel)
      end
    end
  end

  -- Replace sentinels with "nil".
  for i, v in ipairs (p) do
    if v[#v] == sentinel then
      remove (v)
      if #v > 0 then
        v[#v] = v[#v] .. "|nil"
      else
        v[1] = "nil"
      end
    end
  end

  return p
end


--- Compact permutation list into a list of valid types at each argument.
-- Eliminate bracked types by combining all valid types at each position
-- for all permutations of *typelist*.
-- @tparam list typelist a normalized list of type names
-- @treturn list valid types for each positional parameter
local function compact (types)
  local p = permutations (types)
  local i, r = 1, {}

  local keepgoing = true
  while keepgoing do
    local u = {}
    for _, t in ipairs (p) do
      u[#u + 1] = t[i]
    end
    keepgoing = #u > 0
    if keepgoing then
      r[i] = merge (unpack (u))
    end
    i = i + 1
  end

  return r
end


--- Format typestrings and typelists suitably for display to the user.
-- @tparam string|table ... either `?bool|:plain` or `{"bool", ":plain", "nil"}`
-- @treturn string a comma (and or) separated list of any types given
local function showarg (...)
  local argtypes = merge (...)

  local t = {}
  for i, argtype in ipairs (argtypes) do
    local container, things = match (argtype, "(%S+) of (%S+)")
    if container ~= nil then argtype = container end

    if match (argtype, "^#") then
      t[i] = gsub (argtype, "#", "non-empty ")
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

  local r = gsub (concat (t, ", "), ", ([^,]+)$", " or %1")
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
local function badargs_format (fname, i, want, field, got)
  if want == nil and field ~= nil then
    local s = "bad argument #%d to '%s' (invalid field name '%s')"
    return format (s, i, fname, field)
  end

  if got == nil then field, got = nil, field end -- field is optional
  if want == nil then i, want = i - 1, i end     -- numbers only for narg error

  if got == nil and type (want) == "number" then
    local s = "bad argument #%d to '%s' (no more than %d argument%s expected, got %d)"
    return format (s, i + 1, fname, i, i == 1 and "" or "s", want)
  elseif field ~= nil then
    local s = "bad argument #%d to '%s' (%s expected for field '%s', got %s)"
    return format (s, i, fname, want, field, got or "no value")
  end
  return format ("bad argument #%d to '%s' (%s expected, got %s)",
                 i, fname, showarg (want), got or "no value")
end


--- Return `true` if *typelist* contains "nil".
-- @tparam list typelist a normalized list of type names
-- @treturn boolean non-`true` if *typelist* does not contain "nil"
local function nilok (typelist)
  for _, v in ipairs (typelist) do
    if v == "nil" then return true end
  end
end


--- Return `true` if *typelist* contains "any".
-- @tparam list typelist a normalized list of type names
-- @treturn boolean non-`true` if *typelist* does not contain "any"
local function anyok (typelist)
  for _, v in ipairs (typelist) do
    if v == "any" then return true end
  end
end


--- Extend argument list to satisfy given argument types.
-- @tparam list arglist list of arguments to extend
-- @int i position in *list* to update
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
local function extendarglist (arglist, i, argtype)
  -- extend with the first valid argument type
  argtype = merge (argtype)[1]

  local container, thing = match (argtype or "", "(%S+) of (%S+)")
  if container ~= nil then argtype = container end

  if argtype == nil then
    arglist[i] = nil
  elseif sub (argtype, 1, 1) == ":" then
    arglist[i] = argtype
  elseif argtype == "any" then
    arglist[i] = ":any"
  elseif argtype == "boolean" then
    arglist[i] = true
  elseif argtype == "file" then
    arglist[i] = STDERR
  elseif argtype == "func" or argtype == "function" then
    arglist[i] = ipairs
  elseif argtype == "int" then
    arglist[i] = 42
  elseif sub (argtype, 1, 1) == "#" then
    arglist[i] = {}
  elseif argtype == "list" or argtype == "table" then
    arglist[i] = {}
  elseif argtype == "number" then
    arglist[i] = 2.718281828
  elseif argtype == "string" then
    arglist[i] = "foo"
  elseif argtype == "object" then
    arglist[i] = setmetatable ({}, {_type = "Fnord"})
  elseif match (argtype, "^_*[A-Z]") then
    -- Assume an object of type 'argtype' was expected.
    arglist[i] = setmetatable ({}, {_type = argtype})
  end

  if sub (argtype or "", 1, 1) == "#" then
    thing = thing or "Fnord"
    extendarglist (arglist[i], 1, thing)
    if arglist[i][1] == nil then
      extendarglist (arglist[i], 1, match (thing, "(%S+)s$"))
    end
  end
end


--- Extend argument list to not match any given argument types.
-- @tparam list arglist list of arguments to extend
-- @int i position in *list* to update
-- @tparam string|table argtype either `?bool|:plain` or `{"bool", ":plain", "nil"}`
local function poisonarglist (arglist, i, argtype)
  local argtypes = {}
  for i, v in ipairs (merge (argtype)) do argtypes[v] = i end

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
    arglist[i] = STDERR
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
  for i, v in ipairs (merge (argtype)) do
    container, thing = match (v, "(%S+) of (%S+)")
    if container ~= nil then break end
  end

  if container == nil then return nil end

  local poison = setmetatable ({}, { _type = container })
  extendarglist (poison, 1, thing)
  if poison[1] == nil then
    extendarglist (poison, 1, match (thing, "(%S+)s$"))
  end
  poisonarglist (poison, 2, thing)
  if poison[2] == nil then
    poisonarglist (poison, 2, match (thing, "(%S+)s$"))
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
-- @func fn the function being specified
-- @tparam diagnose_decl decl argument type declaration
local function diagnose (fn, decl)
  -- Parse "fname (argtype, argtype, argtype...)".
  local fname = match (decl, "^%s*([%w_][%.%d%w_]*)") or "fn"
  local types = match (decl, "%s*%(%s*(.-)%s*%)") or decl
  if types == "" then
    types = {}
  elseif types then
    types = split (types, ",%s*")
  end

  local max, fin = #types, match (last (types) or "", "^(.+)%*$")
  if fin then
    types[max] = fin
    if fin ~= "any" then types[max + 1] = fin end
    max = INF
  end

  local typemin, type_specs = #types, compact (types)
  for _, v in pairs (types) do
    if match (v, "%[.*%]") then typemin = typemin - 1 end
  end

  -- Ensure the following functions are executed in the environment that
  -- this function is inside.
  setfenv (examples, getfenv ())
  setfenv (expect, getfenv ())

  local arglist = {}
  for i, argtype in ipairs (type_specs) do
    if not nilok (argtype) and i <= typemin and (not fin or i < typemin) then
      examples {
        ["it diagnoses missing argument #" .. tostring (i)] = function ()
          expect (fn (unpack (arglist))).to_raise.any_of {
	    badargs_format ("?", i, argtype),	-- recent LuaJIT
	    badargs_format (fname, i, argtype),	-- PUC-Rio Lua
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
	    badargs_format ("?", i, argtype, showarg (type (arglist[i]))),
	    badargs_format (fname, i, argtype, showarg (type (arglist[i]))),
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
	        format (s, i, "?", containertype, type (arglist[i][2])),
	        format (s, i, fname, containertype, type (arglist[i][2])),
	      }
	    end
	}
      end
    end
    extendarglist (arglist, i, argtype)
  end

  if max ~= INF then
    -- Check diagnosis of too many arguments when the final parameter
    -- does not end with a '*'.
    extendarglist (arglist, max, last (type_specs))
    arglist[max + 1] = false
    examples {
      ["it diagnoses more than maximum of " .. max .. " arguments"] = function ()
        expect (fn (unpack (arglist))).to_raise.any_of {
	  badargs_format (fname, max + 1),
	  badargs_format ("?", max + 1),
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
  format   = badargs_format,
  diagnose = diagnose,
}
