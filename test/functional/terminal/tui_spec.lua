-- Some sanity checks for the TUI using the builtin terminal emulator
-- as a simple way to send keys and assert screen state.
local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local feed = thelpers.feed_data
local execute = helpers.execute

describe('tui', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "--cmd", "set noswapfile"]')
    screen.timeout = 30000 -- pasting can be really slow in the TUI
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  it('accepts basic utf-8 input', function()
    feed('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b')
    screen:expect([[
      abc                                               |
      test1                                             |
      test{1:2}                                             |
      ~                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('automatically sends <Paste> for bracketed paste sequences', function()
    feed('i\x1b[200~')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('pasted from terminal')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[201~')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle arbitrarily long bursts of input', function()
    execute('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed('i\x1b[200~')
    feed(table.concat(t, '\n'))
    feed('\x1b[201~')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000{1: }                                        |
      [No Name] [+]                   3000,10        Bot|
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)
end)
