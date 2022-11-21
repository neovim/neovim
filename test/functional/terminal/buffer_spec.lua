local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local assert_alive = helpers.assert_alive
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local poke_eventloop = helpers.poke_eventloop
local eval, feed_command, source = helpers.eval, helpers.feed_command, helpers.source
local pcall_err = helpers.pcall_err
local eq, neq = helpers.eq, helpers.neq
local meths = helpers.meths
local retry = helpers.retry
local write_file = helpers.write_file
local command = helpers.command
local exc_exec = helpers.exc_exec
local matches = helpers.matches
local exec_lua = helpers.exec_lua
local sleep = helpers.sleep
local funcs = helpers.funcs
local is_os = helpers.is_os
local skip = helpers.skip

describe(':terminal buffer', function()
  local screen

  before_each(function()
    clear()
    feed_command('set modifiable swapfile undolevels=20')
    poke_eventloop()
    screen = thelpers.screen_setup()
  end)

  it('terminal-mode forces various options', function()
    feed([[<C-\><C-N>]])
    command('setlocal cursorline cursorlineopt=both cursorcolumn scrolloff=4 sidescrolloff=7')
    eq({ 'both', 1, 1, 4, 7 }, eval('[&l:cursorlineopt, &l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]'))
    eq('nt', eval('mode(1)'))

    -- Enter terminal-mode ("insert" mode in :terminal).
    feed('i')
    eq('t', eval('mode(1)'))
    eq({ 'number', 1, 0, 0, 0 }, eval('[&l:cursorlineopt, &l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]'))
  end)

  it('terminal-mode does not change cursorlineopt if cursorline is disabled', function()
    feed([[<C-\><C-N>]])
    command('setlocal nocursorline cursorlineopt=both')
    feed('i')
    eq({ 0, 'both' }, eval('[&l:cursorline, &l:cursorlineopt]'))
  end)

  it('terminal-mode disables cursorline when cursorlineopt is only set to "line', function()
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
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        :enew                                             |
      ]])
    end)

    it('will hide the buffer, ignoring the bufhidden option', function()
      feed(':bnext:l<esc>')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
                                                          |
      ]])
    end)
  end)

  describe('swap and undo', function()
    before_each(function()
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        {2:^ }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
    end)

    it('does not create swap files', function()
      local swapfile = nvim('exec', 'swapname', true):gsub('\n', '')
      eq(nil, io.open(swapfile))
    end)

    it('does not create undofiles files', function()
      local undofile = nvim('eval', 'undofile(bufname("%"))')
      eq(nil, io.open(undofile))
    end)
  end)

  it('cannot be modified directly', function()
    feed('<c-\\><c-n>dd')
    screen:expect([[
      tty ready                                         |
      {2:^ }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {8:E21: Cannot make changes, 'modifiable' is off}     |
    ]])
  end)

  it('sends data to the terminal when the "put" operator is used', function()
    feed('<c-\\><c-n>gg"ayj')
    feed_command('let @a = "appended " . @a')
    feed('"ap"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      {2: }                                                 |
                                                        |
                                                        |
      :let @a = "appended " . @a                        |
    ]])
    -- operator count is also taken into consideration
    feed('3"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
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
      {2: }                                                 |
                                                        |
                                                        |
                                                        |
      :put a                                            |
    ]])
    -- line argument is only used to move the cursor
    feed_command('6put a')
    screen:expect([[
      tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      {2: }                                                 |
                                                        |
      ^                                                  |
      :6put a                                           |
    ]])
  end)

  it('can be deleted', function()
    feed('<c-\\><c-n>:bd!<cr>')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      :bd!                                              |
    ]])
    feed_command('bnext')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      :bnext                                            |
    ]])
  end)

  it('handles loss of focus gracefully', function()
    -- Change the statusline to avoid printing the file name, which varies.
    nvim('set_option', 'statusline', '==========')
    feed_command('set laststatus=0')

    -- Save the buffer number of the terminal for later testing.
    local tbuf = eval('bufnr("%")')
    local exitcmd = helpers.is_os('win')
      and "['cmd', '/c', 'exit']"
      or "['sh', '-c', 'exit']"
    source([[
    function! SplitWindow(id, data, event)
      new
      call feedkeys("iabc\<Esc>")
    endfunction

    startinsert
    call jobstart(]]..exitcmd..[[, {'on_exit': function("SplitWindow")})
    call feedkeys("\<C-\>", 't')  " vim will expect <C-n>, but be exited out of
                                  " the terminal before it can be entered.
    ]])

    -- We should be in a new buffer now.
    screen:expect([[
      ab^c                                               |
      {4:~                                                 }|
      {5:==========                                        }|
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {1:==========                                        }|
                                                        |
    ]])

    neq(tbuf, eval('bufnr("%")'))
    feed_command('quit!')  -- Should exit the new window, not the terminal.
    eq(tbuf, eval('bufnr("%")'))

    feed_command('set laststatus=1')  -- Restore laststatus to the default.
  end)

  it('term_close() use-after-free #4393', function()
    feed_command('terminal yes')
    feed([[<C-\><C-n>]])
    feed_command('bdelete!')
  end)

  describe('handles confirmations', function()
    it('with :confirm', function()
      feed_command('terminal')
      feed('<c-\\><c-n>')
      feed_command('confirm bdelete')
      screen:expect{any='Close "term://'}
    end)

    it('with &confirm', function()
      feed_command('terminal')
      feed('<c-\\><c-n>')
      feed_command('bdelete')
      screen:expect{any='E89'}
      feed('<cr>')
      eq('terminal', eval('&buftype'))
      feed_command('set confirm | bdelete')
      screen:expect{any='Close "term://'}
      feed('y')
      neq('terminal', eval('&buftype'))
    end)
  end)

  it('it works with set rightleft #11438', function()
    skip(is_os('win'))
    local columns = eval('&columns')
    feed(string.rep('a', columns))
    command('set rightleft')
    screen:expect([[
                                               ydaer ytt|
      {1:a}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    command('bdelete!')
  end)

  it('requires bang (!) to close a running job #15402', function()
    eq('Vim(wqall):E948: Job still running', exc_exec('wqall'))
    for _, cmd in ipairs({ 'bdelete', '%bdelete', 'bwipeout', 'bunload' }) do
      matches('^Vim%('..cmd:gsub('%%', '')..'%):E89: term://.*tty%-test.* will be killed %(add %! to override%)$',
        exc_exec(cmd))
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
    feed_command('put a')  -- register a is empty
    helpers.assert_alive()
  end)

  it([[can use temporary normal mode <c-\><c-o>]], function()
    eq('t', funcs.mode(1))
    feed [[<c-\><c-o>]]
    screen:expect{grid=[[
      tty ready                                         |
      {2:^ }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- (terminal) --}                                  |
    ]]}
    eq('ntT', funcs.mode(1))

    feed [[:let g:x = 17]]
    screen:expect{grid=[[
      tty ready                                         |
      {2: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      :let g:x = 17^                                     |
    ]]}

    feed [[<cr>]]
    screen:expect{grid=[[
      tty ready                                         |
      {1: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    eq('t', funcs.mode(1))
  end)

  it('writing to an existing file with :w fails #13549', function()
    eq('Vim(write):E13: File exists (add ! to override)',
       pcall_err(command, 'write test/functional/fixtures/tty-test.c'))
  end)
end)

describe('No heap-buffer-overflow when using', function()
  local testfilename = 'Xtestfile-functional-terminal-buffers_spec'

  before_each(function()
    write_file(testfilename, "aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  end)

  after_each(function()
    os.remove(testfilename)
  end)

  it('termopen(echo) #3161', function()
    feed_command('edit ' .. testfilename)
    -- Move cursor away from the beginning of the line
    feed('$')
    -- Let termopen() modify the buffer
    feed_command('call termopen("echo")')
    assert_alive()
    feed_command('bdelete!')
  end)
end)

describe('No heap-buffer-overflow when', function()
  it('set nowrap and send long line #11548', function()
    feed_command('set nowrap')
    feed_command('autocmd TermOpen * startinsert')
    feed_command('call feedkeys("4000ai\\<esc>:terminal!\\<cr>")')
    assert_alive()
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

  it('runs TextChangedT event', function()
    meths.set_var('called', 0)
    command('autocmd TextChangedT * ++once let g:called = 1')
    feed_command('terminal')
    feed('iaa')
    eq(1, meths.get_var('called'))
  end)
end)

it('terminal truncates number of composing characters to 5', function()
  clear()
  local chan = meths.open_term(0, {})
  local composing = ('a̳'):sub(2)
  meths.chan_send(chan, 'a' .. composing:rep(8))
  retry(nil, nil, function() eq('a' .. composing:rep(5), meths.get_current_line()) end)
end)
