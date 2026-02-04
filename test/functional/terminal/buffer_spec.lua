local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local assert_alive = n.assert_alive
local feed, clear = n.feed, n.clear
local poke_eventloop = n.poke_eventloop
local nvim_prog = n.nvim_prog
local eval, feed_command, source = n.eval, n.feed_command, n.source
local pcall_err = t.pcall_err
local eq, neq = t.eq, t.neq
local api = n.api
local retry = t.retry
local testprg = n.testprg
local write_file = t.write_file
local command = n.command
local exc_exec = n.exc_exec
local matches = t.matches
local exec_lua = n.exec_lua
local sleep = vim.uv.sleep
local fn = n.fn
local is_os = t.is_os
local skip = t.skip

describe(':terminal buffer', function()
  local screen

  before_each(function()
    clear()
    command('set modifiable swapfile undolevels=20')
    screen = tt.setup_screen()
  end)

  it('terminal-mode forces various options', function()
    local expr =
      '[&l:cursorlineopt, &l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]'

    feed([[<C-\><C-N>]])
    command('setlocal cursorline cursorlineopt=both cursorcolumn scrolloff=4 sidescrolloff=7')
    eq({ 'both', 1, 1, 4, 7 }, eval(expr))
    eq('nt', eval('mode(1)'))

    -- Enter Terminal mode ("insert" mode in :terminal).
    feed('i')
    eq('t', eval('mode(1)'))
    eq({ 'number', 1, 0, 0, 0 }, eval(expr))

    -- Return to Normal mode.
    feed([[<C-\><C-N>]])
    eq('nt', eval('mode(1)'))
    eq({ 'both', 1, 1, 4, 7 }, eval(expr))

    -- Enter Terminal mode again.
    feed('i')
    eq('t', eval('mode(1)'))
    eq({ 'number', 1, 0, 0, 0 }, eval(expr))

    -- Delete the terminal buffer and return to the previous buffer.
    command('bwipe!')
    feed('<Ignore>') -- Add input to separate two RPC requests
    eq('n', eval('mode(1)'))
    -- Window options in the old buffer should be unchanged. #37484
    eq({ 'both', 0, 0, -1, -1 }, eval(expr))
  end)

  it('terminal-mode does not change cursorlineopt if cursorline is disabled', function()
    feed([[<C-\><C-N>]])
    command('setlocal nocursorline cursorlineopt=both')
    feed('i')
    eq({ 0, 'both' }, eval('[&l:cursorline, &l:cursorlineopt]'))
  end)

  it('terminal-mode disables cursorline when cursorlineopt is only set to "line"', function()
    feed([[<C-\><C-N>]])
    command('setlocal cursorline cursorlineopt=line')
    feed('i')
    eq({ 0, 'line' }, eval('[&l:cursorline, &l:cursorlineopt]'))
  end)

  describe('swap and undo', function()
    before_each(function()
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])
    end)

    it('does not create swap files', function()
      eq('No swap file', n.exec_capture('swapname'))
    end)

    it('does not create undo files', function()
      local undofile = api.nvim_eval('undofile(bufname("%"))')
      eq(nil, io.open(undofile))
    end)
  end)

  it('cannot be modified directly', function()
    feed('<c-\\><c-n>dd')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {101:E21: Cannot make changes, 'modifiable' is off}     |
    ]])
  end)

  it('sends data to the terminal when the "put" operator is used', function()
    feed('<c-\\><c-n>gg"ayj')
    feed_command('let @a = "appended " . @a')
    feed('"ap"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |*2
                                                        |
                                                        |*2
      :let @a = "appended " . @a                        |
    ]])
    -- operator count is also taken into consideration
    feed('3"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |*5
      :let @a = "appended " . @a                        |
    ]])
  end)

  it('sends data to the terminal when the ":put" command is used', function()
    feed('<c-\\><c-n>gg"ayj')
    feed_command('let @a = "appended " . @a')
    feed_command('put a')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
                                                        |
                                                        |*3
      :put a                                            |
    ]])
    -- line argument is only used to move the cursor
    feed_command('6put a')
    screen:expect([[
      tty ready                                         |
      appended tty ready                                |*2
                                                        |
                                                        |
      ^                                                  |
      :6put a                                           |
    ]])
  end)

  it('can be deleted', function()
    feed('<c-\\><c-n>:bd!<cr>')
    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*5
      :bd!                                              |
    ]])
    feed_command('bnext')
    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*5
      :bnext                                            |
    ]])
  end)

  it('handles loss of focus gracefully', function()
    -- Change the statusline to avoid printing the file name, which varies.
    api.nvim_set_option_value('statusline', '==========', {})

    -- Save the buffer number of the terminal for later testing.
    local tbuf = eval('bufnr("%")')
    local exitcmd = is_os('win') and "['cmd', '/c', 'exit']" or "['sh', '-c', 'exit']"
    source([[
    function! SplitWindow(id, data, event)
      new
      call feedkeys("iabc\<Esc>")
    endfunction

    startinsert
    call jobstart(]] .. exitcmd .. [[, {'on_exit': function("SplitWindow")})
    call feedkeys("\<C-\>", 't')  " vim will expect <C-n>, but be exited out of
                                  " the terminal before it can be entered.
    ]])

    -- We should be in a new buffer now.
    screen:expect([[
      ab^c                                               |
      {100:~                                                 }|
      {3:==========                                        }|
      rows: 2, cols: 50                                 |
                                                        |
      {119:==========                                        }|
                                                        |
    ]])

    neq(tbuf, eval('bufnr("%")'))
    feed_command('quit!') -- Should exit the new window, not the terminal.
    eq(tbuf, eval('bufnr("%")'))
  end)

  describe('handles confirmations', function()
    it('with :confirm', function()
      feed('<c-\\><c-n>')
      feed_command('confirm bdelete')
      screen:expect { any = 'Close "term://' }
    end)

    it('with &confirm', function()
      feed('<c-\\><c-n>')
      feed_command('bdelete')
      screen:expect { any = 'E89' }
      feed('<cr>')
      eq('terminal', eval('&buftype'))
      feed_command('set confirm | bdelete')
      screen:expect { any = 'Close "term://' }
      feed('y')
      neq('terminal', eval('&buftype'))
    end)
  end)

  it('it works with set rightleft #11438', function()
    local columns = eval('&columns')
    feed(string.rep('a', columns))
    command('set rightleft')
    screen:expect([[
                                               ydaer ytt|
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
                                                        |*4
      {5:-- TERMINAL --}                                    |
    ]])
    command('bdelete!')
  end)

  it('requires bang (!) to close a running job #15402', function()
    eq('Vim(wqall):E948: Job still running (add ! to end the job)', exc_exec('wqall'))
    for _, cmd in ipairs({ 'bdelete', '%bdelete', 'bwipeout', 'bunload' }) do
      matches(
        '^Vim%('
          .. cmd:gsub('%%', '')
          .. '%):E89: term://.*tty%-test.* will be killed %(add %! to override%)$',
        exc_exec(cmd)
      )
    end
    command('call jobstop(&channel)')
    assert(0 >= eval('jobwait([&channel], 1000)[0]'))
    command('bdelete')
  end)

  it(':wqall! closes a running job', function()
    n.expect_exit(command, 'wqall!')
  end)

  it('stops running jobs with :quit', function()
    -- Open in a new window to avoid terminating the nvim instance
    command('split')
    command('terminal')
    command('set nohidden')
    command('quit')
  end)

  it('does not segfault when pasting empty register #13955', function()
    feed('<c-\\><c-n>')
    feed_command('put a') -- register a is empty
    n.assert_alive()
  end)

  it([[can use temporary normal mode <c-\><c-o>]], function()
    eq('t', fn.mode(1))
    feed [[<c-\><c-o>]]
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {5:-- (terminal) --}                                  |
    ]])
    eq('ntT', fn.mode(1))

    feed [[:let g:x = 17]]
    screen:expect([[
      tty ready                                         |
                                                        |
                                                        |*4
      :let g:x = 17^                                     |
    ]])

    feed [[<cr>]]
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {5:-- TERMINAL --}                                    |
    ]])
    eq('t', fn.mode(1))
  end)

  it('writing to an existing file with :w fails #13549', function()
    eq(
      'Vim(write):E13: File exists (add ! to override)',
      pcall_err(command, 'write test/functional/fixtures/tty-test.c')
    )
  end)

  it('external interrupt (got_int) does not hang #20726', function()
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    command('call timer_start(0, {-> interrupt()})')
    feed('<Ignore>') -- Add input to separate two RPC requests
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed([[<C-\><C-N>]])
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
    command('bd!')
  end)

  it('correct size when switching buffers', function()
    local term_buf = api.nvim_get_current_buf()
    command('file foo | enew | vsplit')
    api.nvim_set_current_buf(term_buf)
    screen:expect([[
      tty ready                │                        |
      ^rows: 5, cols: 25        │{100:~                       }|
                               │{100:~                       }|*3
      {120:foo [-]                   }{2:[No Name]               }|
                                                        |
    ]])

    feed('<C-^><C-W><C-O><C-^>')
    screen:expect([[
      tty ready                                         |
      ^rows: 5, cols: 25                                 |
      rows: 6, cols: 50                                 |
                                                        |*4
    ]])
  end)

  it('reports focus notifications when requested', function()
    feed([[<C-\><C-N>]])
    exec_lua(function()
      local function new_test_term()
        local chan = vim.api.nvim_open_term(0, {
          on_input = function(_, term, buf, data)
            if data == '\27[I' then
              vim.b[buf].term_focused = true
              vim.api.nvim_chan_send(term, 'focused\n')
            elseif data == '\27[O' then
              vim.b[buf].term_focused = false
              vim.api.nvim_chan_send(term, 'unfocused\n')
            end
          end,
        })
        vim.b.term_focused = false
        vim.api.nvim_chan_send(chan, '\27[?1004h') -- Enable focus reporting
      end

      vim.cmd 'edit bar'
      new_test_term()
      vim.cmd 'vnew foo'
      new_test_term()
      vim.cmd 'vsplit'
    end)
    screen:expect([[
      ^                    │              │              |
                          │              │              |*4
      {120:foo [-]              }{119:foo [-]        bar [-]       }|
                                                        |
    ]])

    -- TermEnter/Leave happens *after* entering/leaving terminal mode, so focus should've changed
    -- already by the time these events run.
    exec_lua(function()
      _G.last_event = nil
      vim.api.nvim_create_autocmd({ 'TermEnter', 'TermLeave' }, {
        callback = function(args)
          _G.last_event = args.event
            .. ' '
            .. vim.fs.basename(args.file)
            .. ' '
            .. tostring(vim.b[args.buf].term_focused)
        end,
      })
    end)

    feed('i')
    screen:expect([[
      focused             │focused       │              |
      ^                    │              │              |
                          │              │              |*3
      {120:foo [-]              }{119:foo [-]        bar [-]       }|
      {5:-- TERMINAL --}                                    |
    ]])
    eq('TermEnter foo true', exec_lua('return _G.last_event'))

    -- Next window has the same terminal; no new notifications.
    command('wincmd w')
    screen:expect([[
      focused             │focused             │        |
                          │^                    │        |
                          │                    │        |*3
      {119:foo [-]              }{120:foo [-]              }{119:bar [-] }|
      {5:-- TERMINAL --}                                    |
    ]])
    -- Next window has a different terminal; expect new unfocus and focus notifications.
    command('wincmd w')
    screen:expect([[
      focused             │focused │focused             |
      unfocused           │unfocuse│^                    |
                          │        │                    |*3
      {119:foo [-]              foo [-]  }{120:bar [-]             }|
      {5:-- TERMINAL --}                                    |
    ]])
    -- Leaving terminal mode; expect a new unfocus notification.
    feed([[<C-\><C-N>]])
    screen:expect([[
      focused             │focused │focused             |
      unfocused           │unfocuse│unfocused           |
                          │        │^                    |
                          │        │                    |*2
      {119:foo [-]              foo [-]  }{120:bar [-]             }|
                                                        |
    ]])
    eq('TermLeave bar false', exec_lua('return _G.last_event'))
  end)

  it('no crash with race between buffer close and OSC 2', function()
    skip(is_os('win'), 'tty-test cannot forward OSC 2 on Windows?')
    exec_lua(function()
      vim.api.nvim_chan_send(vim.bo.channel, '\027]2;SOME_TITLE\007')
    end)
    retry(nil, 4000, function()
      eq('SOME_TITLE', api.nvim_buf_get_var(0, 'term_title'))
    end)
    screen:expect_unchanged()
    --- @type string
    local title_before_del = exec_lua(function()
      vim.wait(10) -- Ensure there are no pending events so that a write isn't queued.
      vim.api.nvim_chan_send(vim.bo.channel, '\027]2;OTHER_TITLE\007')
      vim.uv.sleep(50) -- Block the event loop and wait for tty-test to forward OSC 2.
      local term_title = vim.b.term_title
      vim.api.nvim_buf_delete(0, { force = true })
      vim.wait(10, nil, nil, true) -- Process fast events only.
      return term_title
    end)
    -- Title isn't changed until the second vim.wait().
    eq('SOME_TITLE', title_before_del)
    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*5
                                                        |
    ]])
    assert_alive()
  end)
