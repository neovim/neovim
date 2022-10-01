local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec

before_each(clear)

describe('matchaddpos()', function()
  -- oldtest: Test_matchaddpos_dump()
  it('can add more than 8 match positions vim-patch:9.0.0620', function()
    local screen = Screen.new(60, 14)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {background = Screen.colors.Yellow},  -- Search
    })
    screen:attach()
    exec([[
      call setline(1, ['1234567890123']->repeat(14))
      call matchaddpos('Search', range(1, 12)->map({i, v -> [v, v]}))
    ]])
    screen:expect([[
      {1:^1}234567890123                                               |
      1{1:2}34567890123                                               |
      12{1:3}4567890123                                               |
      123{1:4}567890123                                               |
      1234{1:5}67890123                                               |
      12345{1:6}7890123                                               |
      123456{1:7}890123                                               |
      1234567{1:8}90123                                               |
      12345678{1:9}0123                                               |
      123456789{1:0}123                                               |
      1234567890{1:1}23                                               |
      12345678901{1:2}3                                               |
      1234567890123                                               |
                                                                  |
    ]])
  end)
end)
