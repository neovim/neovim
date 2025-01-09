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
    feed([[<C-\><C-N>]])
    command('setlocal cursorline cursorlineopt=both cursorcolumn scrolloff=4 sidescrolloff=7')
    eq(
      { 'both', 1, 1, 4, 7 },
      eval('[&l:cursorlineopt, &l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]')
    )
    eq('nt', eval('mode(1)'))

    -- Enter terminal-mode ("insert" mode in :terminal).
    feed('i')
    eq('t', eval('mode(1)'))
    eq(
      { 'number', 1, 0, 0, 0 },
      eval('[&l:cursorlineopt, &l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]')
    )
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

  describe('when a new file is edited', function()
    before_each(function()
      feed('<c-\\><c-n>:set bufhidden=wipe<cr>:enew<cr>')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*5
        :enew                                             |
      ]])
    end)

    it('will hide the buffer, ignoring the bufhidden option', function()
      feed(':bnext:l<esc>')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*5
                                                          |
      ]])
    end)
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
      local swapfile = api.nvim_exec('swapname', true):gsub('\n', '')
      eq(nil, io.open(swapfile))
    end)

    it('does not create undofiles files', function()
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
      {8:E21: Cannot make changes, 'modifiable' is off}     |
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
      {4:~                                                 }|*5
      :bd!                                              |
    ]])
    feed_command('bnext')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*5
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
      {4:~                                                 }|
      {5:==========                                        }|
      rows: 2, cols: 50                                 |
                                                        |
      {18:==========                                        }|
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
      {3:-- TERMINAL --}                                    |
    ]])
    command('bdelete!')
  end)

  it('requires bang (!) to close a running job #15402', function()
    skip(is_os('win'), 'Test freezes the CI and makes it time out')
    eq('Vim(wqall):E948: Job still running', exc_exec('wqall'))
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
    screen:expect {
      grid = [[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {3:-- (terminal) --}                                  |
    ]],
    }
    eq('ntT', fn.mode(1))

    feed [[:let g:x = 17]]
    screen:expect {
      grid = [[
      tty ready                                         |
                                                        |
                                                        |*4
      :let g:x = 17^                                     |
    ]],
    }

    feed [[<cr>]]
    screen:expect {
      grid = [[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {3:-- TERMINAL --}                                    |
    ]],
    }
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
end)

describe(':terminal buffer', function()
  before_each(clear)

  it('term_close() use-after-free #4393', function()
    command('terminal yes')
    feed('<Ignore>') -- Add input to separate two RPC requests
    command('bdelete!')
  end)

  it('emits TermRequest events #26972', function()
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

  it('TermRequest synchronization #27572', function()
    command('autocmd! nvim_terminal TermRequest')
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
          if args.data == '\027]11;?' then
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
  before_each(function()
    clear()
    exec_lua([[
      _G.input_data = ''
      vim.api.nvim_open_term(0, { on_input = function(_, _, _, data)
        _G.input_data = _G.input_data .. data
      end })
    ]])
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
      'while 1 | redraw | echo keytrans(getcharstr()) | endwhile',
    })
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                       0,0-1          All}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    for _, key in ipairs({
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
      '<C-LeftMouse>',
      '<C-LeftRelease>',
      '<2-LeftMouse>',
      '<2-LeftRelease>',
      '<S-RightMouse>',
      '<S-RightRelease>',
      '<2-RightMouse>',
      '<2-RightRelease>',
      '<M-MiddleMouse>',
      '<M-MiddleRelease>',
      '<2-MiddleMouse>',
      '<2-MiddleRelease>',
      '<S-ScrollWheelUp>',
      '<S-ScrollWheelDown>',
      '<ScrollWheelUp>',
      '<ScrollWheelDown>',
      '<S-ScrollWheelLeft>',
      '<S-ScrollWheelRight>',
      '<ScrollWheelLeft>',
      '<ScrollWheelRight>',
    }) do
      feed(key)
      screen:expect(([[
                                                          |
        {4:~                                                 }|*3
        {5:[No Name]                       0,0-1          All}|
        %s^ {MATCH: *}|
        {3:-- TERMINAL --}                                    |
      ]]):format(key))
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

  describe('$COLORTERM value', function()
    if skip(is_os('win'), 'Not applicable for Windows') then
      return
    end

    before_each(function()
      -- Outer value should never be propagated to :terminal
      fn.setenv('COLORTERM', 'wrongvalue')
    end)

    local function test_term_colorterm(expected, opts)
      local screen = Screen.new(50, 4)
      fn.termopen({
        nvim_prog,
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--headless',
        '-c',
        'echo $COLORTERM | quit',
      }, opts)
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
        test_term_colorterm('')
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
        test_term_colorterm('truecolor')
      end)
      it('can be overridden', function()
        test_term_colorterm('expectedvalue', { env = { COLORTERM = 'expectedvalue' } })
      end)
    end)
  end)
end)
