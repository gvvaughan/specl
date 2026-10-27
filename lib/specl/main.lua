--[[
 Behaviour Driven Development for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

local match = string.match

local std = require 'specl.std'
local util = require 'specl.util'
local version = require 'specl.version'

local object = std.object
local optparse = require 'optparse'
local filter = require 'std.functional.init'.filter
local clone, merge = std.table.clone, std.table.merge
local deepcopy, files, gettimeofday = 
   util.deepcopy, util.files, util.gettimeofday
local optspec = version.optspec


local Object = object {}


-- optparse opt handler for `-f, --formatter=FILE`.
local function formatter_opthandler(parser, opt, optarg)
   local ok, formatter = pcall(require, optarg)
   if not ok then
      ok, formatter = pcall(require, 'specl.formatter.' ..optarg)
   end
   if not ok then
      parser:opterr("could not load '" .. optarg .. "' formatter.\n" .. formatter)
   end
   return formatter
end


-- Whether *filename* is a specfile-like filename.
local function specfilter(filename)
   return match(filename, '_spec%.yaml$') ~= nil
end


-- Read and close the current input, which process_args() sets through
-- the global io table, so that inprocess.call can redirect it.
local function slurp()
   local h = io.input()
   local s, errmsg = h:read '*a'
   h:close()
   return s, errmsg
end


-- Called by process_args() to concatenate YAML formatted
-- specifications in each <arg>
local function compile(self, arg)
   local s, errmsg = slurp()
   if errmsg ~= nil then
      io.stderr:write(errmsg .. '\n')
      os.exit(1)
   end

   -- Add example opts to each spec file to simplify filtering later.
   if self.opts.example ~= nil then
      self.filters = merge(self.filters or {}, {inclusive = self.opts.example})
   end

   -- The loader needs lpeg and lyaml, which showing the help or version,
   -- or failing to parse the options, has no use for.
   local loader = require 'specl.loader'

   table.insert(self.specs, {
      filename = arg,
      examples = loader.load(arg, s, self.opts),
      filters = self.filters,
   })

   -- Line filters have been claimed.
   self.filters = nil
end


-- Process files and line filters specified on the command-line.
local function process_args(self, parser)
   if #self.arg == 0 then
      return parser:opterr "could not find spec files in './specs/'"
   end

   for i, v in ipairs(self.arg) do
      -- Process line filters.
      local filename, line = nil, match (v, '^%+(%d+)$')   -- +NN
      if line == nil then
         filename, line = match (v, '^(.*):(%d+):%d+')     -- file:NN:MM
      end
      if line == nil then
         filename, line = match (v, '^(.*):(%d+)$')        -- file:NN
      end

      -- Fallback to simple `filename`.
      if line == nil then
         filename = v
      end

      -- Accumulate unclaimed filters in the Main object.
      if line ~= nil then
         self.filters = self.filters or {}
         self.filters[tonumber(line)] = true
      end

      -- Process filename.
      if filename == '-' then
         io.input(io.stdin)
         self:compile(filename)

      elseif filename ~= nil then
         local h = io.open(filename)
         if h == nil and match(v, '^-') then
            return parser:opterr("unrecognised option '" .. v .. "'")
         end
         io.input(h)
         self:compile(filename)
      end
   end
end


-- Execute this program.
local function execute(self)
   -- Parse command line options.
   local parser = optparse(optspec)

   -- optparse writes with the io, os and print it found when it loaded,
   -- so go through the globals instead, which inprocess.call redirects.
   -- This opterr writes the same messages as optparse's own.
   function parser:opterr(msg)
      if not match(msg, '%.$') then
         msg = msg .. '.'
      end
      io.stderr:write(self.program .. ': error: ' .. msg .. '\n')
      io.stderr:write(self.program .. ": Try '" .. self.program .. " --help' for help.\n")
      os.exit(2)
   end
   parser:on('help', function(self)
      print(self.helptext)
      os.exit(0)
   end)
   parser:on('version', function(self)
      print(self.versiontext)
      os.exit(0)
   end)
   parser:on('bundled', function()
      print(table.concat(version.BUNDLED or {}, '\n'))
      os.exit(0)
   end)

   parser:on('color', parser.required, parser.boolean)
   parser:on({'f', 'format', 'formatter'},
              parser.required, formatter_opthandler)

   -- Unicode spec files need no option any more, but accept the old one.
   parser:on('unicode', parser.flag)

   self.arg, self.opts = parser:parse(self.arg, self.opts)
   self.stats.starttime = gettimeofday()

   -- When opt.example is non-nil, it must be a table.
   if self.opts.example and type(self.opts.example) ~= 'table' then
      self.opts.example = { self.opts.example }
   end

   -- Process all specfiles when none are given explicitly.
   if #self.arg == 0 then
      local specs, errmsg = files './specs'
      if specs == nil then
         parser:opterr(errmsg)
      else
         self.arg = filter(specs, specfilter)
      end
   end

   self:process_args(parser)

   if self.opts.coverage then
      pcall(require, 'luacov')
   end

   os.exit(require 'specl.runner'.run(self))
end


return Object {
   _type = 'Main',

   inprocess = _G,

   -- Methods.
   __index = {
      compile = compile,
      execute = execute,
      process_args = process_args,
   },

   -- Allow test harness to hijack io and os functions so that it can be
   -- safely executed in-process.
   _init = function(self, arg, env)
      self.arg = arg
      self.env = env or {}

      -- Option defaults.
      self.opts = {
         color = true,
         formatter = require 'specl.formatter.progress',
      }

      -- Collect compiled specs here.
      self.specs = {}

      -- Expectation statistics, timed from when the options are parsed, so
      -- that showing the help or version does not ask luaposix for the time.
      self.stats = {
         pass = 0, pend = 0, fail = 0
      }

      return self
   end,
}