end)

describe(':terminal buffer', function()
  before_each(clear)

  it('term_close() use-after-free #4393', function()
    command('terminal yes')
    feed('<Ignore>') -- Add input to separate two RPC requests
    command('bdelete!')
  end)

  describe('TermRequest', function()
    it('emits events #26972', function()
      local term = api.nvim_open_term(0, {})
      local termbuf = api.nvim_get_current_buf()

      -- Test that <abuf> is the terminal buffer, not the current buffer
      command('au TermRequest * let g:termbuf = +expand("<abuf>")')
      command('wincmd p')

      -- cwd will be inserted in a file URI, which cannot contain backs
      local cwd = t.fix_slashes(fn.getcwd())
      local parent = cwd:match('^(.+/)')
      local expected = '\027]7;file://host' .. parent
      api.nvim_chan_send(term, string.format('%s\027\\', expected))
      eq(expected, eval('v:termrequest'))
      eq(termbuf, eval('g:termbuf'))
    end)

    it('emits events for APC', function()
      local term = api.nvim_open_term(0, {})

      -- cwd will be inserted in a file URI, which cannot contain backs
      local cwd = t.fix_slashes(fn.getcwd())
      local parent = cwd:match('^(.+/)')
      local expected = '\027_Gfile://host' .. parent
      api.nvim_chan_send(term, string.format('%s\027\\', expected))
      eq(expected, eval('v:termrequest'))
    end)

    it('synchronization #27572', function()
      command('autocmd! nvim.terminal TermRequest')
      local term = exec_lua([[
        _G.input = {}
        local term = vim.api.nvim_open_term(0, {
          on_input = function(_, _, _, data)
            table.insert(_G.input, data)
          end,
          force_crlf = false,
        })
        vim.api.nvim_create_autocmd('TermRequest', {
          callback = function(args)
            if args.data.sequence == '\027]11;?' then
              table.insert(_G.input, '\027]11;rgb:0000/0000/0000\027\\')
            end
          end
        })
        return term
      ]])
      api.nvim_chan_send(term, '\027]11;?\007\027[5n\027]11;?\007\027[5n')
      eq({
        '\027]11;rgb:0000/0000/0000\027\\',
        '\027[0n',
        '\027]11;rgb:0000/0000/0000\027\\',
        '\027[0n',
      }, exec_lua('return _G.input'))
    end)

    it('works with vim.wait() from another autocommand #32706', function()
      command('autocmd! nvim.terminal TermRequest')
      exec_lua([[
        local term = vim.api.nvim_open_term(0, {})
        vim.api.nvim_create_autocmd('TermRequest', {
          buffer = 0,
          callback = function(ev)
            _G.sequence = ev.data.sequence
            _G.v_termrequest = vim.v.termrequest
          end,
        })
        vim.api.nvim_create_autocmd('TermEnter', {
          buffer = 0,
          callback = function()
            vim.api.nvim_chan_send(term, '\027]11;?\027\\')
            _G.result = vim.wait(3000, function()
              local expected = '\027]11;?'
              return _G.sequence == expected and _G.v_termrequest == expected
            end)
          end,
        })
      ]])
      feed('i')
      retry(nil, 4000, function()
        eq(true, exec_lua('return _G.result'))
      end)
    end)

    it('includes cursor position #31609', function()
      command('autocmd! nvim.terminal TermRequest')
      local screen = Screen.new(50, 10)
      local term = exec_lua([[
        _G.cursor = {}
        local term = vim.api.nvim_open_term(0, {})
        vim.api.nvim_create_autocmd('TermRequest', {
          callback = function(args)
            _G.cursor = args.data.cursor
          end
        })
        return term
      ]])
      -- Enter terminal mode so that the cursor follows the output
      feed('a')

      -- Put some lines into the scrollback. This tests the conversion from terminal line to buffer
      -- line.
      api.nvim_chan_send(term, string.rep('>\n', 20))
      screen:expect([[
        >                                                 |*8
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])

      -- Emit an OSC escape sequence
      api.nvim_chan_send(term, 'Hello\nworld!\027]133;D\027\\')
      screen:expect([[
        >                                                 |*7
        Hello                                             |
        world!^                                            |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 22, 6 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, '\nHello\027]133;D\027\\\nworld!\n')
      screen:expect([[
        >                                                 |*4
        Hello                                             |
        world!                                            |
        Hello                                             |
        world!                                            |
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 23, 5 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, 'Hello\027]133;D\027\\\nworld!' .. ('\n'):rep(6))
      screen:expect([[
        world!                                            |
        Hello                                             |
        world!                                            |
                                                          |*5
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 25, 5 }, exec_lua('return _G.cursor'))

      api.nvim_set_option_value('scrollback', 10, {})
      eq(19, api.nvim_buf_line_count(0))

      api.nvim_chan_send(term, 'Hello\nworld!\027]133;D\027\\')
      screen:expect([[
        Hello                                             |
        world!                                            |
                                                          |*5
        Hello                                             |
        world!^                                            |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 19, 6 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, '\nHello\027]133;D\027\\\nworld!\n')
      screen:expect([[
                                                          |*4
        Hello                                             |
        world!                                            |
        Hello                                             |
        world!                                            |
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 17, 5 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, 'Hello\027]133;D\027\\\nworld!' .. ('\n'):rep(6))
      screen:expect([[
        world!                                            |
        Hello                                             |
        world!                                            |
                                                          |*5
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 12, 5 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, 'Hello\027]133;D\027\\\nworld!' .. ('\n'):rep(8))
      screen:expect([[
        world!                                            |
                                                          |*7
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ 10, 5 }, exec_lua('return _G.cursor'))

      api.nvim_chan_send(term, 'Hello\027]133;D\027\\\nworld!' .. ('\n'):rep(20))
      screen:expect([[
                                                          |*8
        ^                                                  |
        {5:-- TERMINAL --}                                    |
      ]])
      eq({ -2, 5 }, exec_lua('return _G.cursor'))
    end)

    it('does not cause hang in vim.wait() #32753', function()
      local screen = Screen.new(50, 10)

      exec_lua(function()
        local term = vim.api.nvim_open_term(0, {})

        -- Write OSC sequence with pending scrollback. TermRequest will
        -- reschedule itself onto an event queue until the pending scrollback is
        -- processed (i.e. the terminal is refreshed).
        vim.api.nvim_chan_send(term, string.format('%s\027]133;;\007', string.rep('a\n', 100)))

        -- vim.wait() drains the event queue. The terminal won't be refreshed
        -- until the event queue is empty. This test ensures that TermRequest
        -- does not continuously reschedule itself onto the same event queue,
        -- causing an infinite loop.
        vim.wait(100)
      end)

      screen:expect([[
        ^a                                                 |
        a                                                 |*8
                                                          |
      ]])
    end)

    describe('no heap-use-after-free after', function()
      local term

      before_each(function()
        term = exec_lua(function()
          vim.api.nvim_create_autocmd('TermRequest', { callback = function() end })
          return vim.api.nvim_open_term(0, {})
        end)
      end)

      it('wiping buffer with pending TermRequest #37226', function()
        exec_lua(function()
          vim.api.nvim_chan_send(term, '\027]8;;https://example.com\027\\')
          vim.api.nvim_buf_delete(0, { force = true })
        end)
        assert_alive()
      end)

      it('unloading buffer with pending TermRequest #37226', function()
        api.nvim_create_buf(true, false) -- Create a buffer to switch to.
        exec_lua(function()
          vim.api.nvim_chan_send(term, '\027]8;;https://example.com\027\\')
          vim.api.nvim_buf_delete(0, { force = true, unload = true })
        end)
        assert_alive()
      end)
    end)
  end)

  it('no heap-buffer-overflow when using jobstart("echo",{term=true}) #3161', function()
    local testfilename = 'Xtestfile-functional-terminal-buffers_spec'
    write_file(testfilename, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    finally(function()
      os.remove(testfilename)
    end)
    feed_command('edit ' .. testfilename)
    -- Move cursor away from the beginning of the line
    feed('$')
    -- Let jobstart(…,{term=true}) modify the buffer
    feed_command([[call jobstart("echo", {'term':v:true})]])
    assert_alive()
    feed_command('bdelete!')
  end)

  it('no heap-buffer-overflow when sending long line with nowrap #11548', function()
    feed_command('set nowrap')
    feed_command('autocmd TermOpen * startinsert')
    feed_command('call feedkeys("4000ai\\<esc>:terminal!\\<cr>")')
    assert_alive()
  end)

  it('truncates the size of grapheme clusters', function()
    local chan = api.nvim_open_term(0, {})
    local composing = ('a̳'):sub(2)
    api.nvim_chan_send(chan, 'a' .. composing:rep(20))
    retry(nil, nil, function()
      eq('a' .. composing:rep(14), api.nvim_get_current_line())
    end)
  end)

  it('handles extended grapheme clusters', function()
    local screen = Screen.new(50, 7)
    feed 'i'
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '🏴‍☠️ yarrr')
    screen:expect([[
      🏴‍☠️ yarrr^                                          |
                                                        |*5
      {5:-- TERMINAL --}                                    |
    ]])
    eq('🏴‍☠️ yarrr', api.nvim_get_current_line())
  end)

  it('handles split UTF-8 sequences #16245', function()
    local screen = Screen.new(50, 7)
    fn.jobstart({ testprg('shell-test'), 'UTF-8' }, { term = true })
    screen:expect([[
      ^å                                                 |
      ref: å̲                                            |
      1: å̲                                              |
      2: å̲                                              |
      3: å̲                                              |
                                                        |*2
    ]])
  end)

  --- @param subcmd 'REP'|'REPFAST'
  local function check_term_rep(subcmd, count)
    local screen = Screen.new(50, 7)
    api.nvim_create_autocmd('TermClose', { command = 'let g:did_termclose = 1' })
    fn.jobstart({ testprg('shell-test'), subcmd, count, 'TEST' }, { term = true })
    retry(nil, nil, function()
      eq(1, api.nvim_get_var('did_termclose'))
    end)
    feed('i')
    screen:expect(([[
      %d: TEST{MATCH: +}|
      %d: TEST{MATCH: +}|
      %d: TEST{MATCH: +}|
      %d: TEST{MATCH: +}|
                                                        |
      [Process exited 0]^                                |
      {5:-- TERMINAL --}                                    |
    ]]):format(count - 4, count - 3, count - 2, count - 1))
    local lines = api.nvim_buf_get_lines(0, 0, -1, true)
    for i = 1, count do
      eq(('%d: TEST'):format(i - 1), lines[i])
    end
  end

  it('does not drop data when job exits immediately after output #3030', function()
    api.nvim_set_option_value('scrollback', 30000, {})
    check_term_rep('REPFAST', 20000)
  end)

  it('does not drop data when autocommands poll for events #37559', function()
    api.nvim_set_option_value('scrollback', 30000, {})
    api.nvim_create_autocmd('BufFilePre', { command = 'sleep 50m', nested = true })
    api.nvim_create_autocmd('BufFilePost', { command = 'sleep 50m', nested = true })
    api.nvim_create_autocmd('TermOpen', { command = 'sleep 50m', nested = true })
    -- REP pauses 1 ms every 100 lines, so each autocommand processes some output.
    check_term_rep('REP', 20000)
  end)

  describe('scrollback is correct if all output is drained by', function()
    for _, event in ipairs({ 'BufFilePre', 'BufFilePost', 'TermOpen' }) do
      describe(('%s autocommand that lasts for'):format(event), function()
        for _, delay in ipairs({ 5, 15, 25 }) do
          -- Terminal refresh delay is 10 ms.
          it(('%.1f * terminal refresh delay'):format(delay / 10), function()
            local cmd = ('sleep %dm'):format(delay)
            api.nvim_create_autocmd(event, { command = cmd, nested = true })
            check_term_rep('REPFAST', 200)
          end)
        end
      end)
    end
  end)

  it('handles unprintable chars', function()
    local screen = Screen.new(50, 7)
    feed 'i'
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '\239\187\191') -- '\xef\xbb\xbf'
    screen:expect([[
      {18:<feff>}^                                            |
                                                        |*5
      {5:-- TERMINAL --}                                    |
    ]])
    eq('\239\187\191', api.nvim_get_current_line())
  end)

  it("handles bell respecting 'belloff' and 'visualbell'", function()
    local screen = Screen.new(50, 7)
    local chan = api.nvim_open_term(0, {})

    command('set belloff=')
    api.nvim_chan_send(chan, '\a')
    screen:expect(function()
      eq({ true, false }, { screen.bell, screen.visual_bell })
    end)
    screen.bell = false

    command('set visualbell')
    api.nvim_chan_send(chan, '\a')
    screen:expect(function()
      eq({ false, true }, { screen.bell, screen.visual_bell })
    end)
    screen.visual_bell = false

    command('set belloff=term')
    api.nvim_chan_send(chan, '\a')
    screen:expect({
      condition = function()
        eq({ false, false }, { screen.bell, screen.visual_bell })
      end,
      unchanged = true,
    })

    command('set belloff=all')
    api.nvim_chan_send(chan, '\a')
    screen:expect({
      condition = function()
        eq({ false, false }, { screen.bell, screen.visual_bell })
      end,
      unchanged = true,
    })
  end)

  it('does not wipeout unrelated buffer after channel closes', function()
    local screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Blue1, bold = true },
      [2] = { reverse = true },
      [31] = { background = Screen.colors.DarkGreen, foreground = Screen.colors.White, bold = true },
    })

    local old_buf = api.nvim_get_current_buf()
    command('new')
    fn.chanclose(api.nvim_open_term(0, {}))
    local term_buf = api.nvim_get_current_buf()
    screen:expect([[
      ^                                                  |
      [Terminal closed]                                 |
      {31:[Scratch] [-]                                     }|
                                                        |
      {1:~                                                 }|
      {2:[No Name]                                         }|
                                                        |
    ]])

    -- Autocommand should not result in the wrong buffer being wiped out.
    command('autocmd TermLeave * ++once wincmd p')
    feed('ii')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*5
                                                        |
    ]])
    eq(old_buf, api.nvim_get_current_buf())
    eq(false, api.nvim_buf_is_valid(term_buf))

    term_buf = api.nvim_get_current_buf()
    fn.chanclose(api.nvim_open_term(term_buf, {}))
    screen:expect([[
      ^                                                  |
      [Terminal closed]                                 |
                                                        |*5
    ]])

    -- Autocommand should not result in a heap UAF if it frees the terminal prematurely.
    command('autocmd TermLeave * ++once bwipeout!')
    feed('ii')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*5
                                                        |
    ]])
    eq(false, api.nvim_buf_is_valid(term_buf))
  end)

  local enew_screen = [[
    ^                                                  |
    {1:~                                                 }|*5
                                                      |
  ]]

  local function test_enew_in_buf_with_running_term(env)
    describe('editing a new file', function()
      it('hides terminal buffer ignoring bufhidden=wipe', function()
        local old_snapshot = env.screen:get_snapshot()
        command('setlocal bufhidden=wipe')
        command('enew')
        neq(env.buf, api.nvim_get_current_buf())
        env.screen:expect(enew_screen)
        feed('<C-^>')
        eq(env.buf, api.nvim_get_current_buf())
        env.screen:expect(old_snapshot)
      end)
    end)
  end

  local function test_open_term_in_buf_with_running_term(env)
    describe('does not allow opening another terminal', function()
      it('with jobstart() in same buffer', function()
        eq(
          ('Vim:Terminal already connected to buffer %d'):format(env.buf),
          pcall_err(fn.jobstart, { testprg('tty-test') }, { term = true })
        )
        env.screen:expect_unchanged()
      end)

      it('with nvim_open_term() in same buffer', function()
        eq(
          ('Terminal already connected to buffer %d'):format(env.buf),
          pcall_err(api.nvim_open_term, env.buf, {})
        )
        env.screen:expect_unchanged()
      end)
    end)
  end

  describe('with running terminal job', function()
    local env = {}

    before_each(function()
      env.screen = Screen.new(50, 7)
      fn.jobstart({ testprg('tty-test') }, { term = true })
      env.screen:expect([[
        ^tty ready                                         |
                                                          |*6
      ]])
      env.buf = api.nvim_get_current_buf()
      api.nvim_set_option_value('modified', false, { buf = env.buf })
    end)

    test_enew_in_buf_with_running_term(env)
    test_open_term_in_buf_with_running_term(env)
  end)

  describe('with open nvim_open_term() channel', function()
    local env = {}

    before_each(function()
      env.screen = Screen.new(50, 7)
      local chan = api.nvim_open_term(0, {})
      api.nvim_chan_send(chan, 'TEST')
      env.screen:expect([[
        ^TEST                                              |
                                                          |*6
      ]])
      env.buf = api.nvim_get_current_buf()
      api.nvim_set_option_value('modified', false, { buf = env.buf })
    end)

    test_enew_in_buf_with_running_term(env)
    test_open_term_in_buf_with_running_term(env)
  end)

  local function test_enew_in_buf_with_finished_term(env)
    describe('editing a new file', function()
      it('hides terminal buffer with bufhidden=hide', function()
        local old_snapshot = env.screen:get_snapshot()
        command('setlocal bufhidden=hide')
        command('enew')
        neq(env.buf, api.nvim_get_current_buf())
        env.screen:expect(enew_screen)
        feed('<C-^>')
        eq(env.buf, api.nvim_get_current_buf())
        env.screen:expect(old_snapshot)
      end)

      it('wipes terminal buffer with bufhidden=wipe', function()
        command('setlocal bufhidden=wipe')
        command('enew')
        neq(env.buf, api.nvim_get_current_buf())
        eq(false, api.nvim_buf_is_valid(env.buf))
        env.screen:expect(enew_screen)
        feed('<C-^>')
        env.screen:expect([[
          ^                                                  |
          {1:~                                                 }|*5
          {9:E23: No alternate file}                            |
        ]])
      end)
    end)
  end

  local function test_open_term_in_buf_with_finished_term(env)
    describe('does not leak memory when opening another terminal', function()
      describe('with jobstart() in same buffer', function()
        it('in Normal mode', function()
          fn.jobstart({ testprg('tty-test') }, { term = true })
          env.screen:expect([[
            ^tty ready                                         |
                                                              |*6
          ]])
        end)

        it('in Terminal mode', function()
          feed('i')
          eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
          fn.jobstart({ testprg('tty-test') }, { term = true })
          env.screen:expect([[
            tty ready                                         |
            ^                                                  |
                                                              |*4
            {5:-- TERMINAL --}                                    |
          ]])
        end)
      end)

      describe('with nvim_open_term() in same buffer', function()
        it('in Normal mode', function()
          local chan = api.nvim_open_term(env.buf, {})
          api.nvim_chan_send(chan, 'OTHER')
          env.screen:expect([[
            ^OTHER                                             |
                                                              |*6
          ]])
        end)

        it('in Terminal mode', function()
          feed('i')
          eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
          local chan = api.nvim_open_term(env.buf, {})
          api.nvim_chan_send(chan, 'OTHER')
          env.screen:expect([[
            OTHER^                                             |
                                                              |*5
            {5:-- TERMINAL --}                                    |
          ]])
        end)
      end)
    end)
  end

  describe('with exited terminal job', function()
    local env = {}

    before_each(function()
      env.screen = Screen.new(50, 7)
      fn.jobstart({ testprg('shell-test') }, { term = true })
      env.screen:expect([[
        ^ready $                                           |
        [Process exited 0]                                |
                                                          |*5
      ]])
      env.buf = api.nvim_get_current_buf()
      api.nvim_set_option_value('modified', false, { buf = env.buf })
    end)

    test_enew_in_buf_with_finished_term(env)
    test_open_term_in_buf_with_finished_term(env)
  end)

  describe('with closed nvim_open_term() channel', function()
    local env = {}

    before_each(function()
      env.screen = Screen.new(50, 7)
      local chan = api.nvim_open_term(0, {})
      api.nvim_chan_send(chan, 'TEST')
      fn.chanclose(chan)
      env.screen:expect([[
        ^TEST                                              |
        [Terminal closed]                                 |
                                                          |*5
      ]])
      env.buf = api.nvim_get_current_buf()
      api.nvim_set_option_value('modified', false, { buf = env.buf })
    end)

    test_enew_in_buf_with_finished_term(env)
    test_open_term_in_buf_with_finished_term(env)
  end)

  it('with nvim_open_term() channel and only 1 line is not reused by :enew', function()
    command('1new')
    local oldbuf = api.nvim_get_current_buf()
    api.nvim_open_term(oldbuf, {})
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
    feed('i')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed([[<C-\><C-N>]])
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())

    command('enew')
    neq(oldbuf, api.nvim_get_current_buf())
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    feed('i')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
    feed('<Esc>')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())

    command('buffer #')
    eq(oldbuf, api.nvim_get_current_buf())
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
    feed('i')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed([[<C-\><C-N>]])
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
  end)

  it('does not allow b:term_title watcher to delete buffer', function()
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '\027]2;SOME_TITLE\007')
    eq('SOME_TITLE', api.nvim_buf_get_var(0, 'term_title'))
    command([[call dictwatcheradd(b:, 'term_title', {-> execute('bwipe!')})]])
    api.nvim_chan_send(chan, '\027]2;OTHER_TITLE\007')
    eq('OTHER_TITLE', api.nvim_buf_get_var(0, 'term_title'))
    matches('^E937: ', api.nvim_get_vvar('errmsg'))
  end)

  it('using NameBuff in BufFilePre does not interfere with buffer rename', function()
    local oldbuf = api.nvim_get_current_buf()
    n.exec([[
      file Xoldfile
      new Xotherfile
      wincmd w
      let g:BufFilePre_bufs = []
      let g:BufFilePost_bufs = []
      autocmd BufFilePre * call add(g:BufFilePre_bufs, [bufnr(), bufname()])
      autocmd BufFilePost * call add(g:BufFilePost_bufs, [bufnr(), bufname()])
      autocmd BufFilePre,BufFilePost * call execute('ls')
    ]])
    fn.jobstart({ testprg('shell-test') }, { term = true })
    eq({ { oldbuf, 'Xoldfile' } }, api.nvim_get_var('BufFilePre_bufs'))
    local buffilepost_bufs = api.nvim_get_var('BufFilePost_bufs')
    eq(1, #buffilepost_bufs)
    eq(oldbuf, buffilepost_bufs[1][1])
    matches('^term://', buffilepost_bufs[1][2])
  end)
end)

describe('on_lines does not emit out-of-bounds line indexes when', function()
  before_each(function()
    clear()
    exec_lua([[
      function _G.register_callback(bufnr)
        _G.cb_error = ''
        vim.api.nvim_buf_attach(bufnr, false, {
          on_lines = function(_, bufnr, _, firstline, _, _)
            local status, msg = pcall(vim.api.nvim_buf_get_offset, bufnr, firstline)
            if not status then
              _G.cb_error = msg
            end
          end
        })
      end
    ]])
  end)

  it('creating a terminal buffer #16394', function()
    feed_command('autocmd TermOpen * ++once call v:lua.register_callback(str2nr(expand("<abuf>")))')
    feed_command('terminal')
    sleep(500)
    eq('', exec_lua([[return _G.cb_error]]))
  end)

  it('deleting a terminal buffer #16394', function()
    feed_command('terminal')
    sleep(500)
    feed_command('lua _G.register_callback(0)')
    feed_command('bdelete!')
    eq('', exec_lua([[return _G.cb_error]]))
  end)
end)

describe('terminal input', function()
  local chan --- @type integer

  before_each(function()
    clear()
    chan = exec_lua(function()
      _G.input_data = ''
      return vim.api.nvim_open_term(0, {
        on_input = function(_, _, _, data)
          _G.input_data = _G.input_data .. data
        end,
      })
    end)
    feed('i')
    poke_eventloop()
  end)

  it('<C-Space> is sent as NUL byte', function()
    feed('aaa<C-Space>bbb')
    eq('aaa\0bbb', exec_lua([[return _G.input_data]]))
  end)

  it('unknown special keys are not sent', function()
    feed('aaa<Help>bbb')
    eq('aaabbb', exec_lua([[return _G.input_data]]))
  end)

  it('<Ignore> is no-op', function()
    feed('aaa<Ignore>bbb')
    eq('aaabbb', exec_lua([[return _G.input_data]]))
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed([[<C-\><Ignore><C-N>]])
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
    feed('v')
    eq({ mode = 'v', blocking = false }, api.nvim_get_mode())
    feed('<Esc>')
    eq({ mode = 'nt', blocking = false }, api.nvim_get_mode())
    feed('i')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed([[<C-\><Ignore><C-O>]])
    eq({ mode = 'ntT', blocking = false }, api.nvim_get_mode())
    feed('v')
    eq({ mode = 'v', blocking = false }, api.nvim_get_mode())
    feed('<Esc>')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    fn.chanclose(chan)
    feed('<MouseMove>')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    feed('<Ignore>')
    eq({ mode = 't', blocking = false }, api.nvim_get_mode())
    eq('terminal', api.nvim_get_option_value('buftype', { buf = 0 }))
    feed('<Space>')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    eq('', api.nvim_get_option_value('buftype', { buf = 0 }))
  end)
end)

describe('terminal input', function()
  it('sends various special keys with modifiers', function()
    clear()
    local screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set notermguicolors',
      '-c',
      'while 1 | redraw | echo keytrans(getcharstr(-1, #{simplify: 0})) | endwhile',
    })
    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*3
      {3:[No Name]                       0,0-1          All}|
                                                        |
      {5:-- TERMINAL --}                                    |
    ]])
    local keys = {
      '<Tab>',
      '<CR>',
      '<Esc>',
      '<M-Tab>',
      '<M-CR>',
      '<M-Esc>',
      '<BS>',
      '<S-Tab>',
      '<Insert>',
      '<Del>',
      '<PageUp>',
      '<PageDown>',
      '<S-Up>',
      '<C-Up>',
      '<Up>',
      '<S-Down>',
      '<C-Down>',
      '<Down>',
      '<S-Left>',
      '<C-Left>',
      '<Left>',
      '<S-Right>',
      '<C-Right>',
      '<Right>',
      '<S-Home>',
      '<C-Home>',
      '<Home>',
      '<S-End>',
      '<C-End>',
      '<End>',
      '<C-LeftMouse><0,0>',
      '<C-LeftDrag><0,1>',
      '<C-LeftRelease><0,1>',
      '<2-LeftMouse><0,1>',
      '<2-LeftDrag><0,0>',
      '<2-LeftRelease><0,0>',
      '<M-MiddleMouse><0,0>',
      '<M-MiddleDrag><0,1>',
      '<M-MiddleRelease><0,1>',
      '<2-MiddleMouse><0,1>',
      '<2-MiddleDrag><0,0>',
      '<2-MiddleRelease><0,0>',
      '<S-RightMouse><0,0>',
      '<S-RightDrag><0,1>',
      '<S-RightRelease><0,1>',
      '<2-RightMouse><0,1>',
      '<2-RightDrag><0,0>',
      '<2-RightRelease><0,0>',
      '<S-X1Mouse><0,0>',
      '<S-X1Drag><0,1>',
      '<S-X1Release><0,1>',
      '<2-X1Mouse><0,1>',
      '<2-X1Drag><0,0>',
      '<2-X1Release><0,0>',
      '<S-X2Mouse><0,0>',
      '<S-X2Drag><0,1>',
      '<S-X2Release><0,1>',
      '<2-X2Mouse><0,1>',
      '<2-X2Drag><0,0>',
      '<2-X2Release><0,0>',
      '<S-ScrollWheelUp>',
      '<S-ScrollWheelDown>',
      '<ScrollWheelUp>',
      '<ScrollWheelDown>',
      '<S-ScrollWheelLeft>',
      '<S-ScrollWheelRight>',
      '<ScrollWheelLeft>',
      '<ScrollWheelRight>',
    }
    -- FIXME: The escape sequence to enable kitty keyboard mode doesn't work on Windows
    if not is_os('win') then
      table.insert(keys, '<C-I>')
      table.insert(keys, '<C-M>')
      table.insert(keys, '<C-[>')
    end
    for _, key in ipairs(keys) do
      feed(key)
      screen:expect(([[
                                                          |
        {100:~                                                 }|*3
        {3:[No Name]                       0,0-1          All}|
        %s^ {MATCH: *}|
        {5:-- TERMINAL --}                                    |
      ]]):format(key:gsub('<%d+,%d+>$', '')))
    end
  end)
