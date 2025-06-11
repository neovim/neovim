local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local tt = require('test.functional.testterm')
local assert_alive = n.assert_alive
local clear = n.clear
local feed = n.feed
local feed_command = n.feed_command
local command = n.command
local eq = t.eq
local eval = n.eval
local api = n.api
local sleep = vim.uv.sleep
local retry = t.retry
local is_os = t.is_os

describe(':terminal', function()
  local screen

  before_each(function()
    clear()
    -- set the statusline to a constant value because of variables like pid
    -- and current directory and to improve visibility of splits
    api.nvim_set_option_value('statusline', '==========', {})
    screen = tt.setup_screen(3)
    command('highlight StatusLine NONE')
    command('highlight StatusLineNC NONE')
    command('highlight StatusLineTerm NONE')
    command('highlight StatusLineTermNC NONE')
    command('highlight VertSplit NONE')
  end)

  it('next to a closing window', function()
    command('split')
    command('terminal')
    command('vsplit foo')
    eq(3, eval("winnr('$')"))
    feed('ZQ') -- Close split, should not crash. #7538
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
                                                        |
                                                        |*2
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
                                                        |
                                                        |*2
      ==========                                        |
      :wincmd p                                         |
    ]])
  end)

  it('does not change size if updated when not visible in any window #19665', function()
    local channel = api.nvim_get_option_value('channel', {})
    command('enew')
    sleep(100)
    api.nvim_chan_send(channel, 'foo')
    sleep(100)
    command('bprevious')
    screen:expect([[
      tty ready                                         |
      ^foo                                               |
                                                        |*8
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
        screen:expect { any = 'rows: 7, cols: 47' }
        screen:try_resize(w2, h2)
        screen:expect { any = 'rows: 4, cols: 41' }
      end)
      return
    end

    screen:try_resize(w1, h1)
    screen:expect([[
      tty ready                                      |
      rows: 7, cols: 47                              |
                                                     |
                                                     |*3
      ^                                               |
                                                     |
    ]])
    screen:try_resize(w2, h2)
    screen:expect([[
      tty ready                                |
      rows: 7, cols: 47                        |
      rows: 4, cols: 41                        |
      ^                                         |
                                               |
    ]])
  end)

  it('stays in terminal mode with <Cmd>wincmd', function()
    command('terminal')
    command('split')
    command('terminal')
    feed('a<Cmd>wincmd j<CR>')
    eq(2, eval('winnr()'))
    eq('t', eval('mode(1)'))
  end)

  it("non-terminal opened in Terminal mode applies 'scrolloff' #34447", function()
    api.nvim_set_option_value('scrolloff', 5, {})
    api.nvim_set_option_value('showtabline', 0, {})
    screen:try_resize(78, 10)
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    n.exec_lua([[
      vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        callback = function()
          vim.schedule(function() vim.fn.line('w0') end)
        end,
      })
    ]])
    n.add_builddir_to_rtp()
    n.exec('tab help api-types')
    screen:expect([[
                                                                                    |
      ==============================================================================|
      API Definitions                                         *api-definitions*     |
                                                                                    |
                                                              ^*api-types*           |
      The Nvim C API defines custom types for all function parameters. Some are just|
      typedefs around C99 standard types, others are Nvim-defined data structures.  |
                                                                                    |
      Basic types ~                                                                 |
                                                                                    |
    ]])
  end)
end)
