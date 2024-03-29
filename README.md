SPECL
=====

[![License](http://img.shields.io/:license-mit-blue.svg)](https://mit-license.org)
[![workflow status](https://github.com/gvvaughan/specl/actions/workflows/spec.yml/badge.svg?branch=master)](https://github.com/gvvaughan/specl/actions)
[![codecov.io](https://codecov.io/github/gvvaughan/specl/coverage.svg?branch=master)](https://codecov.io/github/gvvaughan/specl?branch=master)

[Specl][] is a testing tool for [Lua][] 5.1 (including [LuaJit][]), 5.2,
5.3 and 5.4, providing a [Behaviour Driven Development][BDD] framework in
the vein of [RSpec][].

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


Bug reports and code contributions
----------------------------------

Please make bug reports and suggestions [GitHub Issues][issues].
Pull requests are especially appreciated.

But first, please check that your issue has not already been reported by
someone else, and that it is not already fixed by [master][github] in
preparation for the next release (see Installation section above for how
to temporarily install master with [LuaRocks][]).

There is no strict coding style, but please bear in mind the following
points when proposing changes:

0. Follow existing code. There are a lot of useful patterns and avoided
   traps there.

1. 3-character indentation using SPACES in Lua sources: It makes rogue
   TABs easier to see, and lines up nicely with 'fi' and 'end' keywords.

2. Simple strings are easiest to type using single-quote delimiters,
   saving double-quotes for where a string contains apostrophes.

3. Save horizontal space by only using SPACEs where the parser requires
   them.

4. Use vertical space to separate out compound statements to help the
   coverage reports discover untested lines.

5. Prefer explicit string function calls over object methods, to mitigate
   issues with monkey-patching in caller environments.

[bdd]:       https://en.wikipedia.org/wiki/Behavior-driven_development
[github]:    https://github.com/gvvaughan/specl
[github.io]: https://gvvaughan.github.io/specl
[install]:   https://raw.github.com/gvvaughan/specl/release/INSTALL
[issues]:    https://github.com/gvvaughan/specl/issues
[lua]:       https://www.lua.org
[luajit]:    https://luajit.org
[luarocks]:  https://www.luarocks.org
[rspec]:     https://github.com/rspec/rspec
[specl]:     https://github.com/gvvaughan/specl
[depends]:   https://github.com/gvvaughan/specl/blob/master/specl-git-1.rockspec#L28
