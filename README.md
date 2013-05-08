SPECL
=====

[![travis-ci status](https://secure.travis-ci.org/gvvaughan/specl.png?branch=master)](http://travis-ci.org/gvvaughan/specl/builds)

[Specl][] is a testing tool for [Lua][], providing a
[Behaviour Driven Development][BDD] framework in the vein of [RSpec][].

 * a rich command line program (the `specl` command)
 * textual descriptions of examples and groups (spec files use [YAML][])
 * flexible and customizable reporting (formatters)
 * extensible expectation language (matchers)

Installation
------------

By far the easiest way to install Specl is with [LuaRocks][]:

    luarocks install specl

To install current git master (for testing):

    luarocks install http://raw.github.com/gvvaughan/specl/release/specl-git-1.rockspec

To install without [LuaRocks][], check out the sources from the
[repository][specl], and then run the following commands:

    cd specl
    ./bootstrap
    ./configure --prefix=INSTALLATION-ROOT-DIRECTORY
    make all check install

The dependencies are listed in the dependencies entry of the file
[specl-rockspec.lua][L23]. You will also need autoconf and automake.

See [INSTALL][] for instructions for `configure`.

Documentation
-------------

Specl includes [Markdown formatted documentation][github.io].


[bdd]:       http://en.wikipedia.org/wiki/Behavior-driven_development
[github.io]: http://gvvaughan.github.io/specl
[install]:   http://raw.github.com/gvvaughan/specl/master/INSTALL
[lua]:       http://www.lua.org
[luarocks]:  http://www.luarocks.org
[rspec]:     http://github.com/rspec/rspec
[specl]:     http://github.com/gvvaughan/specl
[L23]:       http://github.com/gvvaughan/specl/blob/master/specl-rockspec.lua#L23
[yaml]:      http//yaml.org
