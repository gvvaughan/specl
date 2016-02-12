# Specl NEWS - User visible changes.

## Noteworthy changes in release 14.1.6 (2016-02-12) [stable]

### New features:

  - generate a working test coverage report with luacov when the
    --coverage option is given (assuming "luacov" is loadable).

  - runs specs in around half the time of previous releases.


## Noteworthy changes in release 14.1.5 (2016-02-09) [stable]

### New features:

  - new --coverage option tries to use "luacov" for coverage reports,
    but actually it doesn't work.


## Noteworthy changes in release 14.1.4 (2016-01-17) [stable]

### New features:

  - compatibility with recent split between lua-stdlib and
    optparse.

## Noteworthy changes in release 14.1.3 (2015-10-26) [stable]

### Bug fixes:

  - internal `deepcopy` no longer overflows the stack when copying
    tables that are their own metatable across nested Specl
    environments.


## Noteworthy changes in release 14.1.2 (2015-08-08) [stable]

### Bug fixes:

  - `equal` matcher really does compare mutable keys correctly,
    which works on LuaJIT and Lua 5.3 too.


## Noteworthy changes in release 14.1.1 (2015-08-02) [stable]

### Bug fixes:

  - `equal` matcher compares mutable table keys correctly, so things
    like this now work:

    ```lua
    expect ({[{k="mutable"}]=true}).to_equal ({[{k="mutable"}]=true})
    ```


## Noteworthy changes in release 14.1.0 (2015-01-03) [stable]

### New features

  - `badargs.diagnose` also accepts '?' in lieu of a proper function
    name in argument errors (as often returned by LuaJIT).

  - `badargs.format` will produce a `bad field` diagnostic when called
    as:

    ```lua
    badargs.format ("function_name", narg, nil, "field_name")
    ```

  - New matcher `raise_matching` compares an error against a Lua pattern.


## Noteworthy changes in release 14.0.0 (2014-12-31) [stable]

### New features

  - Preliminary Lua 5.3 support.

### Incompatible changes:

  - `badargs.format` now formats message with the word "arguments" for
    all ordinal values except exactly 1, where "argument" is used.
    Previously, Specl erroneously used "argument" for ordinal values of
    less than or equal to 1.

  - Ancient code to replace underscores in example description with
    spaces has finally removed.

