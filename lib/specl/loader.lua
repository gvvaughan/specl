--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2013-2023 Gary V. Vaughan
]]

local format = string.format
local gsub = string.gsub
local match = string.match
local sub = string.sub

local macro = require 'macro'
local yaml = require 'yaml'

local compat = require 'specl.compat'
local expect = require 'specl.expect'
local std = require 'specl.std'
local util = require 'specl.util'

local load, searchpath = compat.load, compat.searchpath
local catfile, dirname, slurp = std.io.catfile, std.io.dirname, std.io.slurp
local dirsep, normalize, pathsep, path_mark = 
   std.package.dirsep, std.package.normalize, std.package.pathsep, std.package.path_mark
local escape_pattern = std.string.escape_pattern
local nop = util.nop


local TAG_PREFIX = 'tag:yaml.org,2002:'
local null = {type='LYAML null'}


-- A list of directories we've loaded yaml spec-files from.   Any other
-- files required from these directories are macro-expanded during
-- loading.
local spec_path = ''


--- Search spec_path for module name.
-- @string name module name to load
-- @return compiled module as a function, or error message if not found
local function expandmacros(name)
   local errbuf = {}

   -- Use spec_path by default, but also package.path for specl submodules.
   local search_path = spec_path
   if match(name, '^specl%.') then
      search_path = search_path .. pathsep .. package.path
   end

   local path, err = searchpath(name, search_path)
   if path == nil then
      return nil, err
   end

   local content, err = macro.substitute_tostring(slurp(path))
   if content == nil then
      return nil, "\tmacro expansion failed in '" .. path.. "': " .. err
   end

   local loadfn, err = load(content, name)
   if type(loadfn) ~= 'function' then
      return nil, "\tload '" .. path .. "' failed: " .. err
   end

   return loadfn
end


