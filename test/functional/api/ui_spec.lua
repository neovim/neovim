local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each, finally = t.describe, t.it, t.before_each, t.finally
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local exec = n.exec
local exec_lua = n.exec_lua
local feed = n.feed
local api = n.api
local request = n.request
local pcall_err = t.pcall_err
local uv = vim.uv

describe('nvim_ui_attach()', function()
  before_each(function()
    clear()
  end)

  it('handles very large width/height #2180', function()
    local _ = Screen.new(999, 999)
    eq(999, eval('&lines'))
    eq(999, eval('&columns'))
  end)

  it('validation', function()
    eq("Invalid UI option: 'foo'", pcall_err(api.nvim_ui_attach, 80, 24, { foo = { 'foo' } }))

    eq(
      "Invalid 'ext_linegrid': expected Boolean, got Array",
      pcall_err(api.nvim_ui_attach, 80, 24, { ext_linegrid = {} })
    )
    eq(
      "Invalid 'override': expected Boolean, got Array",
      pcall_err(api.nvim_ui_attach, 80, 24, { override = {} })
    )
    eq(
      "Invalid 'rgb': expected Boolean, got Array",
      pcall_err(api.nvim_ui_attach, 80, 24, { rgb = {} })
    )
    eq(
      "Invalid 'term_name': expected String, got Boolean",
      pcall_err(api.nvim_ui_attach, 80, 24, { term_name = true })
    )
    eq(
      "Invalid 'term_colors': expected Integer, got Boolean",
      pcall_err(api.nvim_ui_attach, 80, 24, { term_colors = true })
    )
    eq(
      "Invalid 'stdin_fd': expected Integer, got String",
      pcall_err(api.nvim_ui_attach, 80, 24, { stdin_fd = 'foo' })
    )
    eq(
      "Invalid 'stdin_tty': expected Boolean, got String",
      pcall_err(api.nvim_ui_attach, 80, 24, { stdin_tty = 'foo' })
    )
    eq(
      "Invalid 'stdout_tty': expected Boolean, got String",
      pcall_err(api.nvim_ui_attach, 80, 24, { stdout_tty = 'foo' })
    )

    eq('UI not attached to channel: 1', pcall_err(request, 'nvim_ui_try_resize', 40, 10))
    eq('UI not attached to channel: 1', pcall_err(request, 'nvim_ui_set_option', 'rgb', true))
    eq('UI not attached to channel: 1', pcall_err(request, 'nvim_ui_detach'))

    local _ = Screen.new(nil, nil, { rgb = false })
    eq(
      'UI already attached to channel: 1',
      pcall_err(request, 'nvim_ui_attach', 40, 10, { rgb = false })
    )
  end)

  it('does not crash if maximum UI count is reached', function()
    local server = api.nvim_get_vvar('servername')
    local screens = {} --- @type test.functional.ui.screen[]
    for i = 1, 16 do
      screens[i] = Screen.new(nil, nil, nil, n.connect(server))
    end
    eq(
      -- 0 is kErrorTypeException
      { false, { 0, 'Maximum UI count reached' } },
      { n.connect(server):request('nvim_ui_attach', 80, 24, {}) }
    )
    for i = 1, 16 do
      screens[i]:detach()
    end
  end)
end)

describe('nvim_ui_send', function()
  before_each(function()
    clear()
  end)

  local function close_pipe(pipe)
    if not pipe:is_closing() then
      pipe:read_stop()
      pipe:close()
    end
  end

  it('works with stdout_tty', function()
    local fds = assert(uv.pipe())

    local read_pipe = assert(uv.new_pipe())
    read_pipe:open(fds.read)

    local read_data = {}
    read_pipe:read_start(function(err, data)
      assert(not err, err)
      if data then
        table.insert(read_data, data)
      end
    end)

    local screen = Screen.new(50, 10, { stdout_tty = true })
    screen:set_stdout(fds.write)
    finally(function()
      screen:detach()
      close_pipe(read_pipe)
    end)

    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
                                                        |
    ]])

    api.nvim_ui_send('Hello world')

    screen:expect_unchanged()

    -- The TUI client queries OSC 11 on connect, so that precedes the payload.
    local bg_request = '\027]11;?\007'
    eq(bg_request .. 'Hello world', table.concat(read_data))
  end)

  it('ignores ui_send event for UIs without stdout_tty', function()
    local fds = assert(uv.pipe())

    local read_pipe = assert(uv.new_pipe())
    read_pipe:open(fds.read)

    local read_data = {}
    read_pipe:read_start(function(err, data)
      assert(not err, err)
      if data then
        table.insert(read_data, data)
      end
    end)

    local screen = Screen.new(50, 10)
    screen:set_stdout(fds.write)
    finally(function()
      screen:detach()
      close_pipe(read_pipe)
    end)

    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
                                                        |
    ]])

    api.nvim_ui_send('Hello world')

    screen:expect_unchanged()

    eq('', table.concat(read_data))
  end)
