-- Load Specl spec-files into native Lua tables.
--
-- Copyright (c) 2013 Free Software Foundation, Inc.
-- Written by Gary V. Vaughan, 2013
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.


local macro = require "macro"
local util  = require "specl.util"
local yaml  = require "yaml"


local TAG_PREFIX = "tag:yaml.org,2002:"
local null       = { type = "LYAML null" }


-- Capture errors thrown by expectations.
macro.define ("expect", function (get)
  local out
  if get:peek (1) == "(" then
    get:expecting "("
    local expr = get:upto ")"
    out = " (pcall (function () return " .. tostring (expr) .. " end))"
  end
  return out, true -- pass through 'expect' token
end)


-- Metatable for Parser objects.
local parser_mt = {
  __index = {
    -- Return the type of the current event.
    type = function (self)
      return tostring (self.event.type)
    end,

    -- Raise a parse error.
    error = function (self, errmsg)
      io.stderr:write (self.filename .. ":" .. self.mark.line .. ":" ..
                       self.mark.column .. ": " .. errmsg .. "\n")
      os.exit (1)
    end,

    -- Compile S into a callable function.
    compile = function (self, s)
      local f, errmsg = macro.substitute_tostring (s)
      if f == nil then
        -- Replace the error message from macro; it's just internal gunk.
        errmsg = self.filename .. ":" .. tostring (self.mark.line) ..
                 ": parse error near 'expect', while collecting arguments"
      else
        f, errmsg = loadstring (f)
      end
      if f == nil then
        local line, msg = errmsg:match ('%[string "[^"]*"%]:([1-9][0-9]*): (.*)$')
        if msg ~= nil then
          line = line + self.mark.line - 1
          errmsg = self.filename .. ":" .. tostring (line) .. ": " .. msg
        end
      end
      if errmsg ~= nil then
        io.stderr:write (errmsg .. "\n")
        os.exit (1)
      end
      return f
    end,

    -- Refetch the original lua format, for accurate error line numbers.
    refetch = function (self, value, event)
      -- Mark indices are character based, but Lua patterns are byte
      -- based, which means refetching doesn't work in the presence of
      -- unicode characters :(
      if opts.unicode then return value end
      value = self.input:sub (event.start_mark.index, event.end_mark.index)
      if event.style == "DOUBLE_QUOTED" then
        value = table.concat {value:match ([[^(%s*)"(.-)"%s*$]])}
      elseif event.style == "SINGLE_QUOTED" then
        value = table.concat {value:match ([[^(%s*)'(.-)'%s*$]])}
      elseif event.style == "LITERAL" then
        value = table.concat {value:match ([[^(%s*)[|](.-)%s*$]])}
      elseif event.style == "FOLDED" then
        value = table.concat {value:match ([[^(%s*)>(.-)%s*$]])}
      end
      return value
    end,

    -- Save node in the anchor table for reference in future ALIASes.
    add_anchor = function (self, node)
      if self.event.anchor ~= nil then
        self.anchors[self.event.anchor] = node
      end
    end,

    -- Fetch the next event.
    parse = function (self)
      local ok, event = pcall (self.next)
      if not ok then
        -- if ok is nil, then event is a parser error from libYAML.
        self:error (event:gsub (" at document: .*$", ""))
      end
      self.event = event
      self.mark  = {
        line   = tostring (self.event.start_mark.line + 1),
        column = tostring (self.event.start_mark.column + 1),
      }
      return self:type ()
    end,

    -- Construct a Lua hash table from following events.
    load_map = function (self)
      local map = {}
      self:add_anchor (map)
      -- Inject the preamble into before node of the outermost map.
      if self.preamble then
        map.before, self.preamble = self.preamble, nil
      end
      while true do
        local key = self:load_node ()
        if key == nil then break end
        local value, event = self:load_node ()
        if value == nil then
          return self:error ("unexpected " .. self:type () .. " event")
        end
        if key == "before" then
          -- Be careful not to overwrite injected preamble.
          value = self:refetch (value, event)
          map.before = table.concat {map.before or "", value}
        elseif value == "" then
          map[key] = self:compile ("pending ()")
        elseif type (value) == "string" then
          map[key] = self:compile (self:refetch (value, event))
        else
          map[key] = value
        end
      end
      -- Delayed compilation of before, having injecting preamble now.
      if type (map.before) == "string" then
        map.before = self:compile (map.before)
      end
      return map
    end,

    -- Construct a Lua array table from following events.
    load_sequence = function (self)
      local sequence = {}
      self:add_anchor (sequence)
      while true do
        local node = self:load_node ()
        if node == nil then
          break
        elseif node.before then
          sequence.before = node.before
        elseif node.after then
          sequence.after = node.after
        else
          sequence[#sequence + 1] = node
        end
      end
      return sequence
    end,

    -- Construct a primitive type from the current event.
    load_scalar = function (self)
      local value = self.event.value
      local tag   = self.event.tag
      if tag then
        tag = tag:match ("^" .. TAG_PREFIX .. "(.*)$")
        if tag == "str" then
          -- value is already a string
        elseif tag == "int" or tag == "float" then
          value = tonumber (value)
        elseif tag == "bool" then
          value = (value == "true" or value == "yes")
        end
      elseif self.event.style == "PLAIN" then
        if value == "~" then
          value = null
        elseif value == "true" or value == "yes" then
          value = true
        elseif value == "false" or value == "no" then
          value = false
        else
          local number = tonumber (value)
          if number then value = number end
        end
      end
      self:add_anchor (value)
      return value, self.event
    end,

    load_alias = function (self)
      local anchor = self.event.anchor
      if self.anchors[anchor] == nil then
        return self:error ("invalid reference: " .. tostring (anchor))
      end
      return self.anchors[anchor]
    end,

    load_node = function (self)
      local dispatch  = {
        SCALAR         = self.load_scalar,
        ALIAS          = self.load_alias,
        MAPPING_START  = self.load_map,
        SEQUENCE_START = self.load_sequence,
        MAPPING_END    = util.nop,
        SEQUENCE_END   = util.nop,
        DOCUMENT_END   = util.nop,
      }

      local event = self:parse ()
      if dispatch[event] == nil then
        return self:error ("invalid event: " .. self:type ())
      end
     return dispatch[event] (self)
    end,
  },
}


-- Parser object constructor.
local function Parser (filename, s)
  local object = {
    anchors  = {},
    filename = filename:gsub ("^%./", ""),
    input    = s,
    mark     = { line = "0", column = "0" },
    next     = yaml.parser (s),

    -- Used to simplify requiring from the spec file directory.
    preamble = "package.path = \"" ..
               filename:gsub ("[^/]+$", "?.lua;") ..
               "\" .. package.path\n",
  }
  return setmetatable (object, parser_mt)
end


local function load (filename, s)
  local documents = {}
  local parser    = Parser (filename, s)

  if parser:parse () ~= "STREAM_START" then
    return parser:error ("expecting STREAM_START event, but got " ..
                         parser:type ())
  end

  while parser:parse () ~= "STREAM_END" do
    local document = parser:load_node ()
    if document == nil then
      return parser:error ("unexpected " .. parser:type () .. " event")
    end

    if parser:parse () ~= "DOCUMENT_END" then
      return parser:error ("expecting DOCUMENT_END event, but got " ..
                           parser:type ())
    end

    -- save document
    documents[#documents + 1] = document

    -- Hoist document-level befores and afters.
    documents.before, document.before = document.before, nil
    documents.after, document.after = document.after, nil

    -- reset anchor table
    parser.anchors = {}
  end

  return documents
end


--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--

local M = {
  load = load,
  null = null,
}

return M
