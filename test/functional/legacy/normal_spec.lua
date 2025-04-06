local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local api = n.api
local eq = t.eq
local fn = n.fn

describe('normal', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 19)
  end)

  -- oldtest: Test_normal_j_below_botline()
  it([[no skipped lines with "j" scrolling below botline and 'foldmethod' not "manual"]], function()
    exec([[
      set number foldmethod=diff scrolloff=0
      call setline(1, map(range(1, 9), 'repeat(v:val, 200)'))
      norm Lj
    ]])
    screen:expect([[
      {8:  2 }222222222222222222222222222222222222|
      {8:    }222222222222222222222222222222222222|*4
      {8:    }22222222222222222222                |
      {8:  3 }333333333333333333333333333333333333|
      {8:    }333333333333333333333333333333333333|*4
      {8:    }33333333333333333333                |
      {8:  4 }^444444444444444444444444444444444444|
      {8:    }444444444444444444444444444444444444|*4
      {8:    }44444444444444444444                |
                                              |
    ]])
  end)

  -- oldtest: Test_single_line_scroll()
  it('(Half)-page scroll up or down reveals virtual lines #19605, #27967', function()
    fn.setline(1, 'foobar one two three')
    exec('set smoothscroll')
    local ns = api.nvim_create_namespace('')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {
      virt_lines = { { { '---', 'IncSearch' } } },
      virt_lines_above = true,
    })
    -- Nvim: not actually necessary to scroll down to hide the virtual line.
    -- Check topfill instead of skipcol and show the screen state.
    feed('<C-E>')
    eq(0, fn.winsaveview().topfill)
    local s1 = [[
      ^foobar one two three                    |
      {1:~                                       }|*17
                                              |
    ]]
    screen:expect(s1)
    feed('<C-B>')
    eq(1, fn.winsaveview().topfill)
    local s2 = [[
      {2:---}                                     |
      ^foobar one two three                    |
      {1:~                                       }|*16
                                              |
    ]]
    screen:expect(s2)
    feed('<C-E>')
    eq(0, fn.winsaveview().topfill)
    screen:expect(s1)
    feed('<C-U>')
    eq(1, fn.winsaveview().topfill)
    screen:expect(s2)

    -- Nvim: also test virt_lines below the last line
    feed('yy100pG<C-L>')
    api.nvim_buf_set_extmark(0, ns, 100, 0, { virt_lines = { { { '---', 'IncSearch' } } } })
    screen:expect({
      grid = [[
        foobar one two three                    |*17
        ^foobar one two three                    |
                                                |
      ]],
    })
    feed('<C-F>')
    screen:expect({
      grid = [[
        ^foobar one two three                    |
        {2:---}                                     |
        {1:~                                       }|*16
                                                |
      ]],
    })
    feed('ggG<C-D>')
    screen:expect({
      grid = [[
        foobar one two three                    |*16
        ^foobar one two three                    |
        {2:---}                                     |
                                                |
      ]],
    })
  end)

  -- oldtest: Test_normal_gm()
  it('gm sets curswant correctly', function()
    screen:try_resize(75, 10)
    exec([[
      call setline(1, repeat(["  abcd\tefgh\tij"], 10))
      call cursor(1, 1)
    ]])
    feed('jVjzf')
    -- gm
    feed('gmk')
    eq(18, fn.virtcol('.'))
    -- g0
    feed('gj0k')
    eq(1, fn.virtcol('.'))
    -- g^
    feed('jg^k')
    eq(3, fn.virtcol('.'))
    exec('call cursor(10, 1)')
    -- gm
    feed('gmk')
    eq(18, fn.virtcol('.'))
    -- g0
    feed('gj0k')
    eq(1, fn.virtcol('.'))
    -- g^
    feed('jg^k')
    eq(3, fn.virtcol('.'))
  end)
end)
