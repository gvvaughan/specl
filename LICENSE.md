The MIT License (MIT)

Copyright (c) 2013-2026 Gary V. Vaughan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Bundled software

The `specl` that a release installs is one file, with the Lua libraries
that it needs inside, and its builder squeezes the comments, and so the
notices, out of them.  They are made available under the same terms as
above, except where this says otherwise:

  * ansicolors, by

        Copyright (c) 2009 Rob Hoelz <rob@hoelzro.net>
        Copyright (c) 2011 Enrique García Cota <enrique.garcia.cota@gmail.com>

  * LuaMacro (`macro`, `macro.Getter` and `macro.TokenList`), under the
    MIT/X11 license, by

        Copyright (C) 2007-2011 Steve Donovan

    with `macro.lexer`, written by Peter Odding in 2007 and released under
    the blessing of the SQLite project, "The author disclaims copyright to
    this source code.  In place of a legal notice, here is a blessing:  May
    you do good and not evil.  May you find forgiveness for yourself and
    forgive others.  May you share freely, never taking more than you
    give.", and `macro.clexer`, based on the C lexer in Peter Odding's
    lua-lxsh.