end)

if is_os('win') then
  describe(':terminal in Windows', function()
    local screen

    before_each(function()
      clear()
      feed_command('set modifiable swapfile undolevels=20')
      poke_eventloop()
      local cmd = { 'cmd.exe', '/K', 'PROMPT=$g$s' }
      screen = tt.setup_screen(nil, cmd)
    end)

    it('"put" operator sends data normally', function()
      feed('<c-\\><c-n>G')
      feed_command('let @a = ":: tty ready"')
      feed_command('let @a = @a . "\\n:: appended " . @a . "\\n\\n"')
      feed('"ap"ap')
      screen:expect([[
                                                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      ^>                                                 |
      :let @a = @a . "\n:: appended " . @a . "\n\n"     |
      ]])
      -- operator count is also taken into consideration
      feed('3"ap')
      screen:expect([[
      > :: appended :: tty ready                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      ^>                                                 |
      :let @a = @a . "\n:: appended " . @a . "\n\n"     |
      ]])
    end)

    it('":put" command sends data normally', function()
      feed('<c-\\><c-n>G')
      feed_command('let @a = ":: tty ready"')
      feed_command('let @a = @a . "\\n:: appended " . @a . "\\n\\n"')
      feed_command('put a')
      screen:expect([[
                                                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      >                                                 |
                                                        |
      ^                                                  |
      :put a                                            |
      ]])
      -- line argument is only used to move the cursor
      feed_command('6put a')
      screen:expect([[
                                                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      > :: tty ready                                    |
      > :: appended :: tty ready                        |
      ^>                                                 |
      :6put a                                           |
      ]])
    end)
  end)
