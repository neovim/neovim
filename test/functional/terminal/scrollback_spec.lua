local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local clear, eq = n.clear, t.eq
local feed, testprg = n.feed, n.testprg
local eval = n.eval
local command = n.command
local poke_eventloop = n.poke_eventloop
local retry = t.retry
local api = n.api
local feed_data = tt.feed_data
local pcall_err = t.pcall_err
local exec_lua = n.exec_lua
local assert_alive = n.assert_alive
local skip = t.skip
local is_os = t.is_os

describe(':terminal scrollback', function()
  local screen

  before_each(function()
    clear()
    screen = tt.setup_screen(nil, nil, 30)
  end)

  describe('when the limit is exceeded', function()
    before_each(function()
      local lines = {}
      for i = 1, 30 do
        table.insert(lines, 'line' .. tostring(i))
      end
      table.insert(lines, '')
      feed_data(lines)
      screen:expect([[
        line26                        |
        line27                        |
        line28                        |
        line29                        |
        line30                        |
        {1: }                             |
        {3:-- TERMINAL --}                |
      ]])
    end)

    it('will delete extra lines at the top', function()
      feed('<c-\\><c-n>gg')
      screen:expect([[
        ^line16                        |
        line17                        |
        line18                        |
        line19                        |
        line20                        |
        line21                        |
                                      |
      ]])
    end)
  end)

  describe('with cursor at last row', function()
    before_each(function()
      feed_data({ 'line1', 'line2', 'line3', 'line4', '' })
      screen:expect([[
        tty ready                     |
        line1                         |
        line2                         |
        line3                         |
        line4                         |
        {1: }                             |
        {3:-- TERMINAL --}                |
      ]])
    end)

    describe('and 1 line is printed', function()
      before_each(function()
        feed_data({ 'line5', '' })
      end)

      it('will hide the top line', function()
        screen:expect([[
          line1                         |
          line2                         |
          line3                         |
          line4                         |
          line5                         |
          {1: }                             |
          {3:-- TERMINAL --}                |
        ]])
        eq(7, api.nvim_buf_line_count(0))
      end)

      describe('and then 3 more lines are printed', function()
        before_each(function()
          feed_data({ 'line6', 'line7', 'line8' })
        end)

        it('will hide the top 4 lines', function()
          screen:expect([[
            line3                         |
            line4                         |
            line5                         |
            line6                         |
            line7                         |
            line8{1: }                        |
            {3:-- TERMINAL --}                |
          ]])

          feed('<c-\\><c-n>6k')
          screen:expect([[
            ^line2                         |
            line3                         |
            line4                         |
            line5                         |
            line6                         |
            line7                         |
                                          |
          ]])

          feed('gg')
          screen:expect([[
            ^tty ready                     |
            line1                         |
            line2                         |
            line3                         |
            line4                         |
            line5                         |
                                          |
          ]])

          feed('G')
          screen:expect([[
            line3                         |
            line4                         |
            line5                         |
            line6                         |
            line7                         |
            ^line8{2: }                        |
                                          |
          ]])
        end)
      end)
    end)

    describe('and height decreased by 1', function()
      local function will_hide_top_line()
        feed([[<C-\><C-N>]])
        screen:try_resize(screen._width - 2, screen._height - 1)
        screen:expect([[
          line2                       |
          line3                       |
          line4                       |
          rows: 5, cols: 28           |
          {2:^ }                           |
                                      |
        ]])
      end

      it('will hide top line', will_hide_top_line)

      describe('and then decreased by 2', function()
        before_each(function()
          will_hide_top_line()
          screen:try_resize(screen._width - 2, screen._height - 2)
        end)

        it('will hide the top 3 lines', function()
          screen:expect([[
            rows: 5, cols: 28         |
            rows: 3, cols: 26         |
            {2:^ }                         |
                                      |
          ]])
          eq(8, api.nvim_buf_line_count(0))
          feed([[3k]])
          screen:expect([[
            ^line4                     |
            rows: 5, cols: 28         |
            rows: 3, cols: 26         |
                                      |
          ]])
        end)
      end)
    end)
  end)

  describe('with empty lines after the cursor', function()
    -- XXX: Can't test this reliably on Windows unless the cursor is _moved_
    --      by the resize. http://docs.libuv.org/en/v1.x/signal.html
    --      See also: https://github.com/rprichard/winpty/issues/110
    if skip(is_os('win')) then
      return
    end

    describe('and the height is decreased by 2', function()
      before_each(function()
        screen:try_resize(screen._width, screen._height - 2)
      end)

      local function will_delete_last_two_lines()
        screen:expect([[
          tty ready                     |
          rows: 4, cols: 30             |
          {1: }                             |
                                        |
          {3:-- TERMINAL --}                |
        ]])
        eq(4, api.nvim_buf_line_count(0))
      end

      it('will delete the last two empty lines', will_delete_last_two_lines)

      describe('and then decreased by 1', function()
        before_each(function()
          will_delete_last_two_lines()
          screen:try_resize(screen._width, screen._height - 1)
        end)

        it('will delete the last line and hide the first', function()
          screen:expect([[
            rows: 4, cols: 30             |
            rows: 3, cols: 30             |
            {1: }                             |
            {3:-- TERMINAL --}                |
          ]])
          eq(4, api.nvim_buf_line_count(0))
          feed('<c-\\><c-n>gg')
          screen:expect([[
            ^tty ready                     |
            rows: 4, cols: 30             |
            rows: 3, cols: 30             |
                                          |
          ]])
          feed('a')
          screen:expect([[
            rows: 4, cols: 30             |
            rows: 3, cols: 30             |
            {1: }                             |
            {3:-- TERMINAL --}                |
          ]])
        end)
      end)
    end)
  end)

  describe('with 4 lines hidden in the scrollback', function()
    before_each(function()
      feed_data({ 'line1', 'line2', 'line3', 'line4', '' })
      screen:expect([[
        tty ready                     |
        line1                         |
        line2                         |
        line3                         |
        line4                         |
        {1: }                             |
        {3:-- TERMINAL --}                |
      ]])
      screen:try_resize(screen._width, screen._height - 3)
      screen:expect([[
        line4                         |
        rows: 3, cols: 30             |
        {1: }                             |
        {3:-- TERMINAL --}                |
      ]])
      eq(7, api.nvim_buf_line_count(0))
    end)

    describe('and the height is increased by 1', function()
      -- XXX: Can't test this reliably on Windows unless the cursor is _moved_
      --      by the resize. http://docs.libuv.org/en/v1.x/signal.html
      --      See also: https://github.com/rprichard/winpty/issues/110
      if skip(is_os('win')) then
        return
      end
      local function pop_then_push()
        screen:try_resize(screen._width, screen._height + 1)
        screen:expect([[
          line4                         |
          rows: 3, cols: 30             |
          rows: 4, cols: 30             |
          {1: }                             |
          {3:-- TERMINAL --}                |
        ]])
      end

      it('will pop 1 line and then push it back', pop_then_push)

      describe('and then by 3', function()
        before_each(function()
          pop_then_push()
          eq(8, api.nvim_buf_line_count(0))
          screen:try_resize(screen._width, screen._height + 3)
        end)

        local function pop3_then_push1()
          screen:expect([[
            line2                         |
            line3                         |
            line4                         |
            rows: 3, cols: 30             |
            rows: 4, cols: 30             |
            rows: 7, cols: 30             |
            {1: }                             |
            {3:-- TERMINAL --}                |
          ]])
          eq(9, api.nvim_buf_line_count(0))
          feed('<c-\\><c-n>gg')
          screen:expect([[
            ^tty ready                     |
            line1                         |
            line2                         |
            line3                         |
            line4                         |
            rows: 3, cols: 30             |
            rows: 4, cols: 30             |
                                          |
          ]])
        end

        it('will pop 3 lines and then push one back', pop3_then_push1)

        describe('and then by 4', function()
          before_each(function()
            pop3_then_push1()
            feed('Gi')
            screen:try_resize(screen._width, screen._height + 4)
          end)

          it('will show all lines and leave a blank one at the end', function()
            screen:expect([[
              tty ready                     |
              line1                         |
              line2                         |
              line3                         |
              line4                         |
              rows: 3, cols: 30             |
              rows: 4, cols: 30             |
              rows: 7, cols: 30             |
              rows: 11, cols: 30            |
              {1: }                             |
                                            |
              {3:-- TERMINAL --}                |
            ]])
            -- since there's an empty line after the cursor, the buffer line
            -- count equals the terminal screen height
            eq(11, api.nvim_buf_line_count(0))
          end)
        end)
      end)
    end)
  end)
end)

