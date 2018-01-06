SPECL
=====

[![License](http://img.shields.io/:license-mit-blue.svg)](https://mit-license.org)
[![travis-ci status](https://secure.travis-ci.org/gvvaughan/specl.png?branch=master)](https://travis-ci.org/gvvaughan/specl/builds)
[![codecov.io](https://codecov.io/github/gvvaughan/specl/coverage.svg?branch=master)](https://codecov.io/github/gvvaughan/specl?branch=master)
[![Stories in Ready](https://badge.waffle.io/gvvaughan/specl.png?label=ready&title=Ready)](https://waffle.io/gvvaughan/specl)

[Specl][] is a testing tool for [Lua][] 5.1 (including [LuaJit][]), 5.2
and 5.3, providing a [Behaviour Driven Development][BDD] framework in the
vein of [RSpec][].

 * a rich command line program (the `specl` command)
 * textual descriptions of examples and groups (spec files use [YAML][])
 * flexible and customizable reporting (formatters)
 * extensible expectation language (matchers)

Installation
------------

There's no need to download a [Specl][] release, or clone the git repo,
unless you want to modify the code.  If you use [LuaRocks][], you can
use it to install the latest release from its repository:

    luarocks install specl

Or from the rockspec inside the release tarball:

    luarocks make specl-?-1.rockspec

To install current git master from [GitHub][specl] (for testing):

    luarocks install \
      https://raw.githubusercontent.com/gvvaughan/specl/master/specl-git-1.rockspec

The dependencies are listed in the dependencies entry of the 
[rockspec][depends].


Documentation
-------------

Specl includes [comprehensive documentation][github.io].


[bdd]:       https://en.wikipedia.org/wiki/Behavior-driven_development
[github.io]: https://gvvaughan.github.io/specl
[install]:   https://raw.github.com/gvvaughan/specl/release/INSTALL
[lua]:       https://www.lua.org
[luajit]:    https://luajit.org
[luarocks]:  https://www.luarocks.org
[rspec]:     https://github.com/rspec/rspec
[specl]:     https://github.com/gvvaughan/specl
[depends]:   https://github.com/gvvaughan/specl/blob/master/specl-git-1.rockspec#L28
