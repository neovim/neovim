local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local assert_alive = helpers.assert_alive
local clear = helpers.clear
local feed = helpers.feed
local feed_command = helpers.feed_command
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local meths = helpers.meths
local sleep = helpers.sleep
local retry = helpers.retry
local is_os = helpers.is_os

describe(':terminal', function()
  local screen

  before_each(function()
    clear()
    -- set the statusline to a constant value because of variables like pid
    -- and current directory and to improve visibility of splits
    meths.set_option_value('statusline', '==========', {})
    command('highlight StatusLine cterm=NONE')
    command('highlight StatusLineNC cterm=NONE')
    command('highlight VertSplit cterm=NONE')
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
    assert_alive()
  end)

  it('does not change size on WinEnter', function()
    feed('<c-\\><c-n>')
    feed('k')
    feed_command('2split')
    screen:expect([[
      ^tty ready                                         |
      rows: 5, cols: 50                                 |
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
      ^tty ready                                         |
      rows: 5, cols: 50                                 |
      {2: }                                                 |
                                                        |
                                                        |
      ==========                                        |
      :wincmd p                                         |
    ]])
  end)

  it('does not change size if updated when not visible in any window #19665', function()
    local channel = meths.get_option_value('channel', {})
    command('enew')
    sleep(100)
    meths.chan_send(channel, 'foo')
    sleep(100)
    command('bprevious')
    screen:expect([[
      tty ready                                         |
      ^foo{2: }                                              |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
    ]])
  end)

  it('forwards resize request to the program', function()
    feed([[<C-\><C-N>G]])
    local w1, h1 = screen._width - 3, screen._height - 2
    local w2, h2 = w1 - 6, h1 - 3

    if is_os('win') then
      -- win: SIGWINCH is unreliable, use a weaker test. #7506
      retry(3, 30000, function()
        screen:try_resize(w1, h1)
        screen:expect{any='rows: 7, cols: 47'}
        screen:try_resize(w2, h2)
        screen:expect{any='rows: 4, cols: 41'}
      end)
      return
    end

    screen:try_resize(w1, h1)
    screen:expect([[
      tty ready                                      |
      rows: 7, cols: 47                              |
      {2: }                                              |
                                                     |
                                                     |
                                                     |
      ^                                               |
                                                     |
    ]])
    screen:try_resize(w2, h2)
    screen:expect([[
      tty ready                                |
      rows: 7, cols: 47                        |
      rows: 4, cols: 41                        |
      {2:^ }                                        |
                                               |
    ]])
  end)

  it('stays in terminal mode with <Cmd>wincmd', function()
    command('terminal')
    command('split')
    command('terminal')
    feed('a<Cmd>wincmd j<CR>')
    eq(2, eval("winnr()"))
    eq('t', eval('mode(1)'))
  end)

end)
