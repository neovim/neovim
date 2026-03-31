local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local exec = n.exec
local feed = n.feed

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
end)
