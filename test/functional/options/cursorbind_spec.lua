local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local clear = n.clear
local command = n.command
local exec = n.exec
local feed = n.feed
local fn = n.fn

before_each(clear)

describe("'cursorbind'", function()
  -- oldtest: Test_cursorline_cursorbind_horizontal_scroll()
  it("behaves consistently whether 'cursorline' is set or not vim-patch:8.2.4795", function()
    local screen = Screen.new(60, 8)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [2] = { bold = true, reverse = true }, -- StatusLine
      [3] = { reverse = true }, -- StatusLineNC
      [4] = { background = Screen.colors.Grey90 }, -- CursorLine, CursorColumn
    })
    exec([[
      call setline(1, 'aa bb cc dd ee ff gg hh ii jj kk ll mm' ..
      \ ' nn oo pp qq rr ss tt uu vv ww xx yy zz')
      set nowrap
      " The following makes the cursor apparent on the screen dump
      set sidescroll=1 cursorcolumn
      " add empty lines, required for cursorcolumn
      call append(1, ['','','',''])
      20vsp
      windo :set cursorbind
    ]])
    feed('20l')
    screen:expect([[
      a bb cc dd ee ff gg │aa bb cc dd ee ff gg^ hh ii jj kk ll mm |
                         {4: }│                    {4: }                  |*4
      {1:~                   }│{1:~                                      }|
      {3:[No Name] [+]        }{2:[No Name] [+]                          }|
                                                                  |
    ]])
    feed('10l')
    screen:expect([[
       hh ii jj kk ll mm n│aa bb cc dd ee ff gg hh ii jj ^kk ll mm |
                {4: }         │                              {4: }        |*4
      {1:~                   }│{1:~                                      }|
      {3:[No Name] [+]        }{2:[No Name] [+]                          }|
                                                                  |
    ]])
    command('windo :set cursorline')
    feed('0')
    feed('20l')
    screen:expect([[
      {4:a bb cc dd ee ff gg }│{4:aa bb cc dd ee ff gg^ hh ii jj kk ll mm }|
                         {4: }│                    {4: }                  |*4
      {1:~                   }│{1:~                                      }|
      {3:[No Name] [+]        }{2:[No Name] [+]                          }|
                                                                  |
    ]])
    feed('10l')
    screen:expect([[
      {4: hh ii jj kk ll mm n}│{4:aa bb cc dd ee ff gg hh ii jj ^kk ll mm }|
                {4: }         │                              {4: }        |*4
      {1:~                   }│{1:~                                      }|
      {3:[No Name] [+]        }{2:[No Name] [+]                          }|
                                                                  |
    ]])
    command('windo :set nocursorline nocursorcolumn')
    feed('0')
    feed('40l')
    screen:expect([[
      kk ll mm nn oo pp qq│ bb cc dd ee ff gg hh ii jj kk ll mm n^n|
                          │                                       |*4
      {1:~                   }│{1:~                                      }|
      {3:[No Name] [+]        }{2:[No Name] [+]                          }|
                                                                  |
    ]])
  end)

  it('resyncs the other diff window when undo changes the diff #41250', function()
    exec([[
      set diffopt+=linematch:60
      call setline(1, ['C11', 'C12', 'C31', 'C32'])
      diffthis
      let g:w1 = win_getid()
      vnew
      call setline(1, ['C21', 'C22', 'A21', 'A22', 'C41', 'C42'])
      diffthis
      let g:w2 = win_getid()
      windo set cursorbind
      call win_gotoid(g:w1)
    ]])

    local function other_line()
      return fn.trim(fn.win_execute(fn.eval('g:w2'), 'echo getline(".")'))
    end

    eq('C11', fn.getline('.'))
    eq('C21', other_line())

    feed('2dd')
    eq('C31', fn.getline('.'))

    feed('jk')
    eq('C41', other_line())

    -- Undo restores the deleted lines and puts the cursor back on line 1, the
    -- same position it was memoised at, so the other window used to stay put.
    feed('u')
    eq('C11', fn.getline('.'))
    eq('C21', other_line())
  end)
end)
