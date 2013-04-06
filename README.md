SPECL
=====

[![travis-ci status](https://secure.travis-ci.org/gvvaughan/specl.png)](http://travis-ci.org/gvvaughan/specl/builds)

Behaviour Driven Development for [Lua][].

1. Installation
---------------

By far the easiest way to install Specl is with luarocks:

    luarocks install specl

If you need access to features not in a luarocks release yet:

    git clone git@github.com:gvvaughan/specl.git
    cd specl
    make
    make rockspecs
    luarocks make specl-git-1.rockspec

You can also install Specl without luarocks, but you must first check
that you have all the dependencies installed, because `configure`
assumes they are already available.  The latest dependencies are listed
in the `dependencies` entry of the file `specl-rockspec.lua`.

    git clone git@github.com:gvvaughan/specl.git
    cd specl
    ./bootstrap
    ./configure --prefix=INSTALLATION-ROOT-DIRECTORY
    make all check install

Note that the configured installation method installs directly to the
specified `--prefix` tree, even if you have luarocks installed too.


2. Specifications
-----------------

The `specl` command verifies that the behaviour of your software meets
the specifications encoded in one or more _spec-files_. A spec-file is
a [YAML][] structured file, laid out as groups of nested plain-English
descriptions of specifications, with associated snippets of [Lua][]
code that verify whether the software behaves as described.

A tiny spec-file outline follows:

    describe specification file format:
    - it is just a list of examples with descriptions:
        with_Lua_code ("to verify described behaviours")
    - it is followed by additional specifications:
        print "Lua example code demonstrates this specification"
        print "on several (indented) lines, if necessary."

The first significant line of any specification is the plain-English
description of the first example group, ending with a `:` (colon).

Underneath that are two examples, each starting with `- ` (minus, space)
and separated by a `:` (colon) into a _description_ of some desired
behaviour, and the associated [Lua][] code to demonstrate it.

The descriptions above follow the [RSpec][] convention of using
_describe_ as the first word of a group description, and _it_ as the
first word of an example description.  [Specl][] doesn't enforce them,
they are conventions after all, but `specl` output tends to look much
better if you follow them.  There are more conventions regarding the
choice of first word in a description under various other circumstances,
which we'll cover shortly.

A fuller spec-file will contain several example groups, similar to the
one above, each typically followed by dozens of individual examples.
To easily keep track of what specifications go with what parts of your
implementation, it's good practice to put all your specs in a
subdirectory, with one spec named after each file being specified. For
example, your application might have a `src/stack.lua` class, along
with a `specs/stack_spec.yaml` file that contains all the matching
specifications.

All of those specifications eventually boil down to lists of behaviour
descriptions and example code, all indented as prescribed by the
[YAML][] file-format.


### 2.1 YAML

[YAML][] makes for a very readable specification file-format, and allows
embedded [Lua][] code right within the standard, as you saw in the last
section.  However, there are some rules to follow as you write your
spec-files in order to maintain valid [YAML][] format that [Specl][] can
load correctly.

Indenting with TAB characters is a syntax error, because the [YAML][]
parser uses indentation columns to infer nesting.  It's easiest just to
avoid putting TAB characters in your spec files entirely.

Punctuation is not allowed in an unquoted [YAML][] string, so you will
need to force the parser to read the description as a string by
surrounding it with `"` (double-quote mark) if you want to put any
punctuation in the description text:

    - "it requires double-quote marks, but only when using punctuation":

Indentation of the code following an example description must be at
least one column further in than the first **letter** of the description
text above, because [YAML][] counts the leading `- ` (minus, space) as
part of the indentation whitespace.

[Specl][] treats everything following the `:` (colon) as a Lua code:

    - it concatenates all following indented lines to a single line:
        Stack = require "stack"
        stack = Stack {}

By default [YAML][] removes indentation and line-breaks from the example
code following the `:` separator, so that by the time [Lua][] receives
the code, it's all on a single line.  More often than not, this isn't a
problem, because the [Lua][] parser is not overly fussy about placement
of line-breaks, but sometimes (to make sure there is a newline to
terminate an embedded comment, for example) you'll need to prevent
[YAML][] from giving [Lua][] everything on a single line. Use the
literal block marker ` |` (space, pipe) after the `:` separator for
this:

    - it does not strip significant whitespace in a literal block: |
        -- A comment on this line, followed by code
        stack = Stack {}
        ...

You also have to be careful about commenting within a spec-file. [YAML][]
comments begin with ` #` (space, hash) and extend to the end of the line.
You can use these anywhere outside of a Lua code block. [Lua][] comments
don't work outside of a lua block, and [YAML][] comments don't work
inside a Lua block, so you have to pick the right comment character,
depending where in the hierarchy it will go.

### 2.2. Contexts

You can further sub-divide your example groups by _context_. In addition
to listing examples in each group, list items can also be contexts,
which in turn list more examples of their own:

    describe a stack:
    - it is empty to start with:
    - context when pushing items:
      - it raises an error if the stack is full:
      - it adds items to the top:
    - context when popping items off the top:
      - it raises an error if the stack is empty:
      - it returns the top item:
      - it removes the popped item:

By convention, the context descriptions start with the word "context",
but [Specl][] doesn't enforce that tradition, so you should just try to
write a description that makes the output easy to understand (see
[Command Line](#specl-command-line)).

Actually, description naming conventions aside, there is no difference
between an example group and a context: Each serves to describe a group
of following examples, or nested contexts.

[Specl][] doesn't place any restrictions on how deeply you nest your
contexts: 2 or 3 is very common, though you should seriously consider
splitting up a spec if you are using more than 4 or 5 levels of nesting
in a single file.

### 2.3. Examples

At the innermost nesting of all those _context_ and _example group_
entries, you will ultimately want to include one or more actual
_examples_. These too are best written with readable names in
plain-English, as shown in the sample from the previous section, but
(unlike contexts) they are followed by the associated example code in
[Lua][], rather than containing more nested contexts.

    describe a stack:
    - it is empty to start with:
        ...EXAMPLE-LUA-CODE...
    - context when pushing items:
      - it raises an error if the stack is full:
          ...EXAMPLE-LUA-CODE...
    ...

Traditionally, the example descriptions start with the words "it",
"example" or "specify", but again, [Lua][] really doesn't mind what you
call them.

### 2.4. Expectations

Each of your examples lists a series of expectations that [Specl][] runs
to determine whether the specification for that part of your project is
being met. Inside the [Lua][] part of each example, you should write a
small block of code that checks that the example being described meets
your expectations. [Specl][] gives you a new `expect` command to check
that each example evaluates as it should:

    - describe a stack:
      - it has no elements when empty:
          stack = Stack {}
          expect (#stack).should_be (0)

The call to expect is almost like English: "Expect size of stack should
be zero."

Behind the scenes, when you evaluate a Lua expression with expect, it's
passed to a _matcher_ method (`.should_be` in this example), which is
used to check whether that expression matched its expected evaluation.
There are quite a few matchers already implemented in [Specl], and you
can easily add new ones if they make your expectations more expressive.

The [next section](#specl-matchers) describes the built in matchers in
more detail.

### 2.5. Pending Examples

Often, you'll think of a useful expectation or behaviour that you don't
have time to implement right now.  Noting it off-line somewhere, or even
adding a commented out example is likely to lead to it being forgotten.
Better to add it to your spec-file as a _pending example_ while it is
still on your mind, so that [Specl][] can remind you that it needs
finishing -- but without contributing a full-blown failing expectation
or specification.

The simplest kind of pending example is an example description with no
associated Lua example code:

    - it raises an error if the stack is full:

The built in formatters will show this as a non-failing unimplemented
(**pending!**) example when the spec-files is run, so you can keep
track of specifications you have yet to write.

Alternatively, if you have written a suitable specification, only to
realise that you are specifying an unimplemented behaviour, just add
the call to `pending ()` somewhere near the beginning of the example
to disable following _expectations_, without removing or commenting out
the `expect` calls:

    - describe a stack:
      - it has no elements when empty:
          pending ()
          stack = Stack {}
          expect (#stack).should_be (0)

This prevents [Specl][] from counting the `expect` result as a failure,
but crucially also allows [Specl][] to inform you when the expectation
begins passing to remind you to remove stale `pending ()` calls from
your specifications.

    ?.....
 
    Summary of pending expectations:
    - a stack has no elements when empty:
      PENDING expectation 1: Passed Unexpectedly!
      You can safely remove the 'pending ()' call from this example

    All expectations met, but 1 still pending, in 0.00366 seconds.

Sometimes, it's useful to add some metadata to a pending example that
you want to see in the summary report.  Pass a single string parameter
to the `pending` function call like this:

    - describe a stack:
      - it cannot remove an element when empty:
          pending "issue #26"
          stack = Stack {}
          expect ("underflow").should_error (stack.pop ())

Running [Specl][] now shows the string in the pending summary report:

    ?.....

    Summary of pending expectations:
    - a stack cannot remove an element when empty:
      PENDING expectation 1: issue #26, not yet implemented

    All expectations met, but 1 still pending, in 0.00332 seconds.


<a id="specl-matchers"></a>
3. Matchers
------------

When `expect` looks up a matcher to validate an expectation, the
`should_` part is just syntactic sugar to make the whole line read more
clearly when you say it out loud.  The idea is that the code for the
specification should be self-documenting, and easily understood by
reading the code itself, rather than having half of the lines in the
spec-file be comments explaining what is going on, and needing to be
kept in sync with the code being described.

The matchers themselves are stored by just the root of their name (`be`
in this case).  See [Inverting a Matcher with
`not`](#inverting-a-matcher), for more about why that is.

The matchers built in to [Specl][] are listed below.

### 3.1. `be`

This matches only when the result of `expect` is the exact same object
as the matcher argument. For example, [Lua][] interns strings as they
are compiled, so this expectation passes:

    expect ("a string").should_be ("a string")

Conversely, [Lua][] constructs a new table object every time it reads
one from the source, so this expectation fails:

    expect ({"a table"}).should_be ({"a table"})

While the tables look the same, and have the same contents, they are
still separate and distinct objects.

### 3.2. `equal`

To get around that problem when comparing tables, use the `equal`
matcher, which does a recursive element by element comparison of the
expectation. The following expectations all pass:

    expect ({}).should_equal ({})
    expect ({1, two = "three"}).should_equal ({1, two = "three"})
    expect ({{1, 2}, {{3}, 4}}).should_equal ({{1, 2}, {{3}, 4}})

### 3.3. `contain`

When comparing strings, you might not want to write out the entire
contents of a very long expected result, when you can easily tell with
just some substring whether `expect` has evaluated as specified:

    expect (backtrace).should_contain ("table expected")

Additionally, when `expect` evaluates to a table, this matcher will
succeed if any element or key of that table matches the expectation
string.  The comparison is done with `equal`, so table elements or
keys can be of any type.

    expect ({{1}, {2}, {5}}).should_contain ({5})

If `expect` passes anything other than a string or table to this
matcher, [Specl][] aborts with an error; use `tostring` or similar if
you need it.

### 3.4. `match`

When a simple substring search is not appropriate, `match` will compare
the expectation against a [Lua][] pattern:

    expect (backtrace).should_match ("\nparse.lua: [0-9]+:")

### 3.5. `error`

Specifications for error conditions are a great idea! And this matcher
checks both that an `error` was raised and that the subsequent error
message contains the supplied substring.

Because [Lua][] evaluates the argument to `expect` before `expect`
receives it, you would have to manually evaluate the expression using
`pcall` to prevent the error it raises from propagating up the stack
past `expect`. The `error` matcher is a syntactic sugar to save writing
the `pcall`, but in order to do that requires the parameters to be in
the opposite order of the other matchers.

Nonetheless, the following are broadly equivalent, though one is *much*
easier to understand than the other:

    expect ("table expected").should_error (next, nil)
    expect (function ()
              ok, msg = pcall (next, nil)
              if ok then return false end
              return msg
            end).should_contain ("table expected")

<a id="inverting-a-matcher"></a>
### 3.6. Inverting a matcher with `not`

Oftentimes, in your specification you need to check that an expectation
does *not* match a particular outcome, and [Specl][] has you covered
there too. Rather than implement another set of matchers to do that
though, you can just insert `not_` right in the matcher method name.
[Specl][] will still call the matcher according to the root name (see
[Matchers](#specl-matchers)), but inverts the result of the comparison
before reporting a pass or fail:

    expect ({}).should_not_be ({})
    expect (tostring (hex)).should_not_contain ("[g-zG-Z]")


4. Example Environments
-------------------------

It's important that every example be evaluated from a clean slate, both
to prevent the side effects of one example affecting the start
conditions of another, and in order to focus on a given example without
worrying what the earlier examples might have done when debugging a
specification.

[Specl][] achieves this by initialising a completely new environment in
which to execute each example, then tearing it down afterwards to build
another clean environment for executing the next example, and so on.

### 4.1. Before and After functions

To keep examples as readable and concise as possible, it's best not to
have too much code in each. For example, it's inefficient to repeat a
few lines of set up and clean up around each expectation.

Much like [RSpec][], [Specl][] supports the use of before and after
functions to isolate that repeated code. A `before` is executed prior to
every example, just after the new environment is initialised, and
conversely `after` is executed immediately after the example has
finished, just prior to tearing the environment down. Since we don't
need any fancy long descriptions for `before` and `after` functions,
their table keys are just a bare `before` or `after` respectively:

    ...
    - before: stack = Stack {}

    - it has no elements when empty:
        expect (#stack).should_equal (0)
    ...

Note that, unlike normal [Lua][] code, we don't declare everything with
`local` scope, since the environment is reset before each example, so no
state leaks out.  And, eliding all the redundant `local` keywords makes
for more concise example code in the specification.

### 4.2. Grouping Examples

If you have used [RSpec][], you'll already know that it supports
`before(:each)` and `before(:all)`, and equivalents for `after`. But
then goes to some lengths to warn that if you initialise any mutable
state inside `before(:all)`, then you've provided a way to let one
example leave side effects that could effect the behaviour of following
examples.

[Specl][]'s `before` is equivalent to [RSpec][]'s `before(:each)`,
although it has no `before(:all)` analogue (and likewise for `after`).
However, [Specl] does support nested contexts, which are mainly useful
for grouping, but also allow you to write a `before` function outside of
a group, where it will behave as if it were a `before(:all)` inside the
group:

    ...
    - describe a Stack:
        - before: |
            -- equivalent to before(:all)
            package.path = "src/?.lua;" .. package.path
            Stack = require "stack"

        - context when inspecting the stack:
            - before: |
                -- equivalent to before(:each)
                stack = Stack {}

            - it has no elements when empty:
            ...

Tricky `before` placement aside, it's always a good idea to organize
large spec files in example groups, and the best way to do that is with
a nested context (and write the description starting with the word
"context" rather than "describe" if you are a traditionalist!).

### 4.3 Environments versus `require`

The ideal way to organize your code to make writing the specification
examples very straight forward is to eliminate (or at least to minimize)
side-effects, so that the behaviour of each API call in every example
is obvious from the parameters and return values alone.

[Specl][] takes pains to isolate examples from one another; making
sure, among other things, that running a function compiled from a string
chunk in the example will only affect the environment of that example
and not leak out into any following examples.  However, `require`
defeats these precautions for two reasons:

  1. Non-local symbols in a required module always refer to `_G` (or
     `_ENV` in Lua 5.2), which, by definition will leak out into
     following examples.  Avoid this by ensuring everything in the
     module is either marked as `local` or returned from the module,
     where the caller can decide whether to corrupt the global
     environment or not.
  2. The returned result of requiring a module is cached, so any code
     executed as a side-effect of the `require` call only takes effect
     on the first call.  Requiring the same module again, even from a
     different example environment, returns the cached result.  Avoid
     this by returning any initial state from the module rather than
     executing arbitrary code on first load.

With good module hygiene, you'll probably never even need to be aware of
the above.  But, if you are writing specifications for an existing
module that has side-effects and/or writes in the global environment the
first time it is required, then you'll need to construct and order the
related code examples carefully not to trip up over either of these two
issues.

Of course, if you do _anything_ at all to change the global environment
(available as `_G` inside example environments) in code you write or
run from a code example, then those changes will be visible to, and
possibly impact upon all subsequent tests. Try to avoid doing this if
you can.


5. Formatters
--------------

As [Specl][] executes examples and tests the expectations of a
specification, it can displays its progress using a formatter.

[Specl][] comes with two formatters already implemented, though you can
write your own very easily if the format of the built in formatters
doesn't suit you.

### 5.1. Progress Formatter

The default formatter simply displays [Specl][]'s progress by writing a
single period for every expectation that is met, or an `F` instead if an
expectation is not met.  Once all the expectations have been evaluated,
a one line summary follows:

    ......
    All expectations met in 0.00233 seconds.

### 5.2. Report Formatter

The other built in formatter writes out the specification descriptions
in an indented list in an easy to read format, followed by a slightly
more detailed summary.

    a stack
      is empty to start with
      when pushing items
         raises an error if the stack is full
         adds items to the top
      when popping items off the top
         raises an error if the stack is empty
         returns the top item
         removes the popped item

    Met 100.00% of 6 expectations.
    6 passed, 0 failed in 0.00250 seconds

Failed expectations are reported inline, and again in the footer with a
long header from the associated nested descriptions, making a failing
example easy to find within a large spec-file.

### 5.3. Custom Formatters

A formatter is just a table of functions that [Specl][] can call as it
runs your specifications, so provided you supply the table keys that
[Specl][] is expecting, you can write your own formatters:

    my_formatter = {
      header       = function () ... end,
      spec         = function (desc_table) ... end,
      expectations = function (status, desc_table) ... end,
      footer       = function (stats, accumulated) ... end,
    }

The functions `header` and `footer` are called before any expectations,
and after all expectations, respectively.  The `stats` argument to
`footer` is a table containing:

    stats = {
      pass      = <PASSED>,
      pend      = <PENDING>,
      fail      = <FAILED>,
      starttime = <CLOCK>,
    }

You can use this to print out statistics at the end of the formatted
output.

The `accumulated` argument to `footer` is a string made by concatenating
all the returned strings, if any, from other calls to the formatter API
functions.  This is useful, for example, to return failure reports from
`expectations` and then display a summary report from `footer`, like the
built in formatters.

Instead of accumulating string returns and concatentating them into a
single long string to pass back into `footer`, a table of named strings
can be returned by your `spec` and `expectations` functions, in which
case the accumulation of those keys is passed back to `footer`.  For
example, if each call to `expectations` returns a table with these two
keys:

    {
      failreport = "description of failed expectation\n",
      pendreport = "description of pending expectation\n",
    }

Then `footer` will be passed a similar table, but with each entry being
the accumulation of every non-empty value returned with that key prior
to `footer` being called.  See the built in formatters for more
detailed examples.

The function `spec` is called with a table of each of the descriptions
that the calling specification or context (the headers with descriptions
that typically begin with either `describe` or `context`) is nested
inside.

And finally, the function `expectations` is called after each example
has been run, passing in a tables with the format shown below, with
one expectation entry for each `expect` call in that example, along with
a similar table of nested descriptions as were passed to `spec`:

    status = {
      expectations = {
        {
          pending = (nil|true),
          status  = (true|false),
          message = "error string",
        },
        ...
      },
      ispending = (nil|true),
    }

The outer `ispending` field will be set to `true` if the entire example
is pending - that is, if it has no example code, save perhaps a call to
the `pending ()` function.

If the `pending` field in one of the `expectations` elements is true, then
a call was made to `expect ()` from a pending example.  The two are
necessary so that formatters can diagnose an unexpected `status == true`
in a pending example, among other things.

The standard [Specl][] formatters in the `specl/formatters/` sub-
directory of your installation show how these functions can be used to
display progress using an output format of your choice.

See the next section for details of how to get [Specl][] to load
your custom formatter.


<a id="specl-command-line"></a>
6. Command Line
-----------------

Given a spec-file or two, along with the implementation of the code
being checked against those specifications, you run [Specl][] inside the
project directory using the provided `specl` command.

The `specl` command expects a list of spec-files to follow, and is
usually called like this:

    specl specs/*_spec.yaml

The output will display results using the default `progress` formatter.
To use the `report` formatter instead, add the `-freport`
option to the command line above.

If you prefer to format the results of your specification examples with
a custom formatter, you should make sure your formatter is visible on
`LUA_PATH`, and use the `--formatter=BASENAME` option to load it.

Note that, for security reasons, Specl removes the current directory
from the system search path, so if you want to load a formatter in the
current directory, you will need to explicitly re-enable loading Lua
code from the current directory:

    LUA_PATH=`pwd`'/?.lua' specl --formatter=awesome specs/*_spec.yaml

Otherwise you can load a formatter from the existing `LUA_PATH` by
name, including built in formatters, like this:

    specl --formatter=tap specs/*_spec.yaml

Pass the `--help` option for help and brief documentation on usage of the
remaining available options.


7. Not Yet Implemented
------------------------

No support for mocks in the current version.

The APIs for adding your own `matchers` are not yet documented.
Please read the code for now.


[lua]: http://www.lua.org
[rspec]: http://github.com/rspec/rspec
[specl]: http://github.com/gvvaughan/specl
[yaml]: http//yaml.org
