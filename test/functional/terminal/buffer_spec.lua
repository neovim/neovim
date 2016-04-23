local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local wait = helpers.wait
local eval, execute, source = helpers.eval, helpers.execute, helpers.source
local eq, neq = helpers.eq, helpers.neq


describe('terminal buffer', function()
  local screen

  before_each(function()
    clear()
    execute('set modifiable swapfile undolevels=20')
    wait()
    screen = thelpers.screen_setup()
  end)

  describe('when a new file is edited', function()
    before_each(function()
      feed('<c-\\><c-n>:set bufhidden=wipe<cr>:enew<cr>')
      screen:expect([[
        ^                                                  |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        :enew                                             |
      ]])
    end)

    it('will hide the buffer, ignoring the bufhidden option', function()
      feed(':bnext:l<esc>')
      screen:expect([[
        ^                                                  |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        ~                                                 |
                                                          |
      ]])
    end)
  end)

  describe('swap and undo', function()
    before_each(function()
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        {2: }                                                 |
                                                          |
                                                          |
                                                          |
        ^                                                  |
                                                          |
      ]])
    end)

    it('does not create swap files', function()
      local swapfile = nvim('command_output', 'swapname'):gsub('\n', '')
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
      {2: }                                                 |
                                                        |
                                                        |
                                                        |
      ^                                                  |
      E21: Cannot make changes, 'modifiable' is off     |
    ]])
  end)

  it('sends data to the terminal when the "put" operator is used', function()
    feed('<c-\\><c-n>gg"ayj')
    execute('let @a = "appended " . @a')
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
    execute('let @a = "appended " . @a')
    execute('put a')
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
    execute('6put a')
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
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      :bd!                                              |
    ]])
    execute('bnext')
    screen:expect([[
      ^                                                  |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      :bnext                                            |
    ]])
  end)

  it('handles loss of focus gracefully', function()
    -- Temporarily change the statusline to avoid printing the file name, which
    -- varies be where the test is run.
    nvim('set_option', 'statusline', '==========')
    execute('set laststatus=0')

    -- Save the buffer number of the terminal for later testing.
    local tbuf = eval('bufnr("%")')

    source([[
    function! SplitWindow()
      new
      call feedkeys("iabc\<Esc>")
    endfunction

    startinsert
    call jobstart(['sh', '-c', 'exit'], {'on_exit': function("SplitWindow")})
    call feedkeys("\<C-\>", 't')  " vim will expect <C-n>, but be exited out of
                                  " the terminal before it can be entered.
    ]])

    -- We should be in a new buffer now.
    screen:expect([[
      ab^c                                               |
      ~                                                 |
      ==========                                        |
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {1:==========                                        }|
                                                        |
    ]])

    neq(tbuf, eval('bufnr("%")'))
    execute('quit!')  -- Should exit the new window, not the terminal.
    eq(tbuf, eval('bufnr("%")'))

    execute('set laststatus=1')  -- Restore laststatus to the default.
  end)
end)