describe(':terminal prints more lines than the screen height and exits', function()
  it('will push extra lines to scrollback', function()
    clear()
    local screen = Screen.new(30, 7)
    screen:attach({ rgb = false })
    command(("call termopen(['%s', '10']) | startinsert"):format(testprg('tty-test')))
    screen:expect([[
      line6                         |
      line7                         |
      line8                         |
      line9                         |
                                    |
      [Process exited 0]{2: }           |
      {5:-- TERMINAL --}                |
    ]])
    feed('<cr>')
    -- closes the buffer correctly after pressing a key
    screen:expect {
      grid = [[
      ^                              |
      {1:~                             }|*5
                                    |
    ]],
      attr_ids = { [1] = { foreground = 12 } },
    }
  end)
end)

describe("'scrollback' option", function()
  before_each(function()
    clear()
  end)

  local function set_fake_shell()
    api.nvim_set_option_value('shell', string.format('"%s" INTERACT', testprg('shell-test')), {})
  end

  local function expect_lines(expected, epsilon)
    local ep = epsilon and epsilon or 0
    local actual = eval("line('$')")
    if expected > actual + ep and expected < actual - ep then
      error('expected (+/- ' .. ep .. '): ' .. expected .. ', actual: ' .. tostring(actual))
    end
  end

  it('set to 0 behaves as 1', function()
    local screen
    if is_os('win') then
      screen = tt.setup_screen(nil, { 'cmd.exe' }, 30)
    else
      screen = tt.setup_screen(nil, { 'sh' }, 30)
    end

    api.nvim_set_option_value('scrollback', 0, {})
    feed_data(('%s REP 31 line%s'):format(testprg('shell-test'), is_os('win') and '\r' or '\n'))
    screen:expect { any = '30: line                      ' }
    retry(nil, nil, function()
      expect_lines(7)
    end)
  end)

  it('deletes lines (only) if necessary', function()
    local screen
    if is_os('win') then
      command([[let $PROMPT='$$']])
      screen = tt.setup_screen(nil, { 'cmd.exe' }, 30)
    else
      command('let $PS1 = "$"')
      screen = tt.setup_screen(nil, { 'sh' }, 30)
    end

    api.nvim_set_option_value('scrollback', 200, {})

    -- Wait for prompt.
    screen:expect { any = '%$' }

    feed_data(('%s REP 31 line%s'):format(testprg('shell-test'), is_os('win') and '\r' or '\n'))
    screen:expect { any = '30: line                      ' }

    retry(nil, nil, function()
      expect_lines(33, 2)
    end)
    api.nvim_set_option_value('scrollback', 10, {})
    poke_eventloop()
    retry(nil, nil, function()
      expect_lines(16)
    end)
    api.nvim_set_option_value('scrollback', 10000, {})
    retry(nil, nil, function()
      expect_lines(16)
    end)
    -- Terminal job data is received asynchronously, may happen before the
    -- 'scrollback' option is synchronized with the internal sb_buffer.
    command('sleep 100m')

    feed_data(('%s REP 41 line%s'):format(testprg('shell-test'), is_os('win') and '\r' or '\n'))
    if is_os('win') then
      screen:expect {
        grid = [[
        37: line                      |
        38: line                      |
        39: line                      |
        40: line                      |
                                      |
        ${1: }                            |
        {3:-- TERMINAL --}                |
      ]],
      }
    else
      screen:expect {
        grid = [[
        36: line                      |
        37: line                      |
        38: line                      |
        39: line                      |
        40: line                      |
        {MATCH:.*}|
        {3:-- TERMINAL --}                |
      ]],
      }
    end
    expect_lines(58)

    -- Verify off-screen state
    eq((is_os('win') and '36: line' or '35: line'), eval("getline(line('w0') - 1)->trim(' ', 2)"))
    eq((is_os('win') and '27: line' or '26: line'), eval("getline(line('w0') - 10)->trim(' ', 2)"))
  end)

  it('deletes extra lines immediately', function()
    -- Scrollback is 10 on setup_screen
    local screen = tt.setup_screen(nil, nil, 30)
    local lines = {}
    for i = 1, 30 do
      table.insert(lines, 'line' .. tostring(i))
    end
    table.insert(lines, '')
    feed_data(lines)
    screen:expect([[
        line26                        |
        line27                        |
        line28                        |
        line29                        |
        line30                        |
        {1: }                             |
        {3:-- TERMINAL --}                |
      ]])
    local term_height = 6 -- Actual terminal screen height, not the scrollback
    -- Initial
    local scrollback = api.nvim_get_option_value('scrollback', {})
    eq(scrollback + term_height, eval('line("$")'))
    -- Reduction
    scrollback = scrollback - 2
    api.nvim_set_option_value('scrollback', scrollback, {})
    eq(scrollback + term_height, eval('line("$")'))
  end)

  it('defaults to 10000 in :terminal buffers', function()
    set_fake_shell()
    command('terminal')
    eq(10000, api.nvim_get_option_value('scrollback', {}))
  end)

  it('error if set to invalid value', function()
    eq('Vim(set):E474: Invalid argument: scrollback=-2', pcall_err(command, 'set scrollback=-2'))
    eq(
      'Vim(set):E474: Invalid argument: scrollback=100001',
      pcall_err(command, 'set scrollback=100001')
    )
  end)

  it('defaults to -1 on normal buffers', function()
    command('new')
    eq(-1, api.nvim_get_option_value('scrollback', {}))
  end)

  it(':setlocal in a :terminal buffer', function()
    set_fake_shell()

    -- _Global_ scrollback=-1 defaults :terminal to 10_000.
    command('setglobal scrollback=-1')
    command('terminal')
    eq(10000, api.nvim_get_option_value('scrollback', {}))

    -- _Local_ scrollback=-1 in :terminal forces the _maximum_.
    command('setlocal scrollback=-1')
    retry(nil, nil, function() -- Fixup happens on refresh, not immediately.
      eq(100000, api.nvim_get_option_value('scrollback', {}))
    end)

    -- _Local_ scrollback=-1 during TermOpen forces the maximum. #9605
    command('setglobal scrollback=-1')
    command('autocmd TermOpen * setlocal scrollback=-1')
    command('terminal')
    eq(100000, api.nvim_get_option_value('scrollback', {}))
  end)

  it(':setlocal in a normal buffer', function()
    command('new')
    -- :setlocal to -1.
    command('setlocal scrollback=-1')
    eq(-1, api.nvim_get_option_value('scrollback', {}))
    -- :setlocal to anything except -1. Currently, this just has no effect.
    command('setlocal scrollback=42')
    eq(42, api.nvim_get_option_value('scrollback', {}))
  end)

  it(':set updates local value and global default', function()
    set_fake_shell()
    command('set scrollback=42') -- set global value
    eq(42, api.nvim_get_option_value('scrollback', {}))
    command('terminal')
    eq(42, api.nvim_get_option_value('scrollback', {})) -- inherits global default
    command('setlocal scrollback=99')
    eq(99, api.nvim_get_option_value('scrollback', {}))
    command('set scrollback<') -- reset to global default
    eq(42, api.nvim_get_option_value('scrollback', {}))
    command('setglobal scrollback=734') -- new global default
    eq(42, api.nvim_get_option_value('scrollback', {})) -- local value did not change
    command('terminal')
    eq(734, api.nvim_get_option_value('scrollback', {}))
  end)
end)

