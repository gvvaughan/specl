-- Specification testing sandbox.
-- Written by Gary V. Vaughan, 2016
--
-- Copyright (c) 2016 Gary V. Vaughan
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

local std     = require "specl.std"

local clone = std.table.clone


-- Make a shallow copy of the pristine global environment, so that the
-- future state of the Specl environment is not exposed to spec files.
local sandbox = {
  _VERSION	= _VERSION,
  arg		= clone (arg),
  assert	= assert,
  collectgarbage = collectgarbage,
  coroutine = {
    create	= coroutine.create,
    resume	= coroutine.resume,
    running	= coroutine.running,
    status	= coroutine.status,
    wrap	= coroutine.wrap,
    yield	= coroutine.yield,
  },
  debug = {
    debug	 = debug.debug,
    gethook	 = debug.gethook,
    getinfo	 = debug.getinfo,
    getlocal	 = debug.getlocal,
    getmetatable = debug.getmetatable,
    getregistry	 = debug.getregistry,
    getupvalue	 = debug.getupvalue,
    getuservalue = debug.getuservalue,
    sethook	 = debug.sethook,
    setmetatable = debug.setmetatable,
    setupvalue	 = debug.setupvalue,
    setuservalue = debug.setuservalue,
    traceback	 = debug.traceback,
    upvalueid	 = debug.upvalueid,
    upvaluejoin	 = debug.upvaluejoin,
  },
  dofile	= dofile,
  error		= error,
  getmetatable	= getmetatable,
  io = {
    close	= io.close,
    flush	= io.flush,
    input	= io.input,
    lines	= io.lines,
    open	= io.open,
    output	= io.output,
    popen	= io.popen,
    read	= io.read,
    stderr	= io.stderr,
    stdin	= io.stdin,
    stdout	= io.stdout,
    tmpfile	= io.tmpfile,
    type	= io.type,
    write	= io.write,
  },
  ipairs	= ipairs,
  load		= load,
  loadfile	= loadfile,
  loadstring	= loadstring,
  math = {
    abs		= math.abs,
    acos	= math.acos,
    asin	= math.asin,
    atan	= math.atan,
    ceil	= math.ceil,
    cos		= math.cos,
    deg		= math.deg,
    exp		= math.exp,
    floor	= math.floor,
    fmod	= math.fmod,
    huge	= math.huge,
    log		= math.log,
    max		= math.max,
    min		= math.min,
    modf	= math.modf,
    pi		= math.pi,
    rad		= math.rad,
    random	= math.random,
    randomseed	= math.randomseed,
    sin		= math.sin,
    sqrt	= math.sqrt,
    tan		= math.tan,
  },
  module	= module,
  next		= next,
  os = {
    clock	= os.clock,
    date	= os.date,
    difftime	= os.difftime,
    execute	= os.execute,
    exit	= os.exit,
    getenv	= os.getenv,
    remove	= os.remove,
    rename	= os.rename,
    setlocale	= os.setlocale,
    time	= os.time,
    tmpname	= os.tmpname,
  },
  pack		= pack or table.pack,
  package = {
    config	= package.config,
    cpath	= package.cpath,
    loaders	= package.loaders or package.searchers,
    loadlib	= package.loadlib,
    path	= package.path,
    preload	= package.preload,
    searchers	= package.loaders or package.searchers,
    searchpath	= package.searchpath,
    seeall	= package.seeall,
  },
  pairs		= pairs,
  pcall		= pcall,
  print		= print,
  rawequal	= rawequal,
  rawget	= rawget,
  rawlen	= rawlen,
  rawset	= rawset,
  require	= require,
  select	= select,
  setmetatable	= setmetatable,
  string = {
    byte	= string.byte,
    char	= string.char,
    dump	= string.dump,
    find	= string.find,
    format	= string.format,
    gmatch	= string.gmatch,
    gsub	= string.gsub,
    len		= string.len,
    lower	= string.lower,
    match	= string.match,
    rep		= string.rep,
    reverse	= string.reverse,
    sub		= string.sub,
    upper	= string.upper,
  },
  table = {
    concat	= table.concat,
    insert	= table.insert,
    pack	= table.pack or pack,
    remove	= table.remove,
    sort	= table.sort,
    unpack	= table.unpack or unpack,
  },
  tonumber	= tonumber,
  tostring	= tostring,
  type		= type,
  unpack	= unpack or table.unpack,
  xpcall	= xpcall,
}
sandbox._G	= sandbox
sandbox.package.loaded = {
  _G		= sandbox,
  coroutine	= sandbox.coroutine,
  debug		= sandbox.debug,
  io		= sandbox.io,
  math		= sandbox.math,
  os		= sandbox.os,
  package	= sandbox.package,
  string	= sandbox.string,
  table		= sandbox.table,
}


return sandbox
