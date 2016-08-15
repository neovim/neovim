local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed, nvim = helpers.feed, helpers.nvim
local execute = helpers.execute

if helpers.pending_win32(pending) then return end

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
    screen = thelpers.screen_setup(3)
  end)

  after_each(function()
    screen:detach()
  end)

  it('resets its size when entering terminal window', function()
    feed('<c-\\><c-n>')
    execute('2split')
    screen:expect([[
      tty ready                                         |
      ^rows: 2, cols: 50                                 |
      ==========                                        |
      tty ready                                         |
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      ==========                                        |
                                                        |
    ]])
    execute('wincmd p')
    screen:expect([[
      tty ready                                         |
      rows: 2, cols: 50                                 |
      ==========                                        |
      tty ready                                         |
      rows: 2, cols: 50                                 |
      rows: 5, cols: 50                                 |
      {2: }                                                 |
      ^                                                  |
      ==========                                        |
      :wincmd p                                         |
    ]])
    execute('wincmd p')
    screen:expect([[
      rows: 5, cols: 50                                 |
      ^rows: 2, cols: 50                                 |
      ==========                                        |
      rows: 5, cols: 50                                 |
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      ==========                                        |
      :wincmd p                                         |
    ]])
  end)

  describe('when the screen is resized', function()
    it('will forward a resize request to the program', function()
      screen:try_resize(screen._width + 3, screen._height + 5)
      screen:expect([[
        tty ready                                            |
        rows: 14, cols: 53                                   |
        {1: }                                                    |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
        {3:-- TERMINAL --}                                       |
      ]])
      screen:try_resize(screen._width - 6, screen._height - 10)
      screen:expect([[
        tty ready                                      |
        rows: 14, cols: 53                             |
        rows: 4, cols: 47                              |
        {1: }                                              |
        {3:-- TERMINAL --}                                 |
      ]])
    end)
  end)
end)