describe('pending scrollback line handling', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 7)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.Brown },
      [2] = { reverse = true },
      [3] = { bold = true },
    }
  end)

  it("does not crash after setting 'number' #14891", function()
    exec_lua [[
      local api = vim.api
      local buf = api.nvim_create_buf(true, true)
      local chan = api.nvim_open_term(buf, {})
      vim.wo.number = true
      api.nvim_chan_send(chan, ("a\n"):rep(11) .. "a")
      api.nvim_win_set_buf(0, buf)
    ]]
    screen:expect [[
      {1:  1 }^a                         |
      {1:  2 }a                         |
      {1:  3 }a                         |
      {1:  4 }a                         |
      {1:  5 }a                         |
      {1:  6 }a                         |
                                    |
    ]]
    feed('G')
    screen:expect [[
      {1:  7 }a                         |
      {1:  8 }a                         |
      {1:  9 }a                         |
      {1: 10 }a                         |
      {1: 11 }a                         |
      {1: 12 }^a                         |
                                    |
    ]]
    assert_alive()
  end)

  it('does not crash after nvim_buf_call #14891', function()
    exec_lua(
      [[
      local bufnr = vim.api.nvim_create_buf(false, true)
      local args = ...
      vim.api.nvim_buf_call(bufnr, function()
        vim.fn.termopen(args)
      end)
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.cmd('startinsert')
    ]],
      is_os('win') and { 'cmd.exe', '/c', 'for /L %I in (1,1,12) do @echo hi' }
        or { 'printf', ('hi\n'):rep(12) }
    )
    screen:expect [[
      hi                            |*4
                                    |
      [Process exited 0]{2: }           |
      {3:-- TERMINAL --}                |
    ]]
    assert_alive()
  end)
end)
