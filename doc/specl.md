---
layout: default
---
# SPECL

[Specl] is testing tool for [Lua], providing a
[Behaviour Driven Development][BDD] framework in the vein of [RSpec].

 * textual descriptions of examples and groups ([spec files](#1-specifications) using [YAML])
 * extensible expectation language ([matchers](#2-matchers))
 * self-contained execution environments ([environments](#3-environments))
 * flexible and customizable reporting ([formatters](#4-formatters))
 * a rich command line program (the [`specl` command](#5-command-line))


## 1. Specifications

The `specl` command verifies that the behaviour of your software meets
the specifications encoded in one or more _spec-files_. A spec-file is
a [YAML] structured file, laid out as groups of nested plain-English
descriptions of specifications, with associated snippets of [Lua]
code that verify whether the software behaves as described.

A tiny spec-file outline follows:

{% highlight yaml %}
    describe specification file format:
    - it is just a list of examples with descriptions:
        with_Lua_code ("to verify described behaviours")
    - it is followed by additional specifications:
        print "Lua example code demonstrates this specification"
        print "on several (indented) lines, if necessary."
{% endhighlight %}

The first significant line of any specification is the plain-English
description of the first example group, ending with a `:` (colon).

Underneath that are two examples, each starting with `-_` (minus, space)
and separated by a `:` (colon) into a _description_ of some desired
behaviour, and the associated [Lua] code to demonstrate it.

The descriptions above follow the [RSpec] convention of using
_describe_ as the first word of a group description, and _it_ as the
first word of an example description.  [Specl] doesn't enforce them,
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
[YAML] file-format.


### 1.1 YAML

[YAML] makes for a very readable specification file-format, and allows
embedded [Lua] code right within the standard, as you saw in the last
section.  However, there are some rules to follow as you write your
spec-files in order to maintain valid [YAML] format that [Specl] can
load correctly.

Indenting with TAB characters is a syntax error, because the [YAML]
parser uses indentation columns to infer nesting.  It's easiest just to
avoid putting TAB characters in your spec files entirely.

Some punctuation is not allowed in an unquoted [YAML] string, so you
will need to force the parser to read the description as a string by
surrounding it with `"` (double-quote mark) if you want to put any
punctuation in the description text:

{% highlight yaml %}
    - "it requires double-quote marks: but only when using punctuation":
{% endhighlight %}

Indentation of the code following an example description must be at
least one column further in than the first **letter** of the description
text above, because [YAML] counts the leading `-_` (minus, space) as
part of the indentation whitespace.

[Specl] treats everything following the `:` (colon) as a Lua code:

{% highlight yaml %}
    - it concatenates all following indented lines to a single line:
        Stack = require "stack"
        stack = Stack {}
{% endhighlight %}

By default [YAML] removes indentation and line-breaks from the example
code following the `:` separator, so that by the time [Lua] receives
the code, it's all on a single line.  More often than not, this isn't a
problem, because the [Lua] parser is not overly fussy about placement
of line-breaks, but sometimes (to make sure there is a newline to
terminate an embedded comment, for example) you'll need to prevent
[YAML] from giving [Lua] everything on a single line. Use the
literal block marker `_|` (space, pipe) after the `:` separator for
this:

{% highlight yaml %}
    - it does not strip significant whitespace in a literal block: |
        -- A comment on this line, followed by code
        stack = Stack {}
        ...
{% endhighlight %}

You also have to be careful about commenting within a spec-file. [YAML]
comments begin with `_#` (space, hash) and extend to the end of the line.
You can use these anywhere outside of a Lua code block, including any
lines immediately following a description before any actual [Lua] code.
[Lua] comments don't work outside of a lua block, and [YAML] comments
don't work inside a Lua block, so you have to pick the right comment
character, depending where in the hierarchy it will go.

### 1.2. Contexts

You can further sub-divide your example groups by _context_. In addition
to listing examples in each group, list items can also be contexts,
which in turn list more examples of their own:

{% highlight yaml %}
    describe a stack:
    - it is empty to start with:
    - context when pushing items:
      - it raises an error if the stack is full:
      - it adds items to the top:
    - context when popping items off the top:
      - it raises an error if the stack is empty:
      - it returns the top item:
      - it removes the popped item:
{% endhighlight %}

By convention, the context descriptions start with the word "context",
but [Specl] doesn't enforce that tradition, so you should just try to
write a description that makes the output easy to understand (see
[Command Line](#5-command-line)).

Actually, description naming conventions aside, there is no difference
between an example group and a context: Each serves to describe a group
of following examples, or nested contexts.

[Specl] doesn't place any restrictions on how deeply you nest your
contexts: 2 or 3 is very common, though you should seriously consider
splitting up a spec if you are using more than 4 or 5 levels of nesting
in a single file.

### 1.3. Examples

At the innermost nesting of all those _context_ and _example group_
entries, you will ultimately want to include one or more actual
_examples_. These too are best written with readable names in
plain-English, as shown in the sample from the previous section, but
(unlike contexts) they are followed by the associated example code in
[Lua], rather than containing more nested contexts.

{% highlight yaml %}
    describe a stack:
    - it is empty to start with:
        ...EXAMPLE-LUA-CODE...
    - context when pushing items:
      - it raises an error if the stack is full:
          ...EXAMPLE-LUA-CODE...
    ...
{% endhighlight %}

Traditionally, the example descriptions start with the words "it",
"example" or "specify", but again, [Lua] really doesn't mind what you
call them.

### 1.4. Expectations

Each of your examples lists a series of expectations that [Specl] runs
to determine whether the specification for that part of your project is
being met. Inside the [Lua] part of each example, you should write a
small block of code that checks that the example being described meets
your expectations. [Specl] gives you a new `expect` command to check
that each example evaluates as it should:

{% highlight yaml %}
    - describe a stack:
      - it has no elements when empty:
          stack = Stack {}
          expect (#stack).to_be (0)
{% endhighlight %}

The call to expect is almost like English: "Expect size of stack to be
zero."

Behind the scenes, when you evaluate a Lua expression with expect, it's
passed to a _matcher_ method (`.to_be` in this example), which is
used to check whether that expression matched its expected evaluation.
There are quite a few matchers already implemented in [Specl], and you
can easily add new ones if they make your expectations more expressive.

The [next section](#2-matchers) describes the built in matchers in
more detail.  The `specl.shell` module provides some specialist matchers
for checking whether shell commands have behaved according to
specifications; see [the section on shell commands](#shell-commands) for
more details on those.

### 1.5. Pending Examples

Often, you'll think of a useful expectation or behaviour that you don't
have time to implement right now.  Noting it off-line somewhere, or even
adding a commented out example is likely to lead to it being forgotten.
Better to add it to your spec-file as a _pending example_ while it is
still on your mind, so that [Specl] can remind you that it needs
finishing -- but without contributing a full-blown failing expectation
or specification.

The simplest kind of pending example is an example description with no
associated Lua example code:

{% highlight yaml %}
    - it raises an error if the stack is full:
{% endhighlight %}

The built in formatters will show this as a non-failing unimplemented
(**pending!**) example when the spec-file is checked, so you can keep
track of specifications for code you have yet to write.

Alternatively, if you have written a suitable specification, only to
realise that you are specifying an unimplemented behaviour, just add
a call to `pending ()` somewhere near the beginning of the example
to disable following _expectations_, without removing or commenting out
the `expect` calls:

{% highlight yaml %}
    - describe a stack:
      - it has no elements when empty:
          pending ()
          stack = Stack {}
          expect (#stack).to_be (0)
{% endhighlight %}

This prevents [Specl] from counting the `expect` result as a failure,
but crucially also allows [Specl] to inform you when the expectation
begins passing to remind you to remove stale `pending ()` calls from
your specifications.

{% highlight yaml %}
    ?.....

    Summary of pending expectations:
    - a stack has no elements when empty:
      PENDING expectation 1: Passed Unexpectedly!
      You can safely remove the 'pending ()' call from this example

    All expectations met, but 1 still pending, in 0.00366 seconds.
{% endhighlight %}

Sometimes, it's useful to add some metadata to a pending example that
you want to see in the summary report.  Pass a single string parameter
to the `pending` function call like this:

{% highlight yaml %}
    - describe a stack:
      - it cannot remove an element when empty:
          pending "issue #26"
          stack = Stack {}
          expect (stack.pop ()).to_error "underflow"
{% endhighlight %}

Running [Specl] now shows the string in the pending summary report:

{% highlight yaml %}
    ?.....

    Summary of pending expectations:
    - a stack cannot remove an element when empty:
      PENDING expectation 1: issue #26, not yet implemented

    All expectations met, but 1 still pending, in 0.00332 seconds.
{% endhighlight %}


### 1.6. Skipping Examples

There is no need for a formal `skip` command in [Specl]; the example
execution engine will not display the descriptions of examples that have
no live expectations.

{% highlight yaml %}
    - specify Set:
      - before:
          Set = require "std.set"
      - it supports the hash operator: |
          set = Set {"foo", "bar", "bar"}
          if tonumber (_VERSION:match "Lua (%d+%.%d+)") >= 5.2 then
            expect (#set).to_be (2)
          end
      - it reports membership:
          set = Set {"baz"}
          expect (Set.member (set, "foo")).not_to_be (true)
          expect (Set.member (set, "baz")).to_be (true)
{% endhighlight %}

When running this spec-file with the [Lua] 5.2 interpreter, the
hash example expectation fires, and its result is reported:

{% highlight yaml %}
    Set
      supports the hash operator
      reports membership
{% endhighlight %}

However, with [Lua] 5.1 (which does not respect the `__len` metamethod
of tables with the hash operator), the `if` expression will be false, and
so the `expect` command is not executed.  In that case, formatters do
not report that result, effectively skipping the example:

{% highlight yaml %}
    Set
      reports membership
{% endhighlight %}

Note that, like `pending` examples, the example Lua code **is**
executed and needs to be well formed, it is just ignored by formatters
when reporting the results from a spec-file.


## 2. Matchers

When `expect` looks up a matcher to validate an expectation, the
`to_` part is just syntactic sugar to make the whole line read more
clearly when you say it out loud.  The idea is that the code for the
specification should be self-documenting, and easily understood by
reading the code itself, rather than having half of the lines in the
spec-file be comments explaining what is going on, and needing to be
kept in sync with the code being described.

The matchers themselves are stored by just the root of their name (`be`
in this case).  See
[Inverting a Matcher with not](#inverting-a-matcher-with-not), for more
about why that is.

The matchers built in to [Specl] are listed below.

### 2.1. be

This matches only when the result of `expect` is the exact same object
as the matcher argument. For example, [Lua] interns strings as they
are compiled, so this expectation passes:

{% highlight lua %}
    expect ("a string").to_be ("a string")
{% endhighlight %}

Conversely, [Lua] constructs a new table object every time it reads
one from the source, so this expectation fails:

{% highlight lua %}
    expect ({"a table"}).to_be ({"a table"})
{% endhighlight %}

While the tables look the same, and have the same contents, they are
still separate and distinct objects.

### 2.2. equal

To get around that problem when comparing tables, or std.object derived
objects, use the `equal` matcher, which does a recursive element by
element comparison of the contents of the expectation arguments. The
following expectations all pass:

{% highlight lua %}
{% raw %}
    expect ({}).to_equal ({})
    expect ({1, two = "three"}).to_equal ({1, two = "three"})
    expect ({{1, 2}, {{3}, 4}}).to_equal ({{1, 2}, {{3}, 4}})

    Set = require "std.set"
    expect (Set {1, 2, 5, 3}).to_equal (Set {5, 1, 2, 3})
{% endraw %}
{% endhighlight %}

### 2.3. copy

Like `equal`, this matcher is also useful for comparing tables, or
std.object derived objects, and usually gives the same results.
However, `copy` will fail if the result of `expect` is the exact same
object as the matcher argument.  The following example:

{% highlight lua %}
    t = {"foo"}
    expect (table.clone (t)).to_copy (t)
{% endhighlight %}

is equivalent to:

{% highlight lua %}
    t = {"foo"}
    expect (table.clone (t)).to_equal (t)
    expect (table.clone (t)).not_to_be (t)
{% endhighlight %}

### 2.4. contain

When comparing strings, you might not want to write out the entire
contents of a very long expected result, when you can easily tell with
just some substring whether `expect` has evaluated as specified:

{% highlight lua %}
    expect (backtrace).to_contain ("table expected")
{% endhighlight %}

Additionally, when `expect` evaluates to a table, this matcher will
succeed if any element or key of that table matches the expectation
string.  The comparison is done with `equal`, so table elements or
keys can be of any type.

{% highlight lua %}
{% raw %}
    expect ({{1}, {2}, {5}}).to_contain ({5})
{% endraw %}
{% endhighlight %}

A final convenience is that `contain` will use the `__totable`
metamethod of any lua-stdlib `std.object` derived objects to coerce
a table to test for matching keys or values in the expectation.

If `expect` passes anything other than a string, table or `std.object`
derivative to this matcher, [Specl] aborts with an error; use
`tostring` or similar if you need to.

### 2.5. match

When a simple substring search is not appropriate, `match` will compare
the expectation against a [Lua] pattern:

{% highlight lua %}
    expect (backtrace).to_match ("\nparse.lua: [0-9]+:")
{% endhighlight %}

### 2.6. error

Specifications for error conditions are a great idea! And this matcher
checks both that an `error` was raised and that the subsequent error
message contains the supplied substring, if any.

{% highlight lua %}
    expect (next (nil)).to_error ("table expected")
{% endhighlight %}

### 2.7. Inverting a matcher with not

Oftentimes, in your specification you need to check that an expectation
does **not** match a particular outcome, and [Specl] has you covered
there too. Rather than implement another set of matchers to do that
though, you can just insert `not_` right in the matcher method name.

You can write `not_` either before or after `to_`, whichever you find
most readable. Some people are annoyed by split infinitives, but
[Specl] is not as grumpy as that, and will happily accept `to_not_`
or `not_to_` as entirely equivalent.

[Specl] will still call the matcher according to the root name (see
[Matchers](#2-matchers)), but inverts the result of the comparison
before reporting a pass or fail:

{% highlight lua %}
    expect ({}).not_to_be ({})
    expect (tostring (hex)).not_to_contain ("[g-zG-Z]")
    expect (next {}).not_to_error ()
{% endhighlight %}

Note that the last `not_to_error` example doesn't pass the error
message substring that _to not_ match, because it is never checked,
but you can pass the string if it makes an expectation clearer.

### 2.8. Matcher adaptors

In addition to using matchers for straight one-to-one comparisons
between the result of an `expect` and the argument provided to the
matcher, [Specl] has some shortcuts that can intercept the arguments
and adapt the comparison sequence.  These shortcuts are called
_adaptors_.

#### 2.8.1. Matching alternatives with any_of

When you want to check whether an expectation matches among a list of
alternatives, [Specl] supports an `any_of` adaptor for any matcher:

{% highlight lua %}
    expect (ctermid ()).to_match.any_of {"/.*tty%d+", "/.*pts%d+"}
{% endhighlight %}

The expectation above succeeds if `ctermid ()` output matches any of
the patterns in the table argument to `any_of`.

Conversely, as you might expect, when you combine `any_of` with `not`,
an expectation succeeds only if none of the alternatives match:

{% highlight lua %}
    expect (type "x").not_to_be.any_of {"table", "nil"}
{% endhighlight %}

#### 2.8.2. Multiple matches with all_of

When you need to ensure that several matches succeed, [Specl] provides
the `all_of` adaptor:

{% highlight lua %}
    expect (("1 2 5"):split " ").to_contain.all_of {"1", "2"}
{% endhighlight %}

This expectation succeeds if the `split` method produces a table that
contains each of the strings in the argument to `all_of`; note that it
does not fail if there are elements other than those specified - the
example above will succeed even though there is (presumably!) an
unchecked `"5"` element in the table returned by this `split`.

For completeness, `all_of` can surely be combined with `not`, but the
resulting expression is hard to understand, so I recommend that you
don't use it.  Try running the following to see whether it behaves as
you expect, and notice how carefully you have to think about it
compared to the usual English inspired syntax of [Specl]
expectations:

{% highlight lua %}
    expect ({true}).not_to_contain.all_of {true, false}
{% endhighlight %}

If you want to assert that an expectation does not contain any of the
supplied elements, it is far better to use:

{% highlight lua %}
    expect ({non_boolean_result}).not_to_contain.any_of {true, false}
{% endhighlight %}

#### 2.8.3. Unordered matching with a_permutation_of

While [Specl] makes every effort to maintain ordering of elements in
the tables (and objects) it uses, there are times when you really want
to check the contents of an inherently unordered expectation - say,
that `pairs` returns all the elements of a set containing functions
which can't be guaranteed to have the same sort order on every run.

{% highlight lua %}
    fn_set, elements = {math.sin=true, math.cos=true, math.tan=true}, {}
    for fn in pairs (fn_set) do elements[#elements + 1] = fn end
    expect (elements).to_contain.permutation_of (fn_set)
{% endhighlight %}

In this example, sorting `elements` before comparing them is dangerous,
because we can't know what order the addresses of the functions it
contains will have been assigned by [Lua], but using `permutation_of`
here guarantees that `elements` contains the same elements as `fn_set`
irrespective of order.

Prior to the introduction of `a_permutation_of`, `all_of` was the nearest
equivalent functionality - but `all_of` will not complain if `elements`
has even more elements than what it is supposed `to_contain` at the time
of comparison.

### 2.9. Custom Matchers

Just like the built in matchers described above, you can use the
`Matcher` factory object from `specl.matchers` to register additional
custom matchers to make your spec files easier to understand. The
minimum required is a predicate method, which is then called by
[Specl] to determine whether the result of an `expect` parameter
matches the contents of the `to_` argument:

{% highlight lua %}
    ...
    matchers.Matcher {
      function (self, actual, expected)
        return (actual == expected)
      end,
    }
    ...
{% endhighlight %}

This is exactly how the `be` matcher is implemented, where [Specl]
passes the `actual` result from the expectation and the `expected`
value from the `to_` argument -- and considers the expectation as
a whole to have passed if they are both the same according to a [Lua]
`==` comparison.

Of course, our custom `be` matcher reimplementation is not available
to spec files until it has been registered in [Specl]s matcher table.
You can do this in a `before` block, or your `spec_helper.lua` (see
[Separating Helper Functions](#separating-helper-functions)).

{% highlight lua %}
    ...
    matchers = require "specl.matchers"

    matchers.matchers.be_again = matchers.Matcher {
      function (self, actual, expected)
    ...
{% endhighlight %}

Note that the `matchers` table needs to do some work to fully install
the new `be_again`, and so checks that the assignment is the result
of a `Matcher` factory call.  Trying to assign anthing else won't
work - although nothing stops you from cloning the `Matcher`
prototype to set default fields and methods prior to assignment.

If you try to use `be_again` as it stands, you'll discover that it
doesn't display the results from failed expectations as nicely as the
real `be` matcher - missing the defining "exactly" text in the output.
To implement additional formatting around the `expected` message, add
an implementation for the optional `format_expect` method to the
`Matcher` constructor:

{% highlight lua %}
    ...
    matchers.matchers.be_again = matchers.Matcher {
      function (self, actual, expected)
        return (actual == expected)
      end,

      format_expect = function (self, expected)
        return " exactly " .. matchers.stringify (expected)
      end,
    }
    ...
{% endhighlight %}

Notice the use of `matchers.stringify` to coerce the `expected`
parameter to a nicely formatted and quoted string.  `stringify` is
less useful here than it is in the other formatting method slot,
`format_actual`.

Both of these methods are passed all of the arguments that are
generated in the code wrapped in `expect` that eventually leads to
the custom matcher, though they are not useful in this particular
example, the full prototypes are:

{% highlight lua %}
    function format_expect (self, expected, actual, ...)
    function format_actual (self, actual, expected, ...)
{% endhighlight %}

The `specl.shell` custom matchers use this feature if you want to see
an example of how it can be useful.

Usually, you'll also need to provide nicely formatted messages when
`any_of` calls fail.  Not surprisingly, to do that, you define another
method in the `Matcher` constructor:

{% highlight lua %}
    function format_alternatives (self, adaptor, alternatives, actual, ...)
{% endhighlight %}

When constructed without a specific `format_alternatives` entry,
`Matcher` uses the default format, similarly to how `table.concat`
behaves with ", " separators, except that the final separator is always
the string " or ", and the individual entries are stringified first.  If
you want to make use of that format in your own matchers, it is
available in `specl.util` as `concat`.  Again examples of this, and the
more complicated shell output formatter (`specl.util.reformat`) are
available in the source code, from `lib/specl/shell.lua`.

One final feature of the `Matcher` constructor is that you can have it
enforce a particular type (or types) for the `actual` parameter, by
setting `actual_types` to a list of acceptable types.  For example,
the built in `contain` matcher handles matching against both Lua string
types and Lua tables:

{% highlight lua %}
    matchers.matchers.contain = matchers.Matcher {
      ...
      actual_type = {"string", "table"},
    ...
{% endhighlight %}

Valid values for this list include any of the core Lua types as
returned by the Lua `type` function, but also any extended types
implemented as a table with a `type` field, such as the `process` and
`command` objects defined by the `specl.shell` extensions, or anything
else you care to build using the `specl.std.Object` base type (such
as the `Matcher` factory object used throughout this section of the
manual).

Adding custom matcher with this API automatically handles lookups
with `to_` and inverting matchers with the `not_` string.

#### 2.9.1. Custom Adaptors

When you create a custom matcher, it can often improve the
expressiveness of your spec files to allow additional custom adaptors
that are specific to a particular Matcher object (and other Matchers
cloned from it).

Any `Matcher` based object method named with a trailing question-mark
will be called automatically if that matcher is invoked with an
equivalent adaptor name. For example, the built in adaptors, `all_of`
and `any_of` are implemented as methods called `all_of?` and `any_of?`
on the base `Matcher` object:

{% highlight lua %}
    Matcher = Object {
      ...
      ["all_of?"] = function (self, actual, alternatives, ...) ... end,
      ["any_of?"] = function (self, actual, alternatives, ...) ... end,
      ...
{% endhighlight %}

To add a custom adaptor to `be_again`, we simply define the custom
adaptor method in the same way.  For consistency with the built in
adaptors, I strongly recommend that you perform type checks against the
`Matcher`'s `actual_type` field:

{% highlight lua %}
    local util = require "specl.util"

    matchers.matchers.be_again = Matcher {
      ...
      ["the_same_size_as?"] = function (self, actual, expected, ...)
        util.type_check ("expect", {actual}, {self.actual_type})
        util.type_check ("the_same_size_as", {expected}, {"#table"})

        return (#actual == #expected),
          "expecting a table the same size as" ..
          self.format_expect (expected, actual, ...) .. "but got" ..
          self.format_actual (actual, expected, ...)
      end,
      ...
{% endhighlight %}

The utility function `type_check` checks that the types of each element
of the table in argument 2 match one of the corresponding type names
from argument 3, or else raise an error for mismatched arguments using
the name given in argument 1.  So the first call to `type_check`
enforces that `actual`, the argument to `"expect"`, matches one of the
types listed in the object's `actual_type` field; and the next call
enforces that `expected`, the argument to `"the_same_size_as"`, is a
non-empty table. See the API documentation for more details of how to
use `type_check`.

To make this adaptor work properly with [Specl], it must return a
boolean decribing whether the adaptor matched successfully, followed by
an error message that specl will use if the overall expectation failed
(which can happen even when we return `true`, if the expectation uses
`not_to_`).  Again, we use the `Matcher` object's format functions to
ensure that any specialisations of this particular object will continue
to behave properly with custom `format_` functions too.

There is nothing sacred about the built in matchers, so feel free to add
additional adaptors to the existing `Matcher` objects too:

{% highlight lua %}
    local matchers = (require "specl.matchers").matchers

    for _, m in pairs (matchers) do
      m["the_same_size_as?"] = function (self, actual, expect, ...)
        ...
      end
    end
{% endhighlight %}

And then [Specl] will support expectations such as:

{% highlight yaml %}
    - transform:
      - it remains the same size:
          expect (transform (subject)).
            to_be.the_same_size_as (subject)
{% endhighlight %}

Some adaptors (such as the `any_of` built in adaptor) need access to the
match function normally used by a plain matcher (i.e. without an
adaptor) to compare the result of the `expect` call (`actual`) against
each of the alternatives in a table passed to the adaptor (`expected`).
That function is stored as a matcher method that can be accessed from
the adaptor method with `self.matchp`.



## 3. Environments

It's important that every example be evaluated from a clean slate, both
to prevent the side effects of one example affecting the start
conditions of another, and in order to focus on a given example without
worrying what the earlier examples might have done when debugging a
specification.

[Specl] achieves this by initialising a completely new environment in
which to execute each example, then tearing it down afterwards to build
another clean environment for executing the next example, and so on.

### 3.1. Before and After functions

To keep examples as readable and concise as possible, it's best not to
have too much code in each. For example, it's inefficient to repeat a
few lines of set up and clean up around each expectation.

Much like [RSpec], [Specl] supports the use of before and after
functions to isolate that repeated code. A `before` is executed prior to
every example, just after the new environment is initialised, and
conversely `after` is executed immediately after the example has
finished, just prior to tearing the environment down. Since we don't
need any fancy long descriptions for `before` and `after` functions,
their table keys are just a bare `before` or `after` respectively:

{% highlight yaml %}
    ...
    - before: stack = Stack {}

    - it has no elements when empty:
        expect (#stack).to_equal (0)
    ...
{% endhighlight %}

Note that, unlike normal [Lua] code, we don't declare everything with
`local` scope, since the environment is reset before each example, so no
state leaks out.  And, eliding all the redundant `local` keywords makes
for more concise example code in the specification.

### 3.2. Grouping Examples

If you have used [RSpec], you'll already know that it supports
`before(:each)` and `before(:all)`, and equivalents for `after`. But
then goes to some lengths to warn that if you initialise any mutable
state inside `before(:all)`, then you've provided a way to let one
example leave side effects that could affect the behaviour of following
examples.

[Specl]'s `before` is equivalent to [RSpec]'s `before(:each)`,
and it has no `before(:all)` analogue (and likewise for `after`).
However, [Specl] does support nested contexts, which are mainly useful
for grouping, but also allow you to write a `before` function outside of
a group, where it will behave as if it were a `before(:all)` inside the
group:

{% highlight yaml %}
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
{% endhighlight %}

Tricky `before` placement aside, it's always a good idea to organize
large spec files in example groups, and the best way to do that is with
a nested context (and write the description starting with the word
"context" rather than "describe" if you are a traditionalist!).

### 3.3. Separating Helper Functions

Oftentimes, spec files can become crowded with so much setup code that
the actual specifications can get lost in the noise.  In this case, it
helps the clarity of the specification files, and the helper code too,
if you move as much of it as appropriate into a separate file, usually
called `spec_helper.lua`.

[Specl] automatically loads the `spec_helper.lua` file from the same
directory as the spec file being loaded.  Thus, any global symbols set by
`spec_helper.lua` are available to all the spec files it shares a
directory with.

Almost always, there is a `spec_helper.lua` that sets up the Lua
`package.path` and `package.cpath` to the relative paths from the
top-level project directory so that you can run `specl` directly from
the command line in that directory without needing a wrapper script or
special `make` rules to set them on each invocation:

{% highlight lua %}
local std = require 'specl.std'
local path = std.io.catfile ("lib", "?.lua")

package.path = std.package.normalize (path, package.path)
{% endhighlight %}


## 4. Formatters

As [Specl] executes examples and tests the expectations of a
specification, it can displays its progress using a formatter.

[Specl] comes with two formatters already implemented, though you can
write your own very easily if the format of the built in formatters
doesn't suit you.

### 4.1. Progress Formatter

The default formatter simply displays [Specl]'s progress by writing a
single period for every expectation that is met, or an `F` instead if an
expectation is not met.  Once all the expectations have been evaluated,
a one line summary follows:

{% highlight yaml %}
    ......
    All expectations met in 0.00233 seconds.
{% endhighlight %}

In verbose mode (see [Command Line](#5-command-line)), a longer description of any
pending or failing examples is displayed, along with the file and line
location of each.

### 4.2. Report Formatter

The other built in formatter writes out the specification descriptions
in an indented list in an easy to read format, followed by a slightly
more detailed summary.

{% highlight yaml %}
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
{% endhighlight %}

Failing and pending expectations are annotated inline, and again with
more detail in the summary footer.

In verbose mode (see [Command Line](#5-command-line)), the inline
annotations are expanded to the more detailed summary format, and both
inline and summary reports give the file and line number of each, making
a particular example easy to find within a large spec-file.

### 4.3. Custom Formatters

A formatter is just a table of functions that [Specl] can call as it
runs your specifications, so provided you supply the table keys that
[Specl] is expecting, you can write your own formatters:

{% highlight lua %}
    my_formatter = {
      header       = function () ... end,
      spec         = function (desc_table) ... end,
      expectations = function (status, desc_table) ... end,
      footer       = function (stats, accumulated) ... end,
    }
{% endhighlight %}

The functions `header` and `footer` are called before any expectations,
and after all expectations, respectively.

The `stats` argument to `footer` is a table containing:

{% highlight lua %}
    stats = {
      pass      = <PASSED>,
      pend      = <PENDING>,
      fail      = <FAILED>,
      starttime = <CLOCK>,
    }
{% endhighlight %}

You can use this to print out statistics at the end of the formatted
output. Note that `starttime` may be the result of an earlier call to
`os.time ()`, or if `luaposix` is installed where [Specl] can find it,
it will be the result of an earlier call to `posix.gettimeofday ()`.
In either case, you can pass it to `specl.util.timesince (earlier)` to
turn it into a printable time elapsed since `earlier` (with the best
resolution available):

{% highlight lua %}
  local util = require "specl.util"
  print ("Time elapsed is " ..
         util.timesince (stats.starttime) .. " seconds.")
{% endhighlight %}

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

{% highlight lua %}
    {
      failreport = "description of failed expectation\n",
      pendreport = "description of pending expectation\n",
    }
{% endhighlight %}

Then `footer` will be passed a similar table, but with each entry being
the accumulation of every non-empty value returned with that key prior
to `footer` being called.  See the built in formatters for more
detailed examples.

The function `spec` is called with a table of each of the descriptions
that the calling specification or context (the headers with descriptions
that typically begin with either `describe` or `context`) is nested
inside.

And finally, the function `expectations` is called after each example
has been run, passing in a table with the format shown below, with
one expectation entry for each `expect` call in that example, along with
a similar table of nested descriptions as were passed to `spec`:

{% highlight lua %}
    status = {
      filename = "name of spec-file",
      line     = nn,

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
{% endhighlight %}

The `filename` and `line` fields hold the filename and line-number from
which the example being reported came.

The outer `ispending` field will be set to `true` if the entire example
is pending - that is, if it has no example code, save perhaps a call to
the `pending ()` function.

If the `pending` field in one of the `expectations` elements is true, then
a call was made to `expect ()` from a pending example.  The two are
necessary so that formatters can diagnose an unexpected `status == true`
in a pending example, among other things.

The standard [Specl] formatters in the `lib/specl/formatters/`
directory of the sources show how these functions can be used to
display progress using an output format of your choice.

See the next section for details of how to get [Specl] to load
your custom formatter.


## 5. Command Line

Given a spec-file or two, along with the implementation of the code
being checked against those specifications, you run [Specl] inside the
project directory using the provided `specl` command.

The `specl` command expects spec-files to be kept in a top-level
directory named `specs/`, and to have names ending in `_spec.yaml`. As
long as you follow that format, invoking `specl` will find and check
all the matching spec-files automatically.

{% highlight bash %}
    specl
{% endhighlight %}


### 5.1. Running a Subset of Examples

Often, after adding the new examples for a feature, you're left with
a block of failing tests that scroll off the screen when the following
passing and failing examples are reported, even though you want to
work on the first failure first -- because you've sensibly ordered your
examples with the fundamental features earlier than the later examples
that depend on those earlier ones.  Use the `--fail-fast` option to stop
checking examples as soon as the first failure has been reported.

{% highlight bash %}
    specl --fail-fast
{% endhighlight %}

Once you have accumulated a large collection of spec-files, you might
only need to check a selection of specs relevent to the files you are
working on.  As long as you follow the best practice of putting specs
for, say, a source file named `foo/bar/baz.lua` in a spec-file named
`specs/foo/bar/baz_spec.yaml`, you can list just the specs that are
named for the list of files you're working on, like this:

{% highlight bash %}
    specl specs/foo_spec.yaml specs/bar/*_spec.yaml
{% endhighlight %}

The output will display results using the default `progress` formatter.
To use the `report` formatter instead, add the `-freport`
option to the command line above.

For finer grained selection of a subset of examples than by file,
[Specl] accepts any number of filters to match against the full nested
[YAML] path to each example, using the `--example=PATTERN` option.
Given the following spec-file:

{% highlight yaml %}
specify module:
- context group one:
  - it passes:
      expect (1).to_be (1)
  - it hasn't decided yet:
- context group two:
  - it fails:
      expect (1).to_be (0)
  - it fails again:
      expect (0).to_be (1)
{% endhighlight %}

The full name of an example is made by starting at the nearest top level
[YAML] description field, and concatenating all of the nested
descriptions that lead to the example itself, but leaving off the very
first word of each.  For example, you can tell `specl` to check the
first two examples, named `module group one passes` and `module group
one hasn't decided yet` like this:

{% highlight bash %}
    specl --example 'group one'
{% endhighlight %}

[Specl] will run all examples that match any one (or more) of the
`--example` (or `-e`) arguments you give it.  Those arguments are
interpreted as [Lua patterns], so you must be careful to escape any
pattern meta-characters with an additional `%` (percent) character.
Other than that, each argument is matched against the concatenated
description path leading to each example with respect to pattern anchors
and the like, so you could include the final example in addition to the
first group selected above as follows:

{% highlight bash %}
    specl --e 'group one' -e '%w+%s*again$'
{% endhighlight %}

When invoked with `--verbose`, the `progress` and `report` formatters
display pending and failing examples with a `filename:NN:EE` prefix;
where `filename` is the name of the spec file containing the non-passing
example, `NN` is the line-number of the first line of the non-passing
example in that file, and `EE` is the ordinal expectation within that
example.  If you need to recheck just that example, you can cut and
paste the `filename:NN:EE` directly into your next `specl` invocation:

{% highlight bash %}
    specl specs/foo_spec.yaml:44:1
{% endhighlight %}

Actually, the final `:EE` is always ignored, because there's no way
for [Specl] to tell what parts of the [Lua] code in a given example
are relevant to one `expect` statement or another, so it always checks
the entire example.  You can omit the `:EE` when you type at the command
line too.

If you want to check more than a single non-passing example, without
rechecking all of the specifications in a given file, [Specl] also
accepts `+` prefixed line numbers prior to the file name argument:

{% highlight bash %}
    specl +44 +48 specs/foo_spec.yaml
{% endhighlight %}


### 5.2. Formatting Results

If you prefer to format the results of your specification examples with
a custom formatter, you should make sure your formatter is visible on
`LUA_PATH`, and use the `--formatter=BASENAME` option to load it.

Note that, for security reasons, Specl removes the current directory
from the system search path, so if you want to load a formatter in the
current directory, you will need to explicitly re-enable loading Lua
code from the current directory:

{% highlight bash %}
    LUA_PATH=`pwd`'/?.lua;;' specl --formatter=awesome
{% endhighlight %}

Otherwise you can load a formatter from the existing `LUA_PATH` by
name, including built in formatters, like this:

{% highlight bash %}
    specl --formatter=tap
{% endhighlight %}

Pass the `--help` option for help and brief documentation on usage of the
remaining available options.


## 6. Writing Program Specifications

In addition to writing example code to specify the behaviour of [Lua]
objects and modules, [Specl] is extremely useful for specifying the
behaviour of other command-line programs.  In fact, [Specl] has a
growing collection of specifications for itself in the form of
spec-files!


### 6.1. Shell Commands

When a program can be executed from the shell, [Specl] provides the
`specl.shell` module for running the program with specified options,
arguments and standard input, and capturing the exit status and standard
output and error streams.

To use this module in your specifications you must require it, either in
a `spec_helper.lua` file, or directly in the spec-file:

{% highlight lua %}
    shell = require "specl.shell"
{% endhighlight %}


#### 6.1.1. shell.spawn

This function constructs a `Command` object from it's parameters and
then executes it using Lua's `io.popen` function.  When called with a
string, that string is the shell command that will be executed by
`io.popen`:

{% highlight lua %}
    shell.spawn "echo foo"
{% endhighlight %}

Unfortunately, `io.popen` returns only the process output end of the
command pipeline, so `spawn` (ab)uses shell redirections and temporary
files to provide input, and collect output from the `Command`.  If you
try to call `spawn` with a string that has its own redirections, that
might defeat the redirections added by `spawn`, with unspecified results.
In practice, this doesn't seem to be a real limitation.  If it turns out
that this implementation has problems, then a future release of [Specl]
will use [luaposix] or [alien] for finer control over the `Command`
pipeline creation process.

Alternatively, `spawn` accepts a command specification table with the
command words in the array part of the table, with optional standard
input at `stdin` and environment variable settings in `env`:

{% highlight lua %}
    shell.spawn {
      "cat", "$FOO",
      stdin = "foo",
      env   = { FOO = "-" },
    }
{% endhighlight %}

Calling `spawn` in this example first sets `FOO` to `-` in the shell
environment of the `Command` object, and primes standard input with the
text `foo`, ultimately executing `cat -`, which then copies standard
input (`foo`) to standard output.

The result of a successful execution of a `Command` object is a
`Process` object that can be compared against expectations using any of
the following matchers.

If `expect` does not contain a `Process` object (either from a call to
`spawn` or otherwise), when using these matchers, [Specl] will raise an
error reporting what type was received instead.

#### 6.1.2. exit

This matcher succeeds when the `Process` captured by `expect` has the
given exit status:

{% highlight lua %}
    expect (shell.spawn "exit 42").to_exit (42)
{% endhighlight %}

Naturally, the expectation fails if the exit status does not match.

#### 6.1.3. succeed

Often, specifying an exact exit status is not as clear as determining
whether the `Process` exited normally or not:

{% highlight lua %}
    expect (shell.spawn "true").to_succeed ()
{% endhighlight %}

This is exactly equivalent to:

{% highlight lua %}
    expect (shell.spawn "true").to_exit (0)
{% endhighlight %}

This matcher fails if the exit status is non-zero.

#### 6.1.4. fail

Conversely, it's often useful to determine that the `Process` exited
abnormally in an expectation:

{% highlight lua %}
    expect (shell.spawn "false").to_fail ()
{% endhighlight %}

This is entirely equivalent to:

{% highlight lua %}
    expect (shell.spawn "false").not_to_exit (0)
{% endhighlight %}

This matcher fails only when the exit status is zero.

#### 6.1.5. output

Of course, you won't get very far when all you can specify is the exit
status of a `Process`.  This matcher is for specifying the entire
standard output a `Process` should write throughout its execution:

{% highlight lua %}
    expect (shell.spawn "printf hello").to_output "hello"
{% endhighlight %}

#### 6.1.6. contain_output

Where the `output` matcher works with `Process` output in a similar
way to how the [`be`](#be) matcher works with raw strings, this
`contain_output` matcher is equivalent to [`contain`](#contain):

{% highlight lua %}
    expect (shell.spawn "cat /etc/passwd").to_contain_output "root"
{% endhighlight %}

#### 6.1.7. match_output

Where the `contain_output` matcher works with `Process` output in a
similar way to how the [`contain`](#contain) matcher works with raw
strings, this `match_output` matcher is equivalent to
[`match`](#match):

{% highlight lua %}
    expect (shell.spawn "echo $RANDOM").to_match_output "%d+"
{% endhighlight %}

#### 6.1.8. succeed_with

This matcher checks both that program exits normally, **and** that the
`Process` outputs exactly the given text:

{% highlight lua %}
    expect (shell.spawn "printf hello").to_succeed_with "hello"
{% endhighlight %}

Conversely, `succeed_with` will fail if either the output differs, or
the `Process` exits abnormally.

#### 6.1.9. succeed_while_containing

Similarly, you can check that the program exited normally, **and** that
the `Process` contains the given text as a substring:

{% highlight lua %}
    expect (shell.spawn "cat /etc/hosts").
      to_succeed_while_containing "localhost"
{% endhighlight %}

If the `Process` exited abnormally, or the given text is not found
anywhere in its output, then `succeed_while_containing` fails.

#### 6.1.10. succeed_while_matching

You can also check that the program exited normally, **and** that the
`Process` output matches the given [Lua] pattern with
`succeed_while_matching`.

{% highlight lua %}
    expect (shell.spawn "echo $RANDOM").
      to_succeed_while_matching "%d+"
{% endhighlight %}

#### 6.1.11. output_error

Although it is useful to write specifications that check for expected
`Process` output and exit status, you may have noticed that when those
matchers fail, they will also show the content of standard error (if
any).

When you need to properly specify the content of standard error, use
this matcher:

{% highlight lua %}
    expect (shell.spawn "rspec").
      to_output_error "sh: rspec: command not found"
{% endhighlight %}

#### 6.1.12. contain_error

Note that [the previous example](#output_error) is likely to fail
unexpectedly whenever `/bin/sh` outputs a different error message
prefix, or if the error message text itself is slightly different on
the host machine, or on a system with internationalised messages etc.

Much like [`contain_output`](#contain_output), you can specify a
substring to find in standard error with:

{% highlight lua %}
    expect (shell.spawn "rspec").to_contain_error "sh: rspec: "
{% endhighlight %}

#### 6.1.13. match_error

Or similarly with [Lua] patterns using the `match_error` matcher:

{% highlight lua %}
    expect (shell.spawn "rspec").to_match_error "^[%w/]+: rspec: "
{% endhighlight %}

#### 6.1.14. fail_with

When you need to ensure that the `Process` exited abnormally, in
addition to producing exactly the given error output:

{% highlight lua %}
    expect (shell.spawn "rspec").
      to_fail_with "sh: rspec: command not found"
{% endhighlight %}

#### 6.1.15. fail_while_containing

Or specifying a substring in addition to the abnormal exit:

{% highlight lua %}
    expect (shell.spawn "rspec").
      to_fail_while_containing "sh: rspec: "
{% endhighlight %}

#### 6.1.16. fail_while_matching

Or more precisely still, an abnormal exit **and** a standard error that
matches the given [Lua] pattern:

{% highlight lua %}
    expect (shell.spawn "rspec").
      to_fail_while_matching "^[%w/]+: rspec: "
{% endhighlight %}

## 7. Not Yet Implemented

No support for mocks in the current version.


[alien]:    http://github.com/mascarenhas/alien
[bdd]:      http://en.wikipedia.org/wiki/Behavior-driven_development
[lua]:      http://www.lua.org
[luaposix]: http://github.com/luaposix/luaposix
[rspec]:    http://github.com/rspec/rspec
[specl]:    http://github.com/gvvaughan/specl
[yaml]:     http//yaml.org
[lua patterns]: http://www.lua.org/manual/5.2/manual.html#6.4.1
