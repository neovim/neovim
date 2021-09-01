local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local assert_alive = helpers.assert_alive
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local poke_eventloop = helpers.poke_eventloop
local eval, feed_command, source = helpers.eval, helpers.feed_command, helpers.source
local eq, neq = helpers.eq, helpers.neq
local write_file = helpers.write_file
local command= helpers.command
local exc_exec = helpers.exc_exec
local matches = helpers.matches

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
    command('setlocal cursorline cursorcolumn scrolloff=4 sidescrolloff=7')
    eq({ 1, 1, 4, 7 }, eval('[&l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]'))
    eq('n', eval('mode()'))

    -- Enter terminal-mode ("insert" mode in :terminal).
    feed('i')
    eq('t', eval('mode()'))
    eq({ 0, 0, 0, 0 }, eval('[&l:cursorline, &l:cursorcolumn, &l:scrolloff, &l:sidescrolloff]'))
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
    local exitcmd = helpers.iswin()
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

  it('does not segfault when pasting empty buffer #13955', function()
    feed_command('terminal')
    feed('<c-\\><c-n>')
    feed_command('put a') -- buffer a is empty
    helpers.assert_alive()
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