### Bug fixes:

  - `specl.inprocess` now propagates function environments correctly,
    so examples inside the `inprocess.call` are not tallied to the
    main specl counters; `formatter.report` does not lose track of what
    descriptions have been displayed after an `inprocess.call`; etc.

  - When expecting automatic execution of specfiles in ./specs/*,
    without luaposix installed, error is diagnosed properly.


## Noteworthy changes in release 13 (2014-10-04) [stable]

### New features:

  - Specl's own modules, and modules loaded from spec-file directories
    are now loaded inside the function environment of the running
    example, and so have access to Specl's Lua extensions, such as
    `expect` and matchers.

  - `inprocess.capture` returns a `Process` object, suitable for
    matching using the `specl.shell` matchers.

  - New `to_raise` matcher as an alias for `to_error` to avoid flagging
    capitalised error messages in error matcher argument with Slingshot
    sanity checks.

  - New programmatic `examples` function for building example groups and
    helper functions directly in Lua, whenever YAML starts to get in the
    way.  See documentation for examples.

  - New `specl.badargs` module provides `format` to generate standard
    argument error messages that can be passed to matchers to ensure
    correct error message formatting:

    ```lua
    expect (posix.write ()).to_raise (format ("write", 1, "int"))
    ```

    And `diagnose`, which writes a full set of expectations to check all
    missing, extraneous and badly typed arguments are diagnosed
    correctly:

    ```yaml
    - context with bad arguments:
        badargs.diagnose (posix.write "(int, string)")
    ```

### Incompatible changes:

  - `inprocess.capture` returns a `Process`, not a pair of strings
    and the call results. Call results are still available in the array
    part of the returned `Process`.

  - Specl now requires latest stdlib v40 to be installed on the module
    path, rather than carrying its own copies of parts of stdlib it wants
    to use.

  - Specl now installs as a selection of library files (in the module
    subdirectory `specl`), and a thin wrapper script that sets up the
    execution environment and then calls `specl.main (arg):execute ()`.
    This simplifies debugging, and remove all the infrastructure for
    expanding `from` macros, and concatenating the resulting sources, as
    well as allowing piece-meal loading of specl modules.

### Bug fixes:

  - Enhanced resolution timers now also work with luaposix > 31.

  - The report formatter would not display subsequent repeats of a
    context description after the first under some circumstances.  It
    now displays context descriptions correctly in that case too.

  - Don't prevent examples from loading a different luaposix than the
    installed default loaded by Specl.  This allows the luaposix specs
    to work in the build tree without priming LUA_CPATH and LUA_PATH
    before calling specl, for example.

  - `inprocess.capture` now supports capturing results of a functable
    call.

  - `specl.shell` matchers now correctly succeed when using `not_`
    prefixes to specify that a `Process` should not contain some error
    or standard output text, and that `Process` stream contains `nil`
    to indicate the stream was not written at all. For example:

    ```lua
    expect (capture (function () print "stdout" end)).
      not_to_contain_error "stderr"
    ```

  - After loading system modules it depends on, Specl removes them
    from the Lua module cache so that other versions of those same
    modules (yaml, posix, posix.sys) can use Specl to check their own
    behaviours by loading the to-be-checked versions from
    `spec_helper.lua`.


## Noteworthy changes in release 12 (2014-04-25) [stable]

### New features:

  - Now that this API is stable, there is full documentation for
    `specl.shell` in doc/specl.md.

  - New `specl.inprocess.capture` function for running examples that
    interact with io streams.  `inprocess.capture` wraps a function call
    so that standard input calls read from the supplied buffer, and any
    output is captured rather than leaked:

    ```lua
    inprocess.capture (function (...)
      print (...)
      io.stderr:write (io.stdin:read "*a")
      return "first", 2
    end,
    {"foo", "bar"},
    "input content")

    --> "foo\tbar\n", "input content", "first", 2
    ```

    i.e. standard output, standard error, function return values

  - The report formatter no longer displays orphaned contexts of
    filtered-out examples.

### Bug fixes:

  - Specl no longer crashes when requiring system libraries (such as
    math, bit32 etc) from examples or spec_helpers.

  - The `--fail-fast` option no longer stops when encountering a failing
    expectation in a pending example.

  - Ignore any LUA_INIT or LUA_INIT_5_2 settings in the execution
    environment, since they can easily corrupt the behaviour of example
    code.  If you need to write examples that deliberately interact with
    those envvars, use `specl.shell` to isolate them correctly.

## Noteworthy changes in release 11 (2014-04-05) [stable]

### New features:

  - Built-in matchers compare nested tables and objects in about 25% of
    the time required previously, and is optimised for tail-call
    elimination for non-tree like structures.

  - Specl now loads a `spec_helper.lua` from the same directory as the
    spec file being executed into the example environment automatically,
    so there's no need to manually require it from a `before:` block in
    each spec file any more.

  - You can easily run Specl from the top of your source tree without
    any special LUA_PATH munging in Makefiles or wrapper scripts. Just
    set `package.path` and `package.cpath` to find the code being specced
    out in a `spec_helper.lua` in each directory containing spec files.

  - When invoked with no filename arguments, `specl` will check all your
    specifications, as long as they have names ending in `_spec.yaml` and
    are kept in or somewhere below the `specs/` directory of your project.

  - The report and progress formatters now display file:line:expectation:
    annotations for failed and pending expectations in verbose mode (-v).

  - New command line option `--fail-fast` (or `-1`) to stop checking
    expectations immediately on the first failure, rather than
    continuing and showing all failures.

  - New command line option `--example=PATTERN` (or `-e PATTERN`) to specify
    inclusive filters matched against the fully concatenated YAML
    descriptions of an example. Use this to select a subset of examples to
    (re)check.

  - You can also filter out all but the examples at a specified line
    number either by pasting from the output of a failed or pending
    expectation in verbose mode, by invoking specl as:

    ```bash
    specl specs/some_spec.yaml:44:1
    ```

    or with as many `+NN` as necessary to select several examples from
    the following file:

    ```bash
    specl +44 +48 specs/some_spec.yaml
    ```

    or a combination of the above. Note that the final `:1` in the
    former is ignored and can be omitted (it is the ordinal number of an
    `expect` statement in a given example), but is accepted for ease of
    cutting and pasting.

  - From this release out, matchers using `to_` are preferred to using
    `should_`.  When negating a new syntax `to_` matcher, both of
    `to_not_` and `not_to` are accepted.

  - New `copy` matcher, to specify that an object should be an identical
    copy of the expected value, but not the same object:

    ```lua
    t = {"foo"}
    expect (table.clone (t)).to_copy (t)
    ```

  - You can `require "specl.shell"` for a swathe of additional matchers
    to specify results from a `Process` object:

      a) For exit statuses, use:

         ```lua
         expect (shell.spawn "exit 42").to_exit (42)
         expect (shell.spawn "exit 0").to_succeed ()
         expect (shell.spawn "/bin/false").to_fail ()
         ```

      b) For checking the contents of the output stream, use:

         ```lua
         expect (...).to_output "exact content"
         expect (...).to_contain_output  "substring"
         expect (...).to_match_output "pattern"
         ```

      d) To require zero exit status with specified output stream
         contents:

         ```lua
         expect (...).to_succeed_with "exact content"
         expect (...).to_succeed_while_containing "substring"
         expect (...).to_succeed_while_matching "pattern"
         ```

      c) To check the standard error stream instead:

         ```lua
         expect (...).to_output_error "exact content"
         expect (...).to_contain_error "substring"
         expect (...).to_match_error "pattern"
         ```

      e) To require non-zero exit status with specified error stream
         contents:

         ```lua
         expect (...).to_fail_with "exact content"
         expect (...).to_fail_while_containing "substring"
         expect (...).to_fail_while_matching "pattern"
         ```

  - New experimental `specl.inprocess` module provides a way to run
    carefully written Lua programs inside the Specl process, saving a
    fork/exec each time.  Converting Specl itself to be reentrant, and
    using `specl.inprocess` for most of its examples shaves more than
    75% off the time spent in `make check`: from over 20secs to under
    5secs on my machine.

### Incompatible changes:

  - Invoking `specl` with no filename arguments no longer reads specs
    from standard input.  You must explicitly pass a "-" argument to get
    that behaviour.

  - RSpec has been moving from expressing `should_` expectations to
    using `to_` for technical reasons.  Specl now uses `to_` throughout,
    not for technical reasons, but because:

      (i) expectations almost always read better with `to_` instead of
          `should_`;
     (ii) it's shorter and easier to type, so is less "noisy" in among
          the important surrounding arguments.

    There are no plans to remove `should_` from Specl, so you can expect
    to safely continue to use your existing spec files indefinitely: But
    all mention of `should_` has been removed from documentation, and I
    recommend you use `to_` for new spec files for the reasons above.

  - When making custom matchers, all the api constructor functions are
    now proper methods.  Previous releases forgot the initial self
    parameter in the unnamed matching predicate function and the
    following optional functions accepted by the constructor:

    ```lua
    function (self, actual, expect)
    function format_actual (self, actual, ...)
    format_expect (self, expect, ...)
    format_alternatives (self, adaptor, alternatives, ...)
    ```

    If you have added any custom matchers to your spec files, be sure
    to insert the `self` parameter to match the new calling convention
    as soon as you upgrade, or they will not work with this release.

### Bug fixes:

  - Setting table elements from outer environment tables no longer leak
    into sibling examples.  For example, changing entries in the _G
    table or adding entries to the string table affects only the current
    innermost environment now, just like setting other variables.

  - Unrecognised command-line options are diagnosed properly.


## Noteworthy changes in release 10 (2014-01-15) [stable]

### Bug fixes:

  - Using specl.shell when Specl itself and the process being
    spawned require different versions of Lua no longer crashes
    with corrupted shared package.path settings.


## Noteworthy changes in release 9 (2013-12-09) [stable]

### New features:

  - Vastly improved error diagnostics for syntax errors in spec
    files, reporting filename and line-number of error locations,
    and without spurious Lua-runtime stack traces.

  - Support for custom per-matcher adaptors. See docs/specl.md for
    documentation.

  - New `a_permutation_of` adaptor for contain matcher, that allows
    expectations for operations that are inherently unordered:

    ```lua
    t = {}
    for _, v in pairs (a_big_table) do t[#t + 1] = v end
    expect (a_big_table).should_contain.a_permutation_of (t)
    ```

    It will fail unless the same set of elements are present in the
    expect argument values, or the expect argument keys; like the
    other `contain` adaptors it works with strings and objects too.

  - New `--unicode` command-line option to support unicode in spec
    files, at the expense of inaccurate line-numbers in error
    messages.

  - Works correctly without ansicolors installed (albeit without
    displaying any color!).

  - If `luaposix` is installed where Specl can find it, the report
    and progress formatters will use it to display the time spent
    running specifications much more accurately.

### Incompatible changes:

  - Requires lyaml 4 or newer.

  - Unicode characters in spec files are no longer supported by
    default. LibYAML counts indices by character when reporting the
    offsets used to re-extract the Lua code fragments (i.e. without
    YAML neline folding) that Specl uses to generate correct line-
    numbers in error-messages.  Lua string operations require byte
    offsets, which are incompatible.

  - When using std.objects, the contain matcher now displays the
    expected object type name (rather than just: "table") from the
    FAIL report.

### Bug fixes:

  - Help2man is no longer required to install specl from the
    distribution tarball.


## Noteworthy changes in release 8 (2013-06-26) [stable]

### New features:

  - Can now be installed directly from a release tarball by `luarocks`.
    No need to run `./configure` or `make`, unless you want to install
    to a custom location, or do not use LuaRocks.

  - A new `all_of` adaptor for any matcher:

    ```lua
    expect (mytable).should_contain.all_of {x, y, z}
    ```

  - `contain` matcher handles std.object module derived objects by
    coercing them to tables.

  - `equal` matcher performs a deep comparison of std.object module
    derived objects' contents.

  - `./bootstrap` runs slowly again with 4800 lines of code
    reintroduced required to automatically manage Slingshot files with
    new `bootstrap.slingshot`.  This doesn't have any direct effect on
    users, except that the Slingshot managed release process is much
    more robust, reducing the chances you'll end up with a still-born
    release.

### Bug fixes:

  - Avoid `nan%` divide-by-zero error output from report formatter.

  - Built in report formatter displays argument strings to pending
    calls from examples consistently.

### Incompatible changes:

  - API change in matchers, generalizing the former `format_any_of` to
    `format_alternatives`, with a new `adaptor` parameter for use with
    additional matcher adaptors.

  - API change in both matchers.concat and matchers.reformat, each of
    which now take an additional `adaptor` argument, which can be
    passed in from `format_alternatives` as received so that the
    grammatically best choice of `and` or `or` is used to display the
    list of alternatives when an expectation fails.

  - Calling `require` in a spec file no longer artificially extracts
    symbols from a returned table and injects them into the local
    environment -- because it was inelegant and unnecessary.  If you
    had relied on this feature, simply capture the returned table and
    either manually copy the symbols you need or use a fully qualified
    name.  Previously:

    ```yaml
    # Don't do this!
    before:
      require "specl.shell"
    describe spawn:
      expect (spawn "printf hello").should_output "hello"
    ```

    Much better:

    ```yaml
    # Do this instead.
    before:
      spawn = (require "specl.shell").spawn
    describe spawn:
      expect (spawn "printf hello").should_output "hello"
    ```


## Noteworthy changes in release 7 (2013-05-13) [stable]

### Bug fixes:

  - Add missing documentation for `matchers.Matcher.format_any_of`.

  - It's no longer possible to crash Specl using example descriptions
    that look like other types during lyaml parsing.

  - Specl 6 had a broken `should_contain` matcher, that would
    fail to match any expected substring with an active Lua
    pattern character in it (such as ?, * or % for example).

  - Add missing close parenthesis in non-verbose mode report
    formatter summaries with failing or pending expectations.

### Incompatible changes:

  - While not encouraged, one word descriptions are now supported,
    and are displayed correctly by the bundled formatters.


## Noteworthy changes in release 6 (2013-05-09) [stable]

  - This release is a significant upgrade, with many new features,
    and, no doubt, some new bugs.

### New features:

  - Top level `before` and `after` functions are supported.

  - A proper, documented, API for adding custom matchers.

  - A new `any_of` method for any matcher:

    ```lua
    expect (ctermid ()).should_match.any_of {"/.*tty.*", "/.*pts.*"}
    ```

  - You can `require "specl.shell"` from a spec file (usually in the
    initial top-level `before`) to get access to a shell Command
    constructor, a `spawn` executor function and several new matchers
    for querying the status of a shell command.

  - `package.path` is augmented, for the duration of each spec file,
    so that `require` can find and load other Lua files in the same
    directory.

  - Additional YAML "documents" from a spec file with `---` and `...`
    stream separators are no longer ignored; but treated as additional
    unnamed documents.

  - Report formatter displays inline expectation summaries for each
    example when not in verbose mode.

### Incompatible changes:

  - Documentation is now in Jekyll format markdown for easy website
    regeneration.

  - Calling require in a spec file now runs in the local environment,
    giving access to `global` symbols from the newly loaded file from
    the local namespace.  Conversely, access to those same symbols is
    no longer available from "_G", the global environment table.


## Noteworthy changes in release 5 (2013-04-29) [stable]

### This release is a significant upgrade.

### New features:

  - Documentation reorganisation.  README.md is much simplified, with
    full documentation still in markdown at docs/specl.md.  The html
    documentation at http://gvvaughan.github.io/specl will be updated
    with every release from now on.

### Bug fixes:

  - `./bootstrap` runs quickly with 4800 lines of code removed.

  - `./configure` runs quickly with the remaining C macros removed.

  - `progress` and `report` formatters now report elapsed time rather
    than cpu time in their footer output.

  - The `specl` LUA_PATH no longer picks up its own `specl.std` module
    by mistake when a spec file requires the lua-stdlib `std` module.

### Incompatible changes:

  - The `should_error` matcher now takes arguments in the same order
    as the other matchers. LuaMacro injects a `pcall` into every
    `expect` invocation, so the specifications are written
    intuitively:

    ```lua
    expect (error "failed").should_error "failed"
    ```

  - The Specl-1 Lua format for spec files is no longer supported, in
    part to clean up a lot of otherwise unused code, but also because
    Lua specs were accumulating too much magic to be easy to write by
    hand.

  - `build-aux` speclc and the bundled generated `specs/*_spec.lua`
    specs have been removed.


## Noteworthy changes in release 4 (2013-04-07) [beta]

  - This release is a minor update.

### New features:

  - Now tested against Lua 5.1, Lua 5.2 and luajit-2.0 on every commit,
    thanks to travis-ci.org.

  - Pending specifications are now fully implemented and documented.

  - Unexpected passing of pending specifications is reported by progress
    and report formatters.

  - API for custom formatters is richer and clearer.

### Bug fixes:

  - Specs propagate user LUA_PATH settings to specl forks in Specls own
    own specifications.


## Noteworthy changes in release 3 (2013-03-20) [beta]

  - This release is a significant upgrade.

### New features:

  - lyaml was spun out to a separate luarock, now required.

  - Initial support for pending examples, either using the new
    `pending ()` function, or having an example description with an
    empty definition.

  - pending and failed expectations are now summarized in the footer of
    default (progress) and report formatters.

  - Formatters display in color on supported TERM types, ansicolors is
    now required.

  - Color can be disabled with `--color=no` command line option.

  - Custom formatters are now supported, using the new command line
    option `--formatter=tap`.

  - The custom formatters API is documented in README.md.

  - A new TAP formatter was contributed by François Perrad.

  - Many more specifications for Specl were added, now that specl is
    featureful enough to support BDD development of itself.

### Bug fixes:

  - Error message from invalid Lua in example definitions are now
    reported correctly.

  - Runner environments are more robust, see README.md for details.

  - Specl no longer uses lua-stdlib (to break a cyclic dependency
    when using specl to run lua-stdlib spec-files).

### Incompatible changes:

  - `-v` now behaves differently, and simply requests more verbose
    output from the selected formatter, use `-freport` to select the
    report formatter like `-v` did in release 2 and earlier.


## Noteworthy changes in release 2 (2013-03-07) [beta]

  - Now compatible with Lua 5.2 *and* Lua 5.1.

  - Primary format for spec files is now YAML (specl-1 format spec files
    are still supported).

  - Requires libyaml-0.1.4 to be installed before building.

  - Includes some YAML specifications for Specl.


## Noteworthy changes in release 1 (2013-02-26) [alpha]

  - Initial proof-of concept for an RSpec inspired framework for and in
    Lua.

  - The spec file syntax is a bit horrid in pure Lua, but the next
    release uses YAML and is much nicer!
