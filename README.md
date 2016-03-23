SPECL
=====

[![License](http://img.shields.io/:license-mit-blue.svg)](https://mit-license.org)
[![travis-ci status](https://secure.travis-ci.org/gvvaughan/specl.png?branch=master)](https://travis-ci.org/gvvaughan/specl/builds)
[![codecov.io](https://codecov.io/github/gvvaughan/specl/coverage.svg?branch=master)](https://codecov.io/github/gvvaughan/specl?branch=master)
[![Stories in Ready](https://badge.waffle.io/gvvaughan/specl.png?label=ready&title=Ready)](https://waffle.io/gvvaughan/specl)

[Specl][] is a testing tool for [Lua][], providing a
[Behaviour Driven Development][BDD] framework in the vein of [RSpec][].

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

To install without [LuaRocks][], clone the sources from the
[repository][specl], and then run the following commands:

    cd specl
    ./bootstrap
    ./configure --prefix=INSTALLATION-ROOT-DIRECTORY
    make all check install

The dependencies are listed in the dependencies entry of the file
[rockspec.conf][L10]. You will also need [Autoconf][] and [Automake][].

See [INSTALL][] for instructions for `configure`.

Documentation
-------------

Specl includes [comprehensive documentation][github.io].


[autoconf]:  https://gnu.org/s/autoconf
[automake]:  https://gnu.org/s/automake
[bdd]:       https://en.wikipedia.org/wiki/Behavior-driven_development
[github.io]: https://gvvaughan.github.io/specl
[install]:   https://raw.github.com/gvvaughan/specl/release/INSTALL
[lua]:       https://www.lua.org
[luarocks]:  https://www.luarocks.org
[rspec]:     https://github.com/rspec/rspec
[specl]:     https://github.com/gvvaughan/specl
[L10]:       https://github.com/gvvaughan/specl/blob/master/rockspec.conf#L10
[yaml]:      https//yaml.org
