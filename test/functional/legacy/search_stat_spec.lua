local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, exec, command = helpers.clear, helpers.feed, helpers.exec, helpers.command
local poke_eventloop = helpers.poke_eventloop

describe('search stat', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(30, 10)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {background = Screen.colors.Yellow},  -- Search
      [3] = {foreground = Screen.colors.Blue4, background = Screen.colors.LightGrey},  -- Folded
    })
    screen:attach()
  end)

  it('right spacing with silent mapping vim-patch:8.1.1970', function()
    exec([[
      set shortmess-=S
      " Append 50 lines with text to search for, "foobar" appears 20 times
      call append(0, repeat(['foobar', 'foo', 'fooooobar', 'foba', 'foobar'], 20))
      call setline(2, 'find this')
      call setline(70, 'find this')
      nnoremap n n
      let @/ = 'find this'
      call cursor(1,1)
      norm n
    ]])
    screen:expect([[
      foobar                        |
      {2:^find this}                     |
      fooooobar                     |
      foba                          |
      foobar                        |
      foobar                        |
      foo                           |
      fooooobar                     |
      foba                          |
      /find this             [1/2]  |
    ]])
    command('nnoremap <silent> n n')
    feed('gg0n')
    screen:expect([[
      foobar                        |
      {2:^find this}                     |
      fooooobar                     |
      foba                          |
      foobar                        |
      foobar                        |
      foo                           |
      fooooobar                     |
      foba                          |
                             [1/2]  |
    ]])
  end)

  it('when only match is in fold vim-patch:8.2.0840', function()
    exec([[
      set shortmess-=S
      setl foldenable foldmethod=indent foldopen-=search
      call append(0, ['if', "\tfoo", "\tfoo", 'endif'])
      let @/ = 'foo'
      call cursor(1,1)
      norm n
    ]])
    screen:expect([[
      if                            |
      {3:^+--  2 lines: foo·············}|
      endif                         |
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      /foo                   [1/2]  |
    ]])
    feed('n')
    poke_eventloop()
    screen:expect_unchanged()
    feed('n')
    poke_eventloop()
    screen:expect_unchanged()
  end)

  it('is cleared by gd and gD vim-patch:8.2.3583', function()
    exec([[
      call setline(1, ['int cat;', 'int dog;', 'cat = dog;'])
      set shortmess-=S
      set hlsearch
    ]])
    feed('/dog<CR>')
    screen:expect([[
      int cat;                      |
      int {2:^dog};                      |
      cat = {2:dog};                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      /dog                   [1/2]  |
    ]])
    feed('G0gD')
    screen:expect([[
      int {2:^cat};                      |
      int dog;                      |
      {2:cat} = dog;                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]])
  end)
end)