end)

describe('UI event channels', function()
  it('sets chan for UIEnter/UILeave', function()
    clear { args_rm = { '--headless' } }
    exec([[
    let g:evs = []
    autocmd UIEnter * call add(g:evs, "UIEnter") | let g:uienter_ev = deepcopy(v:event)
    autocmd UILeave * call add(g:evs, "UILeave") | let g:uileave_ev = deepcopy(v:event)
    autocmd VimEnter * call add(g:evs, "VimEnter")
    autocmd VimLeave * call add(g:evs, "VimLeave")
  ]])

    local screen = Screen.new()
    eq({ chan = 1 }, eval('g:uienter_ev'))
    eq({ 'VimEnter', 'UIEnter' }, eval('g:evs'))

    screen:detach()
    eq({ chan = 1 }, eval('g:uileave_ev'))
    eq({ 'VimEnter', 'UIEnter', 'UILeave' }, eval('g:evs'))

    local servername = api.nvim_get_vvar('servername')

    local session2 = n.connect(servername)
    local status2, chan2 = session2:request('nvim_get_chan_info', 0)
    t.ok(status2)

    local session3 = n.connect(servername)
    local status3, chan3 = session3:request('nvim_get_chan_info', 0)
    t.ok(status3)

    local screen2 = Screen.new(nil, nil, nil, session2)
    eq({ chan = chan2.id }, eval('g:uienter_ev'))
    eq({ 'VimEnter', 'UIEnter', 'UILeave', 'UIEnter' }, eval('g:evs'))

    screen2:detach()
    eq({ chan = chan2.id }, eval('g:uileave_ev'))
    eq({ 'VimEnter', 'UIEnter', 'UILeave', 'UIEnter', 'UILeave' }, eval('g:evs'))

    command('let g:evs = ["…"]')

    screen2:attach(session2)
    eq({ chan = chan2.id }, eval('g:uienter_ev'))
    eq({ '…', 'UIEnter' }, eval('g:evs'))

    Screen.new(nil, nil, nil, session3)
    eq({ chan = chan3.id }, eval('g:uienter_ev'))
    eq({ '…', 'UIEnter', 'UIEnter' }, eval('g:evs'))

    screen:attach(n.get_session())
    eq({ chan = 1 }, eval('g:uienter_ev'))
    eq({ '…', 'UIEnter', 'UIEnter', 'UIEnter' }, eval('g:evs'))

    session3:close()
    t.retry(nil, 1000, function()
      eq({}, api.nvim_get_chan_info(chan3.id))
    end)
    eq({ chan = chan3.id }, eval('g:uileave_ev'))
    eq({ '…', 'UIEnter', 'UIEnter', 'UIEnter', 'UILeave' }, eval('g:evs'))

    command('let g:evs = ["…"]')
    command('autocmd UILeave * call writefile(g:evs, "Xevents.log")')
    finally(function()
      os.remove('Xevents.log')
    end)
    n.expect_exit(command, 'qall!')
    n.check_close() -- Wait for process exit.
    -- UILeave should have been triggered for both remaining UIs.
    eq('…\nVimLeave\nUILeave\nUILeave\n', t.read_file('Xevents.log'))
  end)

  it('sets chan for TermResponse and filters tty requests', function()
    clear()
    local main_chan = api.nvim_get_chan_info(0).id
    local session2 = n.connect(api.nvim_get_vvar('servername'))
    local status2, chan2 = session2:request('nvim_get_chan_info', 0)
    t.ok(status2)

    exec_lua([[
    _G.responses = {}
    vim.api.nvim_create_autocmd('TermResponse', {
      callback = function(ev)
        table.insert(_G.responses, ev.data)
      end,
    })
  ]])

    request('nvim_ui_term_event', 'termresponse', 'main')
    session2:request('nvim_ui_term_event', 'termresponse', 'other')
    request('nvim_ui_term_event', 'termresponse', '\027]11;rgb:0000/0000/0000')

    eq({
      { sequence = 'main', chan = main_chan },
      { sequence = 'other', chan = chan2.id },
      {
        sequence = '\027]11;rgb:0000/0000/0000',
        chan = main_chan,
        detected_background = 'dark',
      },
    }, exec_lua('return _G.responses'))

    exec_lua(
      [[
      _G.filtered = {}
      vim.tty.request('', { timeout = 0, chan = ... }, function(resp, data)
        table.insert(_G.filtered, { resp, data.detected_background })
        return true
      end)
    ]],
      chan2.id
    )

    request('nvim_ui_term_event', 'termresponse', 'ignored')
    session2:request('nvim_ui_term_event', 'termresponse', '\027]11;rgb:ffff/ffff/ffff')
    eq(
      { { '\027]11;rgb:ffff/ffff/ffff', 'light' } },
      exec_lua('return _G.filtered')
    )

    session2:close()
  end)

  it('tracks detected background metadata per stdout_tty UI channel', function()
    clear()
    local server = api.nvim_get_vvar('servername')
    local session2 = n.connect(server)
    local status2, chan2 = session2:request('nvim_get_chan_info', 0)
    t.ok(status2)
    local screen2 = Screen.new(20, 4, { stdout_tty = true }, false)
    screen2.rpc_async = true
    screen2:attach(session2)

    local session3 = n.connect(server)
    local status3, chan3 = session3:request('nvim_get_chan_info', 0)
    t.ok(status3)
    local screen3 = Screen.new(20, 4, { stdout_tty = true }, false)
    screen3.rpc_async = true
    screen3:attach(session3)

    finally(function()
      screen2:detach()
      screen3:detach()
      session2:close()
      session3:close()
    end)

    t.retry(nil, 1000, function()
      local seen = {}
      for _, ui in ipairs(api.nvim_list_uis()) do
        seen[ui.chan] = ui.stdout_tty
      end
      eq(true, seen[chan2.id])
      eq(true, seen[chan3.id])
    end)

    session2:notify('nvim_ui_term_event', 'termresponse', '\027]11;rgb:ffff/ffff/ffff')
    session3:notify('nvim_ui_term_event', 'termresponse', '\027]11;rgb:0000/0000/0000')

    t.retry(nil, 1000, function()
      local seen = {}
      for _, ui in ipairs(api.nvim_list_uis()) do
        seen[ui.chan] = ui.detected_background
      end
      eq('light', seen[chan2.id])
      eq('dark', seen[chan3.id])
    end)
  end)
end)

