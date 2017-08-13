local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed, nvim = helpers.feed, helpers.nvim
local feed_command = helpers.feed_command

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
    if helpers.pending_win32(pending) then return end
    feed('<c-\\><c-n>')
    feed_command('2split')
    screen:expect([[
      rows: 2, cols: 50                                 |
      {2:^ }                                                 |
      ==========                                        |
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      ==========                                        |
      :2split                                           |
    ]])
    feed_command('wincmd p')
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
    feed_command('wincmd p')
    screen:expect([[
      rows: 2, cols: 50                                 |
      {2:^ }                                                 |
      ==========                                        |
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      ==========                                        |
      :wincmd p                                         |
    ]])
  end)

  describe('when the screen is resized', function()
    it('will forward a resize request to the program', function()
      feed([[<C-\><C-N>:]])  -- Go to cmdline-mode, so cursor is at bottom.
      screen:try_resize(screen._width - 3, screen._height - 2)
      screen:expect([[
        tty ready                                      |
        rows: 7, cols: 47                              |
        {2: }                                              |
                                                       |
                                                       |
                                                       |
                                                       |
        :^                                              |
      ]])
      screen:try_resize(screen._width - 6, screen._height - 3)
      screen:expect([[
        tty ready                                |
        rows: 7, cols: 47                        |
        rows: 4, cols: 41                        |
        {2: }                                        |
        :^                                        |
      ]])
    end)
  end)
end)