-- Metatable for Parser objects.
local parser_mt = {
   __index = {
      -- Return the type of the current event.
      type = function(self)
         return tostring(self.event.type)
      end,

      -- Raise a parse error.
      error = function(self, errmsg)
         io.stderr:write(format('%s:%d:%d: %s\n', self.filename,
                         self.mark.line, self.mark.column, errmsg))
         os.exit(1)
      end,

      -- Compile S into a callable function.
      compile = function(self, s)
         local f, errmsg = macro.substitute_tostring(s)
         if f == nil then
            -- Replace the error message from macro; it's just internal gunk.
            errmsg = format("%s:%d: parse error near 'expect', while collecting arguments",
                            self.filename, self.mark.line)
         else
            f, errmsg = load(f)
         end
         if f == nil then
            local line, msg = match(errmsg, '%[string "[^"]*"%]:([1-9][0-9]*): (.*)$')
            if msg ~= nil then
               line = tonumber(line) + self.mark.line - 1
               errmsg = format('%s:%d: %s', self.filename, line, msg)
            end
         end
         if errmsg ~= nil then
            io.stderr:write(errmsg .. '\n')
            os.exit(1)
         end
         return f
      end,

      -- Refetch the original lua format, for accurate error line numbers.
      refetch = function(self, value, event)
         -- Mark indices are character based, but Lua patterns are byte
         -- based, which means refetching doesn't work in the presence of
         -- unicode characters :(
         if self.unicode then
            return value
         end
         value = sub(self.input, event.start_mark.index, event.end_mark.index)
         if event.style == 'DOUBLE_QUOTED' then
            value = table.concat {match(value, [[^(%s*)"(.-)"%s*$]])}
         elseif event.style == 'SINGLE_QUOTED' then
            value = table.concat {match(value, [[^(%s*)'(.-)'%s*$]])}
         elseif event.style == 'LITERAL' then
            value = table.concat {match(value, [[^(%s*)[|](.-)%s*$]])}
         elseif event.style == 'FOLDED' then
            value = table.concat {match(value, [[^(%s*)>(.-)%s*$]])}
         end
         return value
      end,

      -- Save node in the anchor table for reference in future ALIASes.
      add_anchor = function(self, node)
         if self.event.anchor ~= nil then
            self.anchors[self.event.anchor] = node
         end
      end,

      -- Fetch the next event.
      parse = function(self)
         local ok, event = pcall(self.next)
         if not ok then
            -- if ok is nil, then event is a parser error from libYAML.
            self:error(gsub(event, ' at document: .*$', ''))
         end
         self.event = event
         self.mark = {
            line = self.event.start_mark.line + 1,
            column = self.event.start_mark.column + 1,
         }
         return self:type()
      end,

      -- Construct a Lua hash table from following events.
      load_map = function(self)
         local map = {}
         self:add_anchor(map)
         -- Inject the preamble into before node of the outermost map.
         if self.preamble then
            map.before = {
               example = self.preamble,
               line = 0,
            }
            self.preamble = nil
         end

         while true do
            local key = self:load_node()
            if key == nil then
               break
            end
            local value, event = self:load_node()
            if value == nil then
               return self:error('unexpected ' .. self:type() .. ' event')
            end
            if key == 'before' then
               -- Be careful not to overwrite injected preamble.
               value = self:refetch(value, event)
               map.before = {
                  example = table.concat {map.before and map.before.example or '', value},
                  line = self.mark.line,
               }
            elseif value == '' then
               map[key] = {
                  example = self:compile('pending()'),
                  line = self.mark.line,
               }
            elseif type(value) == 'string' then
               map[key] = {
                  example = self:compile(self:refetch(value, event)),
                  line = self.mark.line,
               }
            else
               map[key] = value
            end
         end
         -- Delayed compilation of before, having injecting preamble now.
         if map.before and type(map.before.example) == 'string' then
            map.before.example = self:compile(map.before.example)
         end
         return map
      end,

      -- Construct a Lua array table from following events.
      load_sequence = function(self)
         local sequence = {}
         self:add_anchor(sequence)
         while true do
            local node = self:load_node()
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
      load_scalar = function(self)
         local value = self.event.value
         local tag = self.event.tag
         if tag then
            tag = match(tag, '^' .. TAG_PREFIX .. '(.*)$')
            if tag == 'str' then
               -- value is already a string
            elseif tag == 'int' or tag == 'float' then
               value = tonumber(value)
            elseif tag == 'bool' then
               value = (value == 'true' or value == 'yes')
            end
         elseif self.event.style == 'PLAIN' then
            if value == '~' then
               value = null
            elseif value == 'true' or value == 'yes' then
               value = true
            elseif value == 'false' or value == 'no' then
               value = false
            else
               local number = tonumber(value)
               if number then
                  value = number
               end
            end
         end
         self:add_anchor(value)
         return value, self.event
      end,

      load_alias = function(self)
         local anchor = self.event.anchor
         if self.anchors[anchor] == nil then
            return self:error('invalid reference: ' .. tostring(anchor))
         end
         return self.anchors[anchor]
      end,

      load_node = function(self)
         local dispatch = {
            SCALAR = self.load_scalar,
            ALIAS = self.load_alias,
            MAPPING_START = self.load_map,
            SEQUENCE_START = self.load_sequence,
            MAPPING_END = nop,
            SEQUENCE_END = nop,
            DOCUMENT_END = nop,
         }

         local event = self:parse()
         if dispatch[event] == nil then
            return self:error('invalid event: ' .. self:type())
         end
       return dispatch[event](self)
      end,
   },
}


-- Parser object constructor.
local function Parser(filename, s, opts)
   local dir = dirname(filename)

   -- Add this spec-file directory to the macro-expanded spec_path list.
   spec_path = normalize(catfile(dir, path_mark .. '.lua'), spec_path)

   local object = {
      unicode = opts.unicode,
      anchors = {},
      input = s,
      mark = {line=0, column=0},
      next = yaml.parser(s),

      -- strip leading './'
      filename = gsub(filename, catfile('^%.', ''), ''),

      -- Used to simplify requiring from the spec file directory.
      preamble = format([[
         package.path = '%s'

         -- Expand macros in spec_helper.
         local loader = require 'specl.loader'
         local spec_path = '%s'

         -- Autoload spec_helper from spec-file directory, if any.
         table.insert(package.searchers, 1, loader.expandmacros)
         pcall(require, 'spec_helper')
      ]], package.path, spec_path)
   }
   return setmetatable(object, parser_mt)
end


local function load(filename, s, opts)
   local documents = {}
   local parser = Parser(filename, s, opts)

   if parser:parse() ~= 'STREAM_START' then
      return parser:error('expecting STREAM_START event, but got ' ..
                          parser:type())
   end

   while parser:parse() ~= 'STREAM_END' do
      local document = parser:load_node()
      if document == nil then
         return parser:error('unexpected ' .. parser:type() .. ' event')
      end

      if parser:parse() ~= 'DOCUMENT_END' then
         return parser:error('expecting DOCUMENT_END event, but got ' ..
                             parser:type())
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

-- Don't prevent examples from loading a different luaposix.
for _, reload in pairs {'yaml', 'lyaml'} do
   package.loaded[reload] = nil
end


local M = {
   expandmacros = expandmacros,
   load = load,
   null = null,
}

return M
