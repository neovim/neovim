local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = t.clear
local command = t.command
local eq = t.eq
local expect = t.expect
local eval = t.eval
local next_msg = t.next_msg
local feed = t.feed
local api = t.api

describe('cmdline autocommands', function()
  local channel
  before_each(function()
    clear()
    channel = api.nvim_get_chan_info(0).id
    api.nvim_set_var('channel', channel)
    command("autocmd CmdlineEnter * call rpcnotify(g:channel, 'CmdlineEnter', v:event)")
    command("autocmd CmdlineLeave * call rpcnotify(g:channel, 'CmdlineLeave', v:event)")
    command("autocmd CmdWinEnter * call rpcnotify(g:channel, 'CmdWinEnter', v:event)")
    command("autocmd CmdWinLeave * call rpcnotify(g:channel, 'CmdWinLeave', v:event)")
  end)

  it('works', function()
    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 1 } } }, next_msg())
    feed('redraw<cr>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = ':', cmdlevel = 1, abort = false } } },
      next_msg()
    )

    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 1 } } }, next_msg())

    -- note: feed('bork<c-c>') might not consume 'bork'
    -- due to out-of-band interrupt handling
    feed('bork<esc>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = ':', cmdlevel = 1, abort = true } } },
      next_msg()
    )
  end)

  it('can abort cmdline', function()
    command('autocmd CmdlineLeave * let v:event.abort= len(getcmdline())>15')
    feed(":put! ='ok'<cr>")
    expect([[
      ok
      ]])

    feed(":put! ='blah blah'<cr>")
    expect([[
      ok
      ]])
  end)

  it('handles errors correctly', function()
    clear()
    local screen = Screen.new(72, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [4] = { bold = true, reverse = true },
    })
    command("autocmd CmdlineEnter * echoerr 'FAIL'")
    command("autocmd CmdlineLeave * echoerr 'very error'")

    feed(':')
    screen:expect([[
                                                                              |
      {1:~                                                                       }|*3
      {4:                                                                        }|
      :                                                                       |
      {2:CmdlineEnter Autocommands for "*": Vim(echoerr):FAIL}                    |
      :^                                                                       |
    ]])

    feed("put ='lorem ipsum'<cr>")
    screen:expect([[
                                                                              |
      {4:                                                                        }|
      :                                                                       |
      {2:CmdlineEnter Autocommands for "*": Vim(echoerr):FAIL}                    |
      :put ='lorem ipsum'                                                     |
      {2:CmdlineLeave Autocommands for "*": Vim(echoerr):very error}              |
                                                                              |
      {3:Press ENTER or type command to continue}^                                 |
    ]])

    -- cmdline was still executed
    feed('<cr>')
    screen:expect([[
                                                                              |
      ^lorem ipsum                                                             |
      {1:~                                                                       }|*5
                                                                              |
    ]])

    command("autocmd CmdlineChanged * echoerr 'change erreor'")

    -- history recall still works
    feed(':<c-p>')
    screen:expect([[
                                                                              |
      lorem ipsum                                                             |
      {4:                                                                        }|
      :                                                                       |
      {2:CmdlineEnter Autocommands for "*": Vim(echoerr):FAIL}                    |
      :put ='lorem ipsum'                                                     |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum'^                                                     |
    ]])

    feed('<left>')
    screen:expect([[
                                                                              |
      lorem ipsum                                                             |
      {4:                                                                        }|
      :                                                                       |
      {2:CmdlineEnter Autocommands for "*": Vim(echoerr):FAIL}                    |
      :put ='lorem ipsum'                                                     |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum^'                                                     |
    ]])

    -- edit still works
    feed('.')
    screen:expect([[
      {4:                                                                        }|
      :                                                                       |
      {2:CmdlineEnter Autocommands for "*": Vim(echoerr):FAIL}                    |
      :put ='lorem ipsum'                                                     |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum.'                                                    |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum.^'                                                    |
    ]])

    feed('<cr>')
    screen:expect([[
      :put ='lorem ipsum'                                                     |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum.'                                                    |
      {2:CmdlineChanged Autocommands for "*": Vim(echoerr):change erreor}         |
      :put ='lorem ipsum.'                                                    |
      {2:CmdlineLeave Autocommands for "*": Vim(echoerr):very error}              |
                                                                              |
      {3:Press ENTER or type command to continue}^                                 |
    ]])

    -- cmdline was still executed
    feed('<cr>')
    screen:expect([[
                                                                              |
      lorem ipsum                                                             |
      ^lorem ipsum.                                                            |
      {1:~                                                                       }|*4
                                                                              |
    ]])
  end)

  it('works with nested cmdline', function()
    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 1 } } }, next_msg())
    feed('<c-r>=')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = '=', cmdlevel = 2 } } }, next_msg())
    feed('<c-f>')
    eq({ 'notification', 'CmdWinEnter', { {} } }, next_msg())
    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 3 } } }, next_msg())
    feed('<c-c>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = ':', cmdlevel = 3, abort = true } } },
      next_msg()
    )
    feed('<c-c>')
    eq({ 'notification', 'CmdWinLeave', { {} } }, next_msg())
    feed('1+2<cr>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = '=', cmdlevel = 2, abort = false } } },
      next_msg()
    )
  end)

  it('no crash with recursive use of v:event #19484', function()
    command('autocmd CmdlineEnter * normal :')
    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 1 } } }, next_msg())
    feed('<CR>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = ':', cmdlevel = 1, abort = false } } },
      next_msg()
    )
  end)

  it('supports CmdlineChanged', function()
    command(
      "autocmd CmdlineChanged * call rpcnotify(g:channel, 'CmdlineChanged', v:event, getcmdline())"
    )
    feed(':')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = ':', cmdlevel = 1 } } }, next_msg())
    feed('l')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'l' } }, next_msg())
    feed('e')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'le' } }, next_msg())
    feed('t')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let' } }, next_msg())
    feed('<space>')
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let ' } },
      next_msg()
    )
    feed('x')
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let x' } },
      next_msg()
    )
    feed('<space>')
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let x ' } },
      next_msg()
    )
    feed('=')
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let x =' } },
      next_msg()
    )
    feed('<space>')
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let x = ' } },
      next_msg()
    )
    feed('<c-r>=')
    eq({ 'notification', 'CmdlineEnter', { { cmdtype = '=', cmdlevel = 2 } } }, next_msg())
    feed('1')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = '=', cmdlevel = 2 }, '1' } }, next_msg())
    feed('+')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = '=', cmdlevel = 2 }, '1+' } }, next_msg())
    feed('1')
    eq({ 'notification', 'CmdlineChanged', { { cmdtype = '=', cmdlevel = 2 }, '1+1' } }, next_msg())
    feed('<cr>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = '=', cmdlevel = 2, abort = false } } },
      next_msg()
    )
    eq(
      { 'notification', 'CmdlineChanged', { { cmdtype = ':', cmdlevel = 1 }, 'let x = 2' } },
      next_msg()
    )
    feed('<cr>')
    eq(
      { 'notification', 'CmdlineLeave', { { cmdtype = ':', cmdlevel = 1, abort = false } } },
      next_msg()
    )
    eq(2, eval('x'))
  end)
end)
