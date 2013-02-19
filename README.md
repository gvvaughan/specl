# SPECL

A specification testing framework inspired by [RSpec]{rspec) for and
in [Lua][lua].

# WARNING

It's still very alpha, and hasn't yet been used for any real specs.
Essentially, you need to hack the code to make use of it at the moment,
but I'm making progress...

## Documentation

Specl uses the Lua parser to read the specifications, so the syntax is
not as pretty as it might be:

    specs = {
      {["describe specl"] = {
        before = function ()
          -- This runs before each element below.
        end,

        -- Every example runs in its own environment.
        {["it should make a tree"] = function ()
          expect (true).should_not_equal (false)
        end},

        -- Specs can be nested.
        {["describe when nesting contexts"] = {
          {["it should create a branch"] = function ()
              -- Use expect and various matchers to determine whether
              -- example code is behaving as expected.
              expect ({ "sample" }).should_not_be ({ "sample" })
          end},

          {["it should create more branches"] = function ()
              expect ({ "sample" }).should_equal ({ "sample" })
          end},
        }},

        {["it should have two leaves"] = function ()
          expect ("English Language").should_contain ("e")
        end},

        after = function ()
          -- this runs after each element above.
        end,
      }},
    }

No support for mocks, or pending examples in the current version.



[rspec]: http://github.com/rspec/rspec
[lua]: http://www.lua.org
