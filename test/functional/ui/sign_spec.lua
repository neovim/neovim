local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local api, clear, eq = n.api, n.clear, t.eq
local eval, exec, feed = n.eval, n.exec, n.feed

describe('Signs', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = 255 },
      [1] = { background = Screen.colors.Yellow },
      [2] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Grey },
      [3] = { background = Screen.colors.Gray90 },
      [4] = { bold = true, reverse = true },
      [5] = { reverse = true },
      [6] = { foreground = Screen.colors.Brown },
      [7] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
      [8] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [9] = { bold = true, foreground = Screen.colors.Magenta },
      [10] = { foreground = Screen.colors.Blue1 },
      [11] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    })
  end)

  describe(':sign place', function()
    it('allows signs with combining characters', function()
      feed('ia<cr>b<cr><esc>')
      exec([[
        sign define piet1 text=𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄ texthl=Search
        sign define piet2 text=𠜎̀́̂̃̄̅ texthl=Search
        sign place 1 line=1 name=piet1 buffer=1
        sign place 2 line=2 name=piet2 buffer=1
      ]])
      screen:expect([[
        {1:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}a                                                  |
        {1:𠜎̀́̂̃̄̅}b                                                  |
        {2:  }^                                                   |
        {0:~                                                    }|*10
                                                             |
      ]])
    end)

    it('shadows previously placed signs', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec([[
        sign define piet text=>> texthl=Search
        sign define pietx text=>! texthl=Search
        sign place 1 line=1 name=piet buffer=1
        sign place 2 line=3 name=piet buffer=1
        sign place 3 line=1 name=pietx buffer=1
      ]])
      screen:expect([[
        {1:>!}a                                                  |
        {2:  }b                                                  |
        {1:>>}c                                                  |
        {2:  }^                                                   |
        {0:~                                                    }|*9
                                                             |
      ]])
    end)

    it('allows signs with no text', function()
      feed('ia<cr>b<cr><esc>')
      exec('sign define piet1 text= texthl=Search')
      exec('sign place 1 line=1 name=piet1 buffer=1')
      screen:expect([[
        a                                                    |
        b                                                    |
        ^                                                     |
        {0:~                                                    }|*10
                                                             |
      ]])
    end)

    it('can be called right after :split', function()
      feed('ia<cr>b<cr>c<cr><esc>gg')
      -- This used to cause a crash due to :sign using a special redraw
      -- (not updating nvim's specific highlight data structures)
      -- without proper redraw first, as split just flags for redraw later.
      exec([[
        set cursorline
        sign define piet text=>> texthl=Search
        split
        sign place 3 line=2 name=piet buffer=1
      ]])
      screen:expect([[
        {2:  }{3:^a                                                  }|
        {1:>>}b                                                  |
        {2:  }c                                                  |
        {2:  }                                                   |
        {0:~                                                    }|*2
        {4:[No Name] [+]                                        }|
        {2:  }{3:a                                                  }|
        {1:>>}b                                                  |
        {2:  }c                                                  |
        {2:  }                                                   |
        {0:~                                                    }|
        {5:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('can combine text, linehl and numhl', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec([[
        set number
        sign define piet text=>> texthl=Search
        sign define pietx linehl=ErrorMsg
        sign define pietxx numhl=Folded
        sign place 1 line=1 name=piet buffer=1
        sign place 2 line=2 name=pietx buffer=1
        sign place 3 line=3 name=pietxx buffer=1
        sign place 4 line=4 name=piet buffer=1
        sign place 5 line=4 name=pietx buffer=1
        sign place 6 line=4 name=pietxx buffer=1
      ]])
      screen:expect([[
        {1:>>}{6:  1 }a                                              |
        {2:  }{6:  2 }{8:b                                              }|
        {2:  }{7:  3 }c                                              |
        {1:>>}{7:  4 }{8:^                                               }|
        {0:~                                                    }|*9
                                                             |
      ]])
      -- Check that 'statuscolumn' correctly applies numhl
      exec('set statuscolumn=%s%=%l\\ ')
      screen:expect_unchanged()
    end)

    it('highlights the cursorline sign with culhl', function()
      feed('ia<cr>b<cr>c<esc>')
      exec([[
        sign define piet text=>> texthl=Search culhl=ErrorMsg
        sign place 1 line=1 name=piet buffer=1
        sign place 2 line=2 name=piet buffer=1
        sign place 3 line=3 name=piet buffer=1
        set cursorline
      ]])
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}b                                                  |
        {8:>>}{3:^c                                                  }|
        {0:~                                                    }|*10
                                                             |
      ]])
      feed('k')
      screen:expect([[
        {1:>>}a                                                  |
        {8:>>}{3:^b                                                  }|
        {1:>>}c                                                  |
        {0:~                                                    }|*10
                                                             |
      ]])
      exec('set nocursorline')
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}^b                                                  |
        {1:>>}c                                                  |
        {0:~                                                    }|*10
                                                             |
      ]])
      exec('set cursorline cursorlineopt=line')
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}{3:^b                                                  }|
        {1:>>}c                                                  |
        {0:~                                                    }|*10
                                                             |
      ]])
      exec('set cursorlineopt=number')
      exec('hi! link SignColumn IncSearch')
      feed('Go<esc>2G')
      screen:expect([[
        {1:>>}a                                                  |
        {8:>>}^b                                                  |
        {1:>>}c                                                  |
        {5:  }                                                   |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- Check that 'statuscolumn' cursorline/signcolumn highlights are the same (#21726)
      exec('set statuscolumn=%s')
      screen:expect_unchanged()
    end)

    it('multiple signs #9295', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec([[
        set number
        set signcolumn=yes:2
        sign define pietSearch text=>> texthl=Search
        sign define pietError text=XX texthl=Error
        sign define pietWarn text=WW texthl=Warning
        sign place 6 line=3 name=pietSearch buffer=1
        sign place 7 line=3 name=pietWarn buffer=1
        sign place 5 line=3 name=pietError buffer=1
      ]])
      -- Line 3 checks that with a limit over the maximum number
      -- of signs, the ones with the highest Ids are being picked,
      -- and presented by their sorted Id order.
      screen:expect([[
        {2:    }{6:  1 }a                                            |
        {2:    }{6:  2 }b                                            |
        WW{1:>>}{6:  3 }c                                            |
        {2:    }{6:  4 }^                                             |
        {0:~                                                    }|*9
                                                             |
      ]])
      exec([[
        sign place 1 line=1 name=pietSearch buffer=1
        sign place 2 line=1 name=pietError buffer=1
        " Line 2 helps checking that signs in the same line are ordered by Id.
        sign place 4 line=2 name=pietSearch buffer=1
        sign place 3 line=2 name=pietError buffer=1
      ]])
      screen:expect([[
        {8:XX}{1:>>}{6:  1 }a                                            |
        {1:>>}{8:XX}{6:  2 }b                                            |
        WW{1:>>}{6:  3 }c                                            |
        {2:    }{6:  4 }^                                             |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- With the default setting, we get the sign with the top id.
      exec('set signcolumn=yes:1')
      screen:expect([[
        {8:XX}{6:  1 }a                                              |
        {1:>>}{6:  2 }b                                              |
        WW{6:  3 }c                                              |
        {2:  }{6:  4 }^                                               |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- "auto:3" accommodates all the signs we defined so far.
      exec('set signcolumn=auto:3')
      local s3 = [[
        {8:XX}{1:>>}{2:  }{6:  1 }a                                          |
        {1:>>}{8:XX}{2:  }{6:  2 }b                                          |
        WW{1:>>}{8:XX}{6:  3 }c                                          |
        {2:      }{6:  4 }^                                           |
        {0:~                                                    }|*9
                                                             |
      ]]
      screen:expect(s3)
      -- Check "yes:9".
      exec('set signcolumn=yes:9')
      screen:expect([[
        {8:XX}{1:>>}{2:              }{6:  1 }a                              |
        {1:>>}{8:XX}{2:              }{6:  2 }b                              |
        WW{1:>>}{8:XX}{2:            }{6:  3 }c                              |
        {2:                  }{6:  4 }^                               |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- Check "auto:N" larger than the maximum number of signs defined in
      -- a single line (same result as "auto:3").
      exec('set signcolumn=auto:4')
      screen:expect(s3)
      -- line deletion deletes signs.
      exec('3move1')
      exec('2d')
      screen:expect([[
        {8:XX}{1:>>}{6:  1 }a                                            |
        {1:>>}{8:XX}{6:  2 }^b                                            |
        {2:    }{6:  3 }                                             |
        {0:~                                                    }|*10
                                                             |
      ]])
      -- character deletion does not delete signs.
      feed('x')
      screen:expect([[
        {8:XX}{1:>>}{6:  1 }a                                            |
        {1:>>}{8:XX}{6:  2 }^                                             |
        {2:    }{6:  3 }                                             |
        {0:~                                                    }|*10
                                                             |
      ]])
    end)

    it('auto-resize sign column with minimum size (#13783)', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec('set number')
      -- sign column should always accommodate at the minimum size
      exec('set signcolumn=auto:1-3')
      screen:expect([[
        {2:  }{6:  1 }a                                              |
        {2:  }{6:  2 }b                                              |
        {2:  }{6:  3 }c                                              |
        {2:  }{6:  4 }^                                               |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- should support up to 8 signs at minimum
      exec('set signcolumn=auto:8-9')
      screen:expect([[
        {2:                }{6:  1 }a                                |
        {2:                }{6:  2 }b                                |
        {2:                }{6:  3 }c                                |
        {2:                }{6:  4 }^                                 |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- should keep the same sign size when signs are not exceeding
      -- the minimum
      exec('set signcolumn=auto:2-5')
      exec('sign define pietSearch text=>> texthl=Search')
      exec('sign place 1 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>}{2:  }{6:  1 }a                                            |
        {2:    }{6:  2 }b                                            |
        {2:    }{6:  3 }c                                            |
        {2:    }{6:  4 }^                                             |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- should resize itself when signs are exceeding minimum but
      -- not over the maximum
      exec([[
        sign place 2 line=1 name=pietSearch buffer=1
        sign place 3 line=1 name=pietSearch buffer=1
        sign place 4 line=1 name=pietSearch buffer=1
      ]])
      screen:expect([[
        {1:>>>>>>>>}{6:  1 }a                                        |
        {2:        }{6:  2 }b                                        |
        {2:        }{6:  3 }c                                        |
        {2:        }{6:  4 }^                                         |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- should not increase size because sign with existing id is moved
      exec('sign place 4 line=1 name=pietSearch buffer=1')
      screen:expect_unchanged()
      exec('sign unplace 4')
      screen:expect([[
        {1:>>>>>>}{6:  1 }a                                          |
        {2:      }{6:  2 }b                                          |
        {2:      }{6:  3 }c                                          |
        {2:      }{6:  4 }^                                           |
        {0:~                                                    }|*9
                                                             |
      ]])
      exec('sign place 4 line=1 name=pietSearch buffer=1')
      -- should keep the column at maximum size when signs are
      -- exceeding the maximum
      exec([[
        sign place 5 line=1 name=pietSearch buffer=1
        sign place 6 line=1 name=pietSearch buffer=1
        sign place 7 line=1 name=pietSearch buffer=1
        sign place 8 line=1 name=pietSearch buffer=1
      ]])
      screen:expect([[
        {1:>>>>>>>>>>}{6:  1 }a                                      |
        {2:          }{6:  2 }b                                      |
        {2:          }{6:  3 }c                                      |
        {2:          }{6:  4 }^                                       |
        {0:~                                                    }|*9
                                                             |
      ]])
    end)

    it('ignores signs with no icon and text when calculating the signcolumn width', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec([[
        set number
        set signcolumn=auto:2
        sign define pietSearch text=>> texthl=Search
        sign define pietError text= texthl=Error
        sign place 2 line=1 name=pietError buffer=1
      ]])
      -- no signcolumn with only empty sign
      screen:expect([[
        {6:  1 }a                                                |
        {6:  2 }b                                                |
        {6:  3 }c                                                |
        {6:  4 }^                                                 |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- single column with 1 sign with text and one sign without
      exec('sign place 1 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>}{6:  1 }a                                              |
        {2:  }{6:  2 }b                                              |
        {2:  }{6:  3 }c                                              |
        {2:  }{6:  4 }^                                               |
        {0:~                                                    }|*9
                                                             |
      ]])
    end)

    it('signcolumn=number', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      exec([[
        set number signcolumn=number
        sign define pietSearch text=>> texthl=Search numhl=Error
        sign define pietError text=    texthl=Search numhl=Error
        sign place 1 line=1 name=pietSearch buffer=1
        sign place 2 line=2 name=pietError  buffer=1
      ]])
      -- line number should be drawn if sign has no text
      -- no signcolumn, line number for "a" is Search, for "b" is Error, for "c" is LineNr
      screen:expect([[
        {1: >> }a                                                |
        {8:  2 }b                                                |
        {6:  3 }c                                                |
        {6:  4 }^                                                 |
        {0:~                                                    }|*9
                                                             |
      ]])
      -- number column on wrapped part of a line should be empty
      feed('gg100aa<Esc>')
      screen:expect([[
        {1: >> }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        {8:    }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        {8:    }aa^a                                              |
        {8:  2 }b                                                |
        {6:  3 }c                                                |
        {6:  4 }                                                 |
        {0:~                                                    }|*7
                                                             |
      ]])
      api.nvim_buf_set_extmark(0, api.nvim_create_namespace('test'), 0, 0, {
        virt_lines = { { { 'VIRT LINES' } } },
        virt_lines_above = true,
      })
      feed('<C-Y>')
      -- number column on virtual lines should be empty
      screen:expect([[
        {6:    }VIRT LINES                                       |
        {1: >> }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        {8:    }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        {8:    }aa^a                                              |
        {8:  2 }b                                                |
        {6:  3 }c                                                |
        {6:  4 }                                                 |
        {0:~                                                    }|*6
                                                             |
      ]])
    end)

    it('can have 32bit sign IDs', function()
      exec('sign define piet text=>> texthl=Search')
      exec('sign place 100000 line=1 name=piet buffer=1')
      feed(':sign place<cr>')
      screen:expect([[
        {1:>>}                                                   |
        {0:~                                                    }|*6
        {4:                                                     }|
        :sign place                                          |
        {9:--- Signs ---}                                        |
        {10:Signs for [NULL]:}                                    |
            line=1  id=100000  name=piet  priority=10        |
                                                             |
        {11:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {1:>>}^                                                   |
        {0:~                                                    }|*12
                                                             |
      ]])
    end)
  end)

  it('signcolumn width is updated when removing all signs after deleting lines', function()
    api.nvim_buf_set_lines(0, 0, 1, true, { 'a', 'b', 'c', 'd', 'e' })
    exec('sign define piet text=>>')
    exec('sign place 10001 line=1 name=piet')
    exec('sign place 10002 line=5 name=piet')
    exec('2delete')
    exec('sign unplace 10001')
    screen:expect([[
      {2:  }a                                                  |
      {2:  }^c                                                  |
      {2:  }d                                                  |
      >>e                                                  |
      {0:~                                                    }|*9
                                                           |
    ]])
    exec('sign unplace 10002')
    screen:expect([[
      a                                                    |
      ^c                                                    |
      d                                                    |
      e                                                    |
      {0:~                                                    }|*9
                                                           |
    ]])
  end)

  it('signcolumn width is updated when removing all signs after inserting lines', function()
    api.nvim_buf_set_lines(0, 0, 1, true, { 'a', 'b', 'c', 'd', 'e' })
    exec('sign define piet text=>>')
    exec('sign place 10001 line=1 name=piet')
    exec('sign place 10002 line=5 name=piet')
    exec('copy .')
    exec('sign unplace 10001')
    screen:expect([[
      {2:  }a                                                  |
      {2:  }^a                                                  |
      {2:  }b                                                  |
      {2:  }c                                                  |
      {2:  }d                                                  |
      >>e                                                  |
      {0:~                                                    }|*7
                                                           |
    ]])
    exec('sign unplace 10002')
    screen:expect([[
      a                                                    |
      ^a                                                    |
      b                                                    |
      c                                                    |
      d                                                    |
      e                                                    |
      {0:~                                                    }|*7
                                                           |
    ]])
  end)

  it('numhl highlight is applied when signcolumn=no', function()
    screen:try_resize(screen._width, 4)
    exec([[
      set nu scl=no
      call setline(1, ['line1', 'line2', 'line3'])
      call nvim_buf_set_extmark(0, nvim_create_namespace('test'), 0, 0, {'number_hl_group':'Error'})
      call sign_define('foo', { 'text':'F', 'numhl':'Error' })
      call sign_place(0, '', 'foo', bufnr(''), { 'lnum':2 })
    ]])
    screen:expect([[
      {8:  1 }^line1                                            |
      {8:  2 }line2                                            |
      {6:  3 }line3                                            |
                                                           |
    ]])
  end)

  it('no negative b_signcols.count with undo after initializing', function()
    exec([[
      set signcolumn=auto:2
      call setline(1, 'a')
      call nvim_buf_set_extmark(0, nvim_create_namespace(''), 0, 0, {'sign_text':'S1'})
      delete | redraw | undo
    ]])
  end)

  it('sign not shown on line it was previously on after undo', function()
    exec([[
      call setline(1, range(1, 4))
      call nvim_buf_set_extmark(0, nvim_create_namespace(''), 1, 0, {'sign_text':'S1'})
    ]])
    exec('norm 2Gdd')
    exec('silent undo')
    screen:expect([[
      {2:  }1                                                  |
      S1^2                                                  |
      {2:  }3                                                  |
      {2:  }4                                                  |
      {0:~                                                    }|*9
                                                           |
    ]])
  end)

  it('sign_undefine() frees all signs', function()
    exec([[
      sign define 1 text=1
      sign define 2 text=2
      call sign_undefine()
    ]])
    eq({}, eval('sign_getdefined()'))
  end)
end)