end

describe('termopen() (deprecated alias to `jobstart(…,{term=true})`)', function()
  before_each(clear)

  it('disallowed when textlocked and in cmdwin buffer', function()
    command("autocmd TextYankPost <buffer> ++once call termopen('foo')")
    matches(
      'Vim%(call%):E565: Not allowed to change text or change window$',
      pcall_err(command, 'normal! yy')
    )

    feed('q:')
    eq(
      'Vim:E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
      pcall_err(fn.termopen, 'bar')
    )
  end)
end)

describe('jobstart(…,{term=true})', function()
  before_each(clear)

  describe('$COLORTERM value', function()
    before_each(function()
      -- Outer value should never be propagated to :terminal
      fn.setenv('COLORTERM', 'wrongvalue')
    end)

    local function test_term_colorterm(expected, opts)
      local screen = Screen.new(50, 4)
      fn.jobstart({
        nvim_prog,
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--headless',
        '-c',
        'echo $COLORTERM | quit',
      }, vim.tbl_extend('error', opts, { term = true }))
      screen:expect(([[
        ^%s{MATCH:%%s+}|
        [Process exited 0]                                |
                                                          |*2
      ]]):format(expected))
    end

    describe("with 'notermguicolors'", function()
      before_each(function()
        command('set notermguicolors')
      end)
      it('is empty by default', function()
        test_term_colorterm('', {})
      end)
      it('can be overridden', function()
        test_term_colorterm('expectedvalue', { env = { COLORTERM = 'expectedvalue' } })
      end)
    end)

    describe("with 'termguicolors'", function()
      before_each(function()
        command('set termguicolors')
      end)
      it('is "truecolor" by default', function()
        test_term_colorterm('truecolor', {})
      end)
      it('can be overridden', function()
        test_term_colorterm('expectedvalue', { env = { COLORTERM = 'expectedvalue' } })
      end)
    end)
  end)
end)
