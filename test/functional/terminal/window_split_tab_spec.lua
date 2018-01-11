local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed, nvim = helpers.feed, helpers.nvim
local feed_command = helpers.feed_command
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval

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

  it('next to a closing window', function()
    command('split')
    command('terminal')
    command('vsplit foo')
    eq(3, eval("winnr('$')"))
    feed('ZQ')  -- Close split, should not crash. #7538
    eq(2, eval("1+1"))  -- Still alive?
  end)

  it('does not change size on WinEnter', function()
    if helpers.pending_win32(pending) then return end
    feed('<c-\\><c-n>')
    feed_command('2split')
    screen:expect([[
      tty ready                                         |
      ^rows: 5, cols: 50                                 |
      ==========                                        |
      tty ready                                         |
      rows: 5, cols: 50                                 |
      {2: }                                                 |
                                                        |
                                                        |
      ==========                                        |
      :2split                                           |
    ]])
    feed_command('wincmd p')
    screen:expect([[
      tty ready                                         |
      rows: 5, cols: 50                                 |
      ==========                                        |
      tty ready                                         |
      ^rows: 5, cols: 50                                 |
      {2: }                                                 |
                                                        |
                                                        |
      ==========                                        |
      :wincmd p                                         |
    ]])
  end)

  it('forwards resize request to the program', function()
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
