local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local expect = helpers.expect
local next_msg = helpers.next_msg
local feed = helpers.feed
local meths = helpers.meths

describe('cmdline autocommands', function()
  local channel
  before_each(function()
    clear()
    channel = meths.get_api_info()[1]
    meths.set_var("channel",channel)
    command("autocmd CmdlineEnter * call rpcnotify(g:channel, 'CmdlineEnter', v:event)")
    command("autocmd CmdlineLeave * call rpcnotify(g:channel, 'CmdlineLeave', v:event)")
    command("autocmd CmdWinEnter * call rpcnotify(g:channel, 'CmdWinEnter', v:event)")
    command("autocmd CmdWinLeave * call rpcnotify(g:channel, 'CmdWinLeave', v:event)")
  end)

  it('works', function()
    feed(':')
    eq({'notification', 'CmdlineEnter', {{cmdtype=':', cmdlevel=1}}}, next_msg())
    feed('redraw<cr>')
    eq({'notification', 'CmdlineLeave',
        {{cmdtype=':', cmdlevel=1, abort=false}}}, next_msg())

    feed(':')
    eq({'notification', 'CmdlineEnter', {{cmdtype=':', cmdlevel=1}}}, next_msg())

    -- note: feed('bork<c-c>') might not consume 'bork'
    -- due to out-of-band interupt handling
    feed('bork<esc>')
    eq({'notification', 'CmdlineLeave',
        {{cmdtype=':', cmdlevel=1, abort=true}}}, next_msg())
  end)

  it('can abort cmdline', function()
    command("autocmd CmdlineLeave * let v:event.abort= len(getcmdline())>15")
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
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    command("autocmd CmdlineEnter * echoerr 'FAIL'")
    command("autocmd CmdlineLeave * echoerr 'very error'")
    feed(':')
    screen:expect([[
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
      :                                                                       |
      {2:E5500: autocmd has thrown an exception: Vim(echoerr):FAIL}               |
      :^                                                                       |
    ]])
    feed("put ='lorem ipsum'<cr>")
    screen:expect([[
      {1:~                                                                       }|
      {1:~                                                                       }|
      :                                                                       |
      {2:E5500: autocmd has thrown an exception: Vim(echoerr):FAIL}               |
      :put ='lorem ipsum'                                                     |
      {2:E5500: autocmd has thrown an exception: Vim(echoerr):very error}         |
                                                                              |
      {3:Press ENTER or type command to continue}^                                 |
    ]])

    feed('<cr>')
    screen:expect([[
                                                                              |
      ^lorem ipsum                                                             |
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
      {1:~                                                                       }|
                                                                              |
    ]])
  end)

  it('works with nested cmdline', function()
    feed(':')
    eq({'notification', 'CmdlineEnter', {{cmdtype=':', cmdlevel=1}}}, next_msg())
    feed('<c-r>=')
    eq({'notification', 'CmdlineEnter', {{cmdtype='=', cmdlevel=2}}}, next_msg())
    feed('<c-f>')
    eq({'notification', 'CmdWinEnter', {{}}}, next_msg())
    feed(':')
    eq({'notification', 'CmdlineEnter', {{cmdtype=':', cmdlevel=3}}}, next_msg())
    feed('<c-c>')
    eq({'notification', 'CmdlineLeave', {{cmdtype=':', cmdlevel=3, abort=true}}}, next_msg())
    feed('<c-c>')
    eq({'notification', 'CmdWinLeave', {{}}}, next_msg())
    feed('1+2<cr>')
    eq({'notification', 'CmdlineLeave', {{cmdtype='=', cmdlevel=2, abort=false}}}, next_msg())
  end)
end)
