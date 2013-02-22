{["describe matchers"] = {
  before = function ()
    specl = require "specl"
  end,

  {["describe the contain matcher"] = {
    {["context when expect receives a string"] = {
      {["it compares against the expectation"] = function ()
        expect ("English Language").should_contain "e"
	expect ("English Language").should_not_contain "~"
      end},
    }},
    {["context when expect receives a table"] = {
      {["it compares elements against the expectation"] = function ()
        expect ({ "one", "two", "five" }).should_contain "five"
        expect ({ "one", "two", "five" }).should_not_contain "three"
      end},
      {["it compares keys against the expectation"] = function ()
        expect ({ one = true, two = true, five = true }).should_contain "five"
        expect ({ one = true, two = true, five = true }).should_not_contain "three"
      end},
      {["it makes a deep comparison of non-string elements"] = function ()
        expect ({{ "subtable one" }, { "subtable two" }}).should_contain { "subtable one" }
        expect ({{ "subtable one" }, { "subtable two" }}).should_not_contain "subtable one"
      end},
    }},
  }},
}}
