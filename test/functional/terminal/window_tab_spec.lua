local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local clear, eq, curbuf = helpers.clear, helpers.eq, helpers.curbuf
local feed, nvim = helpers.feed, helpers.nvim
local feed_data = thelpers.feed_data

describe('terminal', function()
  local screen

  before_each(function()
    clear()
    -- set the statusline to a constant value because of variables like pid
    -- and current directory and to improve visibility of splits
    nvim('set_option', 'statusline', '==========')
    nvim('command', 'highlight StatusLine cterm=NONE')
    nvim('command', 'highlight StatusLineNC cterm=NONE')
    nvim('command', 'highlight VertSplit cterm=NONE')

    -- based loosely on http://superuser.com/a/614424 with lots stripped out.
    -- Just shows tab numbers in the tabline, not names.
    nvim('command', [[function MyTabLine()
        let s = '' " complete tabline goes here
        " loop through each tab page
        for t in range(tabpagenr('$'))
                " set highlight
                if t + 1 == tabpagenr()
                        let s .= '%#TabLineSel#'
                else
                        let s .= '%#TabLine#'
                endif
                let s .= ' '
                " set page number string
                let s .= t + 1 . ' '
        endfor
        return s
        endfunction]])
    nvim('set_option', 'tabline', '%!MyTabLine()')
    screen = thelpers.screen_setup(3)
  end)

  after_each(function()
    screen:detach()
  end)

  describe('when opening a tab', function()
    it('behaves as expected', function()
      nvim('command', 'tabnew')
      nvim('command', 'tabnew')
      feed('gtgt:b1<cr>G')
      feed('v<Esc>') -- to clear the bottom line, otherwise showing filenames

      screen:expect([[
        {3: 1 } 2 {3: 3                                          }|
        rows: 8, cols: 50                                 |
        {2: }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
        ^~                                                 |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})

      thelpers.feed_data({'line1', 'line2', 'line3', 'line4', 'line5', ''})
      screen:expect([[
        {3: 1 } 2 {3: 3                                          }|
        rows: 8, cols: 50                                 |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        line5                                             |
        {2:^ }                                                 |
        ~                                                 |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})

      nvim('command', 'new')
      screen:expect([[
        {3: 1 } 2 {3: 3                                          }|
        ^                                                  |
        ~                                                 |
        ~                                                 |
        ==========                                        |
        line5                                             |
        rows: 3, cols: 50                                 |
        {2: }                                                 |
        ==========                                        |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})

      feed('gt:b1<cr>')
      feed('v<Esc>') -- to clear the bottom line, otherwise showing filenames
      thelpers.feed_data({'line6', 'line7', 'line8', ''})
      nvim('command', 'vnew')
      screen:expect([[
        {3: 1  2 } 3                                          |
        ^                         |tty ready               |
        ~                        |rows: 8, cols: 50       |
        ~                        |line1                   |
        ~                        |line2                   |
        ~                        |line3                   |
        ~                        |line4                   |
        ~                        |line5                   |
        ==========                ==========              |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})

      feed('gtG')
      screen:expect([[
         1 {3: 2  3                                          }|
        line8                                             |
        rows: 3, cols: 24                                 |
        {2: }                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ^~                                                 |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})

      feed('gt')
      screen:expect([[
        {3: 1 } 2 {3: 3                                          }|
        ^                                                  |
        ~                                                 |
        ~                                                 |
        ==========                                        |
        line8                                             |
        rows: 3, cols: 24                                 |
        {2: }                                                 |
        ==========                                        |
                                                          |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {underline = true, foreground
      = screen.colors.Black, background = 7}})
    end)
  end)

end)
