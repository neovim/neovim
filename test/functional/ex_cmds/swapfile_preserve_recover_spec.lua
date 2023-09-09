local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local luv = require('luv')
local eq, eval, expect, exec =
  helpers.eq, helpers.eval, helpers.expect, helpers.exec
local assert_alive = helpers.assert_alive
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local ok = helpers.ok
local rmdir = helpers.rmdir
local new_argv = helpers.new_argv
local new_pipename = helpers.new_pipename
local pesc = helpers.pesc
local os_kill = helpers.os_kill
local set_session = helpers.set_session
local spawn = helpers.spawn
local nvim_async = helpers.nvim_async
local expect_msg_seq = helpers.expect_msg_seq
local pcall_err = helpers.pcall_err
local mkdir = helpers.mkdir

describe(':recover', function()
  before_each(clear)

  it('fails if given a non-existent swapfile', function()
    local swapname = 'bogus_swapfile'
    local swapname2 = 'bogus_swapfile.swp'
    eq('Vim(recover):E305: No swap file found for '..swapname,
      pcall_err(command, 'recover '..swapname))  -- Should not segfault. #2117
    -- Also check filename ending with ".swp". #9504
    eq('Vim(recover):E306: Cannot open '..swapname2,
      pcall_err(command, 'recover '..swapname2))  -- Should not segfault. #2117
    assert_alive()
  end)

end)

