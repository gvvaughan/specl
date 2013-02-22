SPECL
====

A specification testing framework, inspired by [RSpec][], for and in
[Lua][].


1. Specifications
-----------------

Specifications are loaded from "spec" files, containing nested tables in
standard Lua syntax, like this:

    {
      {description_1 = context_1},
      ...
      {description_n = context_n},
    }

Only the first expression in each "spec" file is loaded, so make sure
each file has (after comments) just a single table expression, or it
won't load correctly.

### 1.1. Contexts

When describing the contexts (`description_1` above, etc.), it makes for
much more readable specifications to use strings for the table keys:

    {["describe this context"] = {
      ...EXAMPLE-LIST...
    }},
    {["describe another context"] = {
      ...EXAMPLE-LIST...
    }},
    ...

[Specl][] requires wrapping each context entry in its own table like
this, so that it can maintain the file order of your examples when it
runs them.

Traditionally, the context descriptions start with the words "describe"
or "context", but [Lua][] doesn't mind what you call them as long as
they're all different.

### 1.2.  Examples

Each context contains a nested list of one or more examples.  These too
are best written with readable names in strings as table keys, and
(unlike contexts) they are set to a function containing the associated
code:

    {["it has some functionality"] = function ()
        ...EXAMPLE-CODE...
     end},
    {["it works properly"] = function ()
      ...EXAMPLE-CODE...
    end},
    ...

