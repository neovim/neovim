-- Test for scenarios involving 'spell'

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local insert = helpers.insert
local uname = helpers.uname
local command = helpers.command

describe("'spell'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(80, 8)
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {special = Screen.colors.Red, undercurl = true},
      [2] = {special = Screen.colors.Blue1, undercurl = true},
    })
  end)

  it('joins long lines #7937', function()
    if uname() == 'openbsd' then pending('FIXME #12104', function() end) return end
    command('set spell')
    insert([[
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
    consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
    cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat
    non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    ]])
    feed('ggJJJJJJ0')
    screen:expect([[
    {1:^Lorem} {1:ipsum} dolor sit {1:amet}, {1:consectetur} {1:adipiscing} {1:elit}, {1:sed} do {1:eiusmod} {1:tempor} {1:i}|
    {1:ncididunt} {1:ut} {1:labore} et {1:dolore} {1:magna} {1:aliqua}. {1:Ut} {1:enim} ad minim {1:veniam}, {1:quis} {1:nostru}|
    {1:d} {1:exercitation} {1:ullamco} {1:laboris} {1:nisi} {1:ut} {1:aliquip} ex ea {1:commodo} {1:consequat}. {1:Duis} {1:aut}|
    {1:e} {1:irure} dolor in {1:reprehenderit} in {1:voluptate} {1:velit} {1:esse} {1:cillum} {1:dolore} {1:eu} {1:fugiat} {1:n}|
    {1:ulla} {1:pariatur}. {1:Excepteur} {1:sint} {1:occaecat} {1:cupidatat} non {1:proident}, {1:sunt} in culpa {1:qui}|
     {1:officia} {1:deserunt} {1:mollit} {1:anim} id est {1:laborum}.                                   |
    {0:~                                                                               }|
                                                                                    |
    ]])

  end)

  it('has correct highlight at start of line', function()
    insert([[
    "This is some text without any spell errors.  Everything",
    "should just be black, nothing wrong here.",
    "",
    "This line has a sepll error. and missing caps.",
    "And and this is the the duplication.",
    "with missing caps here.",
    ]])
    command('set spell spelllang=en_nz')
    screen:expect([[
    "This is some text without any spell errors.  Everything",                      |
    "should just be black, nothing wrong here.",                                    |
    "",                                                                             |
    "This line has a {1:sepll} error. {2:and} missing caps.",                               |
    "{1:And and} this is {1:the the} duplication.",                                         |
    "with missing caps here.",                                                      |
    ^                                                                                |
                                                                                    |
      ]])
  end)
end)
