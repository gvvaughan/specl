--[[ Fake specs ]]--

{["describe specl"] = {
  {["it should make a tree"] = function ()
    expect (true).should_not_equal (false)
  end},

  {["describe when nesting contexts"] = {
    {["it should create a branch"] = function ()
        expect ({ "sample" }).should_not_be ({ "sample" })
    end},

    {["it should create more branches"] = function ()
        expect ({ "sample" }).should_equal ({ "sample" })
    end},
  }},

  {["it should have two leaves"] = function ()
    expect ("English Language").should_contain ("e")
  end},
}}