Traditionally, the example descriptions start with the words "it",
"example" or "specify", but [Specl][] doesn't enforce that tradition, so
you should just try to write a description that makes the output easy to
understand (see [Command Line](#specl-command-line)).

### 1.3. Expectations

Each of your "spec" files lists a series of expectations that [Specl][]
runs to determine whether the specification of a part of your project is
being met. Inside the `function` part of each example element, you
should write a small block of code that checks that the example being
described meets your expectations. [Specl][] gives you a new `expect`
command to check that each example evaluates as it should:

    {["describe Stack"] = {
      {["it has no elements when empty"] = function ()
        stack = Stack {}
        expect (#stack).should_be (0)
      end},
    }}

The call to expect is almost like English: "Expect size of stack should
be should be zero."

Behind the scenes, when you evaluate a Lua expression with expect, it's
passed to a *matcher* method (`.should_be` in this example), which is
used to check whether that expression matched its expected evaluation.
There are quite a few matchers already implemented in [Specl], and you
can easily add new ones if they make your expectations more expressive.

The next section describes the built in matchers in more detail.


<a id="specl-matchers"></a>
2. Matchers
------------

When `expect` looks up a matcher to validate an expectation, the
`should_` part is just syntactic sugar to make the whole line read more
clearly when you say it out loud.  The idea is that the code for the
specification should be self-documenting, and easily understood by
reading the code itself, rather than having half of the lines in the
"spec" file be comments explaining what is going on, and needing to be
kept in synch with the code being described.

The matchers themselves are stored by just the root of their name (`be`
in this case).  See [Inverting a Matcher with
`not`](#inverting-a-matcher), for more about why that is.

The matchers built in to [Specl][] are listed below.

### 2.1. `be`

This matches only when the result of `expect` is the exact same object
as the matcher argument. For example, [Lua][] interns strings as they
are compiled, so this expectation passes:

    expect ("a string").should_be ("a string")

Conversely, [Lua][] constructs a new table object every time it reads
one from the source, so this expectation fails:

    expect ({}).should_be ({})

While the tables look the same, and have the same contents (i.e.
nothing!), they are still separate and distinct objects.

### 2.2. `equal`

To get around that problem when comparing tables, use the `equal`
matcher, which does a recursive element by element comparison of the
expectation. The following expectations all pass:

    expect ({}).should_equal ({})
    expect ({1, two = "three"}).should_equal ({1, two = "three"})
    expect ({{1, 2}, {{3}, 4}}).should_equal ({{1, 2} {{3}, 4}})

### 2.3. `contain`

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

### 2.4. `match`

When a simple substring search is not appropriate, `match` will compare
the expectation against a [Lua][] pattern:

    expect (backtrace).should_match ("\nparse.lua: [0-9]+:")

### 2.5. `error`

Specifications for error conditions are a great idea! And this matcher
checks both that an `error` was raised and that the subsequent error
message contains the supplied substring.

Because [Lua][] evaluates the argument to `expect` before `expect`
receives it, you would have to manual evaluate the expression using
`pcall` to prevent the error it raises from propagating up the stack
past the `expect`. The `error` matcher is a syntactic sugar to save
writing the `pcall`, but in order to do that requires the parameters to
be in the opposite order of the other matchers.

Nonetheless, the following are broadly equivalent, though one is *much*
easier to understand than the other:

    expect ("table expected").should_error (next, nil)
    expect (function ()
              ok, msg = pcall (next, nil)
              if ok then return false end
              return msg
            end).should_contain ("table expected")

<a id="inverting-a-matcher"></a>
### 2.6. Inverting a matcher with `not` 

Oftentimes, in your specification you need to check that an expectation
does *not* match a particular outcome, and [Specl][] has you covered
there too. Rather than implement another set of matchers to do that
though, you can just insert `not_` right in the matcher method name.
[Specl][] will still call the matcher according to the root name (see
[Matchers](#specl-matchers)), but inverts the result of the comparison
berfore reporting a pass or fail:

    expect ({}).should_not_be ({})
    expect (tostring (hex)).should_not_contain ("[g-zG-Z]")


3. Example Environments
-------------------------

It's important that every example be evaluated from a clean slate, both
to prevent the side effects of one example affecting the start
conditions of another, and in order to focus on a given example without
worrying what the earlier examples might have done when reading a
specification.

[Specl][] achieves this by initialising a completely new environment in
which to execute each example, then tearing it down afterwards to build
another clean environment for executing the next example, and so on.

### 3.1. Before and After functions

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
    before = function ()
      stack = Stack {}
    end,

    {["it has no elements when empty"] = function ()
      expect (#stack).should_equal (0)
    end}
    ...

Note that, unlike normal [Lua][] code, we don't declare everything with
`local` scope, since the environment is reset before each example, so no
state leaks out.  And, eliding all the redundant `local` keywords makes
for more concise example code in the specification.

### 3.2. Grouping Examples

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
    {["describe a Stack"] = {
        before = function () -- equivalent to before(:all)
          package.path = "src/?.lua;" .. package.path
          Stack = require "stack"
        end,

        {["context when inspecting the stack"] = function ()
          before = function () -- equivalent to before(:each)
            stack = Stack {}
          end,

          {["it has no elements when empty"] = function ()
            ...

Tricky `before` placement aside, it's always a good idea to organize
large spec files in example groups, and the traditional way to do that
is with a nested context (and write the description starting with the
word "context" rather than "describe" if you are a traditionalist!).

[Specl][] doesn't place any restrictions on how deeply you nest your
contexts: 2 or 3 is very common, though you should seriously consider
splitting up a spec if you are using more than 4 or 5 levels of nesting
in a single file.


4. Formatters
--------------

As [Specl][] executes examples and tests the expectations of a
specification, it can displays its progress using a formatter.

[Specl][] comes with two formatters already implemented, though you can
write your own very easily if the format of the built in formatters
doesn't suit you.

### 4.1. Progress Formatter

The default formatter simply displays [Specl][]'s progress by writing a
single period for every expectation that is met, or an `F` instead if an
expectation is not met.  Once all the expectations have been evaluated,
a one line summary follows:

    ......
    All expectations met, in 0.00233 seconds.

### 4.2.  Report Formatter

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

Failed expectations are reported inline, making the failing example easy
to find within a large "spec" file.


<a id="specl-command-line"></a>
5. Command Line
-----------------

Given a "spec" file or two, along with the implementation of the code
being checked against those specifications, you run [Specl][] inside the
project directory using the provided `specl` command.

The `specl` command expects a list of "spec" files to follow, and is
usually called like this:

    specl specs/*_spec.lua

The output will display results using the default `progress` formatter.
To use the `report` formatter instead, add the `-v` option to the
command line above.

Pass the `-h` option for help and brief documentation on usage of the
remaining available options.


6. Not Yet Implemented
------------------------
    
No support for mocks, or pending examples in the current version.

The APIs for adding your own `matchers` and `formatters` are not yet
documented.  Please read the code for now.


[specl]: http://github.com/gvvaughan/specl
[rspec]: http://github.com/rspec/rspec
[lua]: http://www.lua.org
