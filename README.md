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

There's no need to download a [Specl][] release, or clone the git repo,
unless you want to modify the code.  If you use [LuaRocks][], you can
use it to install the latest release from it's repository:

    luarocks install specl

Or from the rockspec in a release tarball:

    luarocks make specl-?-1.rockspec

To install current git master from [GitHub][specl] (for testing):

    luarocks install \
      https://raw.githubusercontent.com/gvvaughan/specl/release/specl-git-1.rockspec

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

Specl includes [Markdown formatted documentation][github.io].


[autoconf]:  http://gnu.org/s/autoconf
[automake]:  http://gnu.org/s/automake
[bdd]:       http://en.wikipedia.org/wiki/Behavior-driven_development
[github.io]: http://gvvaughan.github.io/specl
[install]:   http://raw.github.com/gvvaughan/specl/release/INSTALL
[lua]:       http://www.lua.org
[luarocks]:  http://www.luarocks.org
[rspec]:     http://github.com/rspec/rspec
[specl]:     http://github.com/gvvaughan/specl
[L10]:       http://github.com/gvvaughan/specl/blob/master/rockspec.conf#L10
[yaml]:      http//yaml.org