it('autocmds VimSuspend/VimResume #22041', function()
  clear()
  local screen = Screen.new()
  exec([[
    let g:ev = []
    autocmd VimResume  * :call add(g:ev, 'r')
    autocmd VimSuspend * :call add(g:ev, 's')
  ]])

  eq(false, screen.suspended)
  feed('<C-Z>')
  screen:expect(function()
    eq(true, screen.suspended)
  end)
  eq({ 's' }, eval('g:ev'))
  screen.suspended = false
  feed('<Ignore>')
  eq({ 's', 'r' }, eval('g:ev'))

  command('suspend')
  screen:expect(function()
    eq(true, screen.suspended)
  end)
  eq({ 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  api.nvim_input_mouse('move', '', '', 0, 0, 0)
  eq({ 's', 'r', 's', 'r' }, eval('g:ev'))

  feed('<C-Z><C-Z><C-Z>')
  screen:expect(function()
    eq(true, screen.suspended)
  end)
  api.nvim_ui_set_focus(false)
  eq({ 's', 'r', 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  api.nvim_ui_set_focus(true)
  eq({ 's', 'r', 's', 'r', 's', 'r' }, eval('g:ev'))

  command('suspend | suspend | suspend')
  screen:expect(function()
    eq(true, screen.suspended)
  end)
  screen:detach()
  eq({ 's', 'r', 's', 'r', 's', 'r', 's' }, eval('g:ev'))
  screen.suspended = false
  screen:attach()
  eq({ 's', 'r', 's', 'r', 's', 'r', 's', 'r' }, eval('g:ev'))
end)