describe("preserve and (R)ecover with custom 'directory'", function()
  local swapdir = luv.cwd()..'/Xtest_recover_dir'
  local testfile = 'Xtest_recover_file1'
  -- Put swapdir at the start of the 'directory' list. #1836
  -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
  -- attempt to create a swapfile in different directory.
  local init = [[
    set directory^=]]..swapdir:gsub([[\]], [[\\]])..[[//
    set swapfile fileformat=unix undolevels=-1
  ]]

  local nvim1
  before_each(function()
    nvim1 = spawn(new_argv())
    set_session(nvim1)
    rmdir(swapdir)
    mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  local function setup_swapname()
    exec(init)
    command('edit! '..testfile)
    feed('isometext<esc>')
    exec('redir => g:swapname | silent swapname | redir END')
    return eval('g:swapname')
  end

  local function test_recover(swappath1)
    -- Start another Nvim instance.
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'},
                                true)
    set_session(nvim2)

    exec(init)

    -- Use the "SwapExists" event to choose the (R)ecover choice at the dialog.
    command('autocmd SwapExists * let v:swapchoice = "r"')
    command('silent edit! '..testfile)
    exec('redir => g:swapname | silent swapname | redir END')

    local swappath2 = eval('g:swapname')

    expect('sometext')
    -- swapfile from session 1 should end in .swp
    eq(testfile..'.swp', string.match(swappath1, '[^%%]+$'))
    -- swapfile from session 2 should end in .swo
    eq(testfile..'.swo', string.match(swappath2, '[^%%]+$'))
    -- Verify that :swapname was not truncated (:help 'shortmess').
    ok(nil == string.find(swappath1, '%.%.%.'))
    ok(nil == string.find(swappath2, '%.%.%.'))
  end

  it('with :preserve and SIGKILL', function()
    local swappath1 = setup_swapname()
    command('preserve')
    os_kill(eval('getpid()'))
    test_recover(swappath1)
  end)

  it('closing stdio channel without :preserve #22096', function()
    local swappath1 = setup_swapname()
    nvim1:close()
    test_recover(swappath1)
  end)

  it('killing TUI process without :preserve #22096', function()
    helpers.skip(helpers.is_os('win'))
    local screen = Screen.new()
    screen:attach()
    local child_server = new_pipename()
    funcs.termopen({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--listen', child_server})
    screen:expect({any = pesc('[No Name]')})  -- Wait for the child process to start.
    local child_session = helpers.connect(child_server)
    set_session(child_session)
    local swappath1 = setup_swapname()
    set_session(nvim1)
    command('call chanclose(&channel)')  -- Kill the child process.
    screen:expect({any = pesc('[Process exited 1]')})  -- Wait for the child process to stop.
    test_recover(swappath1)
  end)

end)

describe('swapfile detection', function()
  local swapdir = luv.cwd()..'/Xtest_swapdialog_dir'
  local nvim0
  -- Put swapdir at the start of the 'directory' list. #1836
  -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
  -- attempt to create a swapfile in different directory.
  local init = [[
    set directory^=]]..swapdir:gsub([[\]], [[\\]])..[[//
    set swapfile fileformat=unix nomodified undolevels=-1 nohidden
  ]]
  before_each(function()
    nvim0 = spawn(new_argv())
    set_session(nvim0)
    rmdir(swapdir)
    mkdir(swapdir)
  end)
  after_each(function()
    set_session(nvim0)
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it('always show swapfile dialog #8840 #9027', function()
    local testfile = 'Xtest_swapdialog_file1'

    local expected_no_dialog = '^'..(' '):rep(256)..'|\n'
    for _=1,37 do
      expected_no_dialog = expected_no_dialog..'~'..(' '):rep(255)..'|\n'
    end
    expected_no_dialog = expected_no_dialog..testfile..(' '):rep(216)..'0,0-1          All|\n'
    expected_no_dialog = expected_no_dialog..(' '):rep(256)..'|\n'

    exec(init)
    command('edit! '..testfile)
    feed('isometext<esc>')
    command('preserve')

    -- Start another Nvim instance.
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'}, true, nil, true)
    set_session(nvim2)
    local screen2 = Screen.new(256, 40)
    screen2:attach()
    exec(init)

    -- With shortmess+=F
    command('set shortmess+=F')
    feed(':edit '..testfile..'<CR>')
    screen2:expect{any=[[E325: ATTENTION.*]]..'\n'..[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With :silent and shortmess+=F
    feed(':silent edit %<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With :silent! and shortmess+=F
    feed(':silent! edit %<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With API (via eval/Vimscript) call and shortmess+=F
    feed(':call nvim_command("edit %")<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    feed('<c-c>')
    screen2:expect(expected_no_dialog)

    -- With API call and shortmess+=F
    nvim_async('command', 'edit %')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    expect_msg_seq({
      ignore={'redraw'},
      seqs={
        { {'notification', 'nvim_error_event', {0, 'Vim(edit):E325: ATTENTION'}},
        }
      }
    })
    feed('<cr>')

    nvim2:close()
  end)

  -- oldtest: Test_swap_prompt_splitwin()
  it('selecting "q" in the attention prompt', function()
    exec(init)
    command('edit Xfile1')
    command('preserve')  -- should help to make sure the swap file exists

    local screen = Screen.new(75, 18)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
    })

    local nvim1 = spawn(new_argv(), true, nil, true)
    set_session(nvim1)
    screen:attach()
    exec(init)
    feed(':split Xfile1\n')
    screen:expect({
      any = pesc('{1:[O]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort: }^')
    })
    feed('q')
    feed(':<CR>')
    screen:expect([[
      ^                                                                           |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      :                                                                          |
    ]])
    nvim1:close()

    local nvim2 = spawn(new_argv(), true, nil, true)
    set_session(nvim2)
    screen:attach()
    exec(init)
    command('set more')
    command('au bufadd * let foo_w = wincol()')
    feed(':e Xfile1<CR>')
    screen:expect({any = pesc('{1:-- More --}^')})
    feed('<Space>')
    screen:expect({
      any = pesc('{1:[O]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort: }^')
    })
    feed('q')
    command([[echo 'hello']])
    screen:expect([[
      ^                                                                           |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      hello                                                                      |
    ]])
    nvim2:close()
  end)

  -- oldtest: Test_nocatch_process_still_running()
  it('allows deleting swapfile created before boot vim-patch:8.2.2586', function()
    local screen = Screen.new(75, 30)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
      [2] = {background = Screen.colors.Red, foreground = Screen.colors.White},  -- ErrorMsg
    })
    screen:attach()

    exec(init)
    command('set nohidden')

    exec([=[
      " Make a copy of the current swap file to "Xswap".
      " Return the name of the swap file.
      func CopySwapfile()
        preserve
        " get the name of the swap file
        let swname = split(execute("swapname"))[0]
        let swname = substitute(swname, '[[:blank:][:cntrl:]]*\(.\{-}\)[[:blank:][:cntrl:]]*$', '\1', '')
        " make a copy of the swap file in Xswap
        set binary
        exe 'sp ' . fnameescape(swname)
        w! Xswap
        set nobinary
        return swname
      endfunc
    ]=])

    -- Edit a file and grab its swapfile.
    exec([[
      edit Xswaptest
      call setline(1, ['a', 'b', 'c'])
    ]])
    local swname = funcs.CopySwapfile()

    -- Forget we edited this file
    exec([[
      new
      only!
      bwipe! Xswaptest
    ]])

    os.rename('Xswap', swname)

    feed(':edit Xswaptest<CR>')
    screen:expect({any = table.concat({
      pesc('{2:E325: ATTENTION}'),
      'file name: .*Xswaptest',
      'process ID: %d* %(STILL RUNNING%)',
      pesc('{1:[O]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort: }^'),
    }, '.*')})

    feed('e')

    -- Forget we edited this file
    exec([[
      new
      only!
      bwipe! Xswaptest
    ]])

    -- pretend that the swapfile was created before boot
    local atime = os.time() - luv.uptime() - 10
    luv.fs_utime(swname, atime, atime)

    feed(':edit Xswaptest<CR>')
    screen:expect({any = table.concat({
      pesc('{2:E325: ATTENTION}'),
      pesc('{1:[O]pen Read-Only, (E)dit anyway, (R)ecover, (D)elete it, (Q)uit, (A)bort: }^'),
    }, '.*')})

    feed('e')
  end)
end)
