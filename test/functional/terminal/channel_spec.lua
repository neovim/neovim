local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local eval = n.eval
local command = n.command
local pcall_err = t.pcall_err
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local is_os = t.is_os
local api = n.api
local async_meths = n.async_meths
local testprg = n.testprg
local assert_alive = n.assert_alive

describe('terminal channel is closed and later released if', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
  end)

  it('opened by nvim_open_term() and deleted by :bdelete!', function()
    command([[let id = nvim_open_term(0, {})]])
    local chans = eval('len(nvim_list_chans())')
    -- channel hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete! | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by pressing a key', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]])
    )
    screen:expect({ any = '%[Terminal closed%]' })
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after another main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by :bdelete', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]])
    )
    screen:expect({ any = '%[Terminal closed%]' })
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by jobstart(…,{term=true}), exited, and deleted by pressing a key', function()
    command([[let id = jobstart('echo',{'term':v:true})]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({ any = '%[Process exited 0%]' })
    -- process has exited but channel has't been released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chansend(id, 'test')]])
    )
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after another main loop iteration
    t.retry(20, nil, function()
      eq(chans - 1, eval('len(nvim_list_chans())'))
    end)
  end)

  -- This indirectly covers #16264
  it('opened by jobstart(…,{term=true}), exited, and deleted by :bdelete', function()
    command([[let id = jobstart('echo', {'term':v:true})]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({ any = '%[Process exited 0%]' })
    -- process has exited but channel hasn't been released
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[call chansend(id, 'test')]])
    )
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq(
      "Vim(call):Can't send data to closed stream",
      pcall_err(command, [[bdelete | call chansend(id, 'test')]])
    )
    feed('<Ignore>') -- add input to separate two RPC requests
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)
end)

it('chansend sends lines to terminal channel in proper order', function()
  clear({ args = { '--cmd', 'set laststatus=2' } })
  local screen = Screen.new(100, 20)
  screen._default_attr_ids = nil
  local shells = is_os('win') and { 'cmd.exe', 'pwsh.exe -nop', 'powershell.exe -nop' } or { 'sh' }
  for _, sh in ipairs(shells) do
    command([[let id = jobstart(']] .. sh .. [[', {'term':v:true})]])
    command([[call chansend(id, ['echo "hello"', 'echo "world"', ''])]])
    screen:expect {
      any = [[echo "hello".*echo "world"]],
    }
    command('bdelete!')
    screen:expect {
      any = '%[No Name%]',
    }
  end
end)

--- @param event string
--- @param extra_tests fun(table, table)?
local function test_autocmd_no_crash(event, extra_tests)
  local env = {}
  -- Use REPFAST for immediately output after start.
  local term_args = { testprg('shell-test'), 'REPFAST', '50', 'TEST' }

  before_each(function()
    clear()
    env.screen = Screen.new(60, 4)
    command([[file Xoldbuf | call setline(1, 'OLDBUF') | enew]])
    -- Wait before :bwipe to avoid closing PTY master before the child calls setsid(),
    -- as that will cause SIGHUP to be also sent to the parent.
    -- Use vim.uv.sleep() which blocks the event loop.
    n.exec([[
      func Wipe()
        lua vim.uv.sleep(5)
        bwipe!
      endfunc
    ]])
  end)

  it('processes job exit event when using jobstart(…,{term=true})', function()
    api.nvim_create_autocmd(event, { command = "call input('')" })
    async_meths.nvim_call_function('jobstart', { term_args, { term = true } })
    env.screen:expect([[
                                                                  |
      {1:~                                                           }|*2
      ^                                                            |
    ]])
    vim.uv.sleep(20)
    feed('<CR>')
    env.screen:expect([[
      ^0: TEST                                                     |
      1: TEST                                                     |
      2: TEST                                                     |
                                                                  |
    ]])
    feed('i')
    env.screen:expect([[
      49: TEST                                                    |
                                                                  |
      [Process exited 0]^                                          |
      {5:-- TERMINAL --}                                              |
    ]])
    feed('<CR>')
    env.screen:expect([[
      ^OLDBUF                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]])
    assert_alive()
  end)

  it('wipes buffer and processes events when using jobstart(…,{term=true})', function()
    api.nvim_create_autocmd(event, { command = "call Wipe() | call input('')" })
    async_meths.nvim_call_function('jobstart', { term_args, { term = true } })
    env.screen:expect([[
                                                                  |
      {1:~                                                           }|*2
      ^                                                            |
    ]])
    vim.uv.sleep(20)
    feed('<CR>')
    env.screen:expect([[
      ^OLDBUF                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]])
    assert_alive()
    eq('Xoldbuf', eval('bufname()'))
    eq(0, eval([[exists('b:term_title')]]))
  end)

  if extra_tests then
    extra_tests(env, term_args)
  end
end

describe('no crash when TermOpen autocommand', function()
  test_autocmd_no_crash('TermOpen', function(env, term_args)
    it('wipes buffer and processes events when using nvim_open_term()', function()
      api.nvim_create_autocmd('TermOpen', { command = "call Wipe() | call input('')" })
      async_meths.nvim_open_term(0, {})
      env.screen:expect([[
                                                                    |
        {1:~                                                           }|*2
        ^                                                            |
      ]])
      feed('<CR>')
      env.screen:expect([[
        ^OLDBUF                                                      |
        {1:~                                                           }|*2
                                                                    |
      ]])
      assert_alive()
    end)

    it('wipes buffer when using jobstart(…,{term=true}) during Nvim exit', function()
      n.expect_exit(n.exec_lua, function()
        vim.schedule(function()
          vim.fn.jobstart(term_args, { term = true })
        end)
        vim.api.nvim_create_autocmd('TermOpen', { command = 'call Wipe()' })
        vim.cmd('qall!')
      end)
    end)
  end)
end)

describe('no crash when BufFilePre autocommand', function()
  test_autocmd_no_crash('BufFilePre')
end)

describe('no crash when BufFilePost autocommand', function()
  test_autocmd_no_crash('BufFilePost')
end)

describe('nvim_open_term', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(8, 10)
  end)

  it('with force_crlf=true converts newlines', function()
    local win = api.nvim_get_current_win()
    local buf = api.nvim_create_buf(false, true)
    local term = api.nvim_open_term(buf, { force_crlf = true })
    api.nvim_win_set_buf(win, buf)
    api.nvim_chan_send(term, 'here\nthere\nfoo\r\nbar\n\ntest')
    screen:expect([[
      ^here        |
      there       |
      foo         |
      bar         |
                  |
      test        |
                  |*4
    ]])
    api.nvim_chan_send(term, '\nfirst')
    screen:expect([[
      ^here        |
      there       |
      foo         |
      bar         |
                  |
      test        |
      first       |
                  |*3
    ]])
  end)

  it('with force_crlf=false does not convert newlines', function()
    local win = api.nvim_get_current_win()
    local buf = api.nvim_create_buf(false, true)
    local term = api.nvim_open_term(buf, { force_crlf = false })
    api.nvim_win_set_buf(win, buf)
    api.nvim_chan_send(term, 'here\nthere')
    screen:expect([[
      ^here        |
          there   |
                  |*8
    ]])
  end)
end)
