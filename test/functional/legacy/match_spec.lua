local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed

before_each(clear)

describe('matchaddpos()', function()
  -- oldtest: Test_matchaddpos_dump()
  it('can add more than 8 match positions vim-patch:9.0.0620', function()
    local screen = Screen.new(60, 14)
    exec([[
      call setline(1, ['1234567890123']->repeat(14))
      call matchaddpos('Search', range(1, 12)->map({i, v -> [v, v]}))
    ]])
    screen:expect([[
      {10:^1}234567890123                                               |
      1{10:2}34567890123                                               |
      12{10:3}4567890123                                               |
      123{10:4}567890123                                               |
      1234{10:5}67890123                                               |
      12345{10:6}7890123                                               |
      123456{10:7}890123                                               |
      1234567{10:8}90123                                               |
      12345678{10:9}0123                                               |
      123456789{10:0}123                                               |
      1234567890{10:1}23                                               |
      12345678901{10:2}3                                               |
      1234567890123                                               |
                                                                  |
    ]])
  end)
end)

describe('match highlighting', function()
  -- oldtest: Test_match_in_linebreak()
  it('does not continue in linebreak vim-patch:8.2.3698', function()
    local screen = Screen.new(75, 10)
    exec([=[
      set breakindent linebreak breakat+=]
      call printf('%s]%s', repeat('x', 50), repeat('x', 70))->setline(1)
      call matchaddpos('ErrorMsg', [[1, 51]])
    ]=])
    screen:expect([[
      ^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx{9:]}                        |
      xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx     |
      {1:~                                                                          }|*7
                                                                                 |
    ]])
  end)

  it('is shown with incsearch vim-patch:8.2.3940', function()
    local screen = Screen.new(75, 6)
    exec([[
      set incsearch
      call setline(1, range(20))
      call matchaddpos('ErrorMsg', [3])
    ]])
    screen:expect([[
      ^0                                                                          |
      1                                                                          |
      {9:2}                                                                          |
      3                                                                          |
      4                                                                          |
                                                                                 |
    ]])
    feed(':s/0')
    screen:expect([[
      {10:0}                                                                          |
      1                                                                          |
      {9:2}                                                                          |
      3                                                                          |
      4                                                                          |
      :s/0^                                                                       |
    ]])
  end)

  it('on a Tab vim-patch:8.2.4062', function()
    local screen = Screen.new(75, 10)
    exec([[
      set linebreak
      call setline(1, "\tix")
      call matchadd('ErrorMsg', '\t')
    ]])
    screen:expect([[
      {9:       ^ }ix                                                                 |
      {1:~                                                                          }|*8
                                                                                 |
    ]])
  end)
end)
