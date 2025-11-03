local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local clear, eq, neq = n.clear, t.eq, t.neq
local feed, testprg = n.feed, n.testprg
local fn = n.fn
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

local function test_terminal_scrollback(hide_curbuf)
  local screen --- @type test.functional.ui.screen
  local buf --- @type integer
  local chan --- @type integer
  local otherbuf --- @type integer
  local restore_terminal_mode --- @type boolean?

  local function may_hide_curbuf()
    if hide_curbuf then
      eq(nil, restore_terminal_mode)
      restore_terminal_mode = vim.startswith(api.nvim_get_mode().mode, 't')
      api.nvim_set_current_buf(otherbuf)
    end
  end

  local function may_restore_curbuf()
    if hide_curbuf then
      neq(nil, restore_terminal_mode)
      eq(buf, fn.bufnr('#'))
      feed('<C-^>') -- "view" in 'jumpoptions' applies to this
      if restore_terminal_mode then
        feed('i')
      else
        -- Cursor position was restored from wi_mark, not b_last_cursor.
        -- Check that b_last_cursor and wi_mark are the same.
        local last_cursor = fn.getpos([['"]])
        local restored_cursor = fn.getpos('.')
        if last_cursor[2] > 0 then
          eq(restored_cursor, last_cursor)
        else
          eq({ 0, 0, 0, 0 }, last_cursor)
          eq({ 0, 1, 1, 0 }, restored_cursor)
        end
      end
      restore_terminal_mode = nil
    end
  end

  --- @param prefix string
  --- @param start integer
  --- @param stop integer
  local function feed_lines(prefix, start, stop)
    may_hide_curbuf()
    local data = ''
    for i = start, stop do
      data = data .. prefix .. tostring(i) .. '\n'
    end
    api.nvim_chan_send(chan, data)
    retry(nil, 1000, function()
      eq({ prefix .. tostring(stop), '' }, api.nvim_buf_get_lines(buf, -3, -1, true))
    end)
    may_restore_curbuf()
  end

  before_each(function()
    clear()
    command('set nostartofline jumpoptions+=view')
    screen = tt.setup_screen(nil, nil, 30)
    buf = api.nvim_get_current_buf()
    chan = api.nvim_get_option_value('channel', { buf = buf })
    if hide_curbuf then
      otherbuf = api.nvim_create_buf(true, false)
    end
  end)

  describe('when the limit is exceeded', function()
    before_each(function()
      feed_lines('line', 1, 30)
      screen:expect([[
        line26                        |
        line27                        |
        line28                        |
        line29                        |
        line30                        |
        ^                              |
        {5:-- TERMINAL --}                |
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

    describe('and cursor on non-last row in screen', function()
      before_each(function()
        feed([[<C-\><C-N>M$]])
        fn.setpos("'m", { 0, 13, 4, 0 })
        local ns = api.nvim_create_namespace('test')
        api.nvim_buf_set_extmark(0, ns, 12, 0, { end_col = 6, hl_group = 'ErrorMsg' })
        screen:expect([[
          line26                        |
          line27                        |
          {101:line2^8}                        |
          line29                        |
          line30                        |
                                        |*2
        ]])
      end)

      it("when outputting fewer than 'scrollback' lines", function()
        feed_lines('new_line', 1, 6)
        screen:expect([[
          line26                        |
          line27                        |
          {101:line2^8}                        |
          line29                        |
          line30                        |
          new_line1                     |
                                        |
        ]])
        eq({ 0, 7, 4, 0 }, fn.getpos("'m"))
        eq({ 0, 7, 6, 0 }, fn.getpos('.'))
      end)

      it("when outputting more than 'scrollback' lines", function()
        feed_lines('new_line', 1, 11)
        screen:expect([[
          line27                        |
          {101:line2^8}                        |
          line29                        |
          line30                        |
          new_line1                     |
          new_line2                     |
                                        |
        ]])
        eq({ 0, 2, 4, 0 }, fn.getpos("'m"))
        eq({ 0, 2, 6, 0 }, fn.getpos('.'))
      end)

      it('when outputting more lines than whole buffer', function()
        feed_lines('new_line', 1, 20)
        screen:expect([[
          ^new_line6                     |
          new_line7                     |
          new_line8                     |
          new_line9                     |
          new_line10                    |
          new_line11                    |
                                        |
        ]])
        eq({ 0, 0, 0, 0 }, fn.getpos("'m"))
        eq({ 0, 1, 1, 0 }, fn.getpos('.'))
      end)
    end)

    describe('and cursor on scrollback row #12651', function()
      before_each(function()
        feed([[<C-\><C-N>Hk$]])
        fn.setpos("'m", { 0, 10, 4, 0 })
        local ns = api.nvim_create_namespace('test')
        api.nvim_buf_set_extmark(0, ns, 9, 0, { end_col = 6, hl_group = 'ErrorMsg' })
        screen:expect([[
          {101:line2^5}                        |
          line26                        |
          line27                        |
          line28                        |
          line29                        |
          line30                        |
                                        |
        ]])
      end)

      it("when outputting fewer than 'scrollback' lines", function()
        feed_lines('new_line', 1, 6)
        screen:expect_unchanged(hide_curbuf)
        eq({ 0, 4, 4, 0 }, fn.getpos("'m"))
        eq({ 0, 4, 6, 0 }, fn.getpos('.'))
      end)

      it("when outputting more than 'scrollback' lines", function()
        feed_lines('new_line', 1, 11)
        screen:expect([[
          ^line27                        |
          line28                        |
          line29                        |
          line30                        |
          new_line1                     |
          new_line2                     |
                                        |
        ]])
        eq({ 0, 0, 0, 0 }, fn.getpos("'m"))
        eq({ 0, 1, 1, 0 }, fn.getpos('.'))
      end)
    end)
  end)

  describe('with cursor at last row', function()
    before_each(function()
      feed_lines('line', 1, 4)
      screen:expect([[
        tty ready                     |
        line1                         |
        line2                         |
        line3                         |
        line4                         |
        ^                              |
        {5:-- TERMINAL --}                |
      ]])
      fn.setpos("'m", { 0, 3, 4, 0 })
      local ns = api.nvim_create_namespace('test')
      api.nvim_buf_set_extmark(0, ns, 2, 0, { end_col = 5, hl_group = 'ErrorMsg' })
      screen:expect([[
        tty ready                     |
        line1                         |
        {101:line2}                         |
        line3                         |
        line4                         |
        ^                              |
        {5:-- TERMINAL --}                |
      ]])
    end)

    it("when outputting more than 'scrollback' lines in Normal mode", function()
      feed([[<C-\><C-N>]])
      feed_lines('new_line', 1, 11)
      screen:expect([[
        new_line7                     |
        new_line8                     |
        new_line9                     |
        new_line10                    |
        new_line11                    |
        ^                              |
                                      |
      ]])
      feed('gg')
      screen:expect([[
        ^line1                         |
        {101:line2}                         |
        line3                         |
        line4                         |
        new_line1                     |
        new_line2                     |
                                      |
      ]])
      eq({ 0, 2, 4, 0 }, fn.getpos("'m"))
      feed('G')
      feed_lines('new_line', 12, 31)
      screen:expect([[
        new_line27                    |
        new_line28                    |
        new_line29                    |
        new_line30                    |
        new_line31                    |
        ^                              |
                                      |
      ]])
      feed('gg')
      screen:expect([[
        ^new_line17                    |
        new_line18                    |
        new_line19                    |
        new_line20                    |
        new_line21                    |
        new_line22                    |
                                      |
      ]])
      eq({ 0, 0, 0, 0 }, fn.getpos("'m"))
    end)

    describe('and 1 line is printed', function()
      before_each(function()
        feed_lines('line', 5, 5)
      end)

      it('will hide the top line', function()
        screen:expect([[
          line1                         |
          {101:line2}                         |
          line3                         |
          line4                         |
          line5                         |
          ^                              |
          {5:-- TERMINAL --}                |
        ]])
        eq(7, api.nvim_buf_line_count(0))
        eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
      end)

      describe('and then 3 more lines are printed', function()
        before_each(function()
          feed_lines('line', 6, 8)
        end)

        it('will hide the top 4 lines', function()
          screen:expect([[
            line4                         |
            line5                         |
            line6                         |
            line7                         |
            line8                         |
            ^                              |
            {5:-- TERMINAL --}                |
          ]])
          eq({ 0, 3, 4, 0 }, fn.getpos("'m"))

          feed('<c-\\><c-n>6k')
          screen:expect([[
            ^line3                         |
            line4                         |
            line5                         |
            line6                         |
            line7                         |
            line8                         |
                                          |
          ]])

          feed('gg')
          screen:expect([[
            ^tty ready                     |
            line1                         |
            {101:line2}                         |
            line3                         |
            line4                         |
            line5                         |
                                          |
          ]])

          feed('G')
          screen:expect([[
            line4                         |
            line5                         |
            line6                         |
            line7                         |
            line8                         |
            ^                              |
                                          |
          ]])
        end)
      end)
    end)

    describe('and height decreased by 1', function()
      local function will_hide_top_line()
        feed([[<C-\><C-N>]])
        may_hide_curbuf()
        screen:try_resize(screen._width - 2, screen._height - 1)
        may_restore_curbuf()
        screen:expect([[
          {101:line2}                       |
          line3                       |
          line4                       |
          rows: 5, cols: 28           |
          ^                            |
                                      |
        ]])
        eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
      end

      it('will hide top line', will_hide_top_line)

      describe('and then decreased by 2', function()
        before_each(function()
          will_hide_top_line()
          may_hide_curbuf()
          screen:try_resize(screen._width - 2, screen._height - 2)
          may_restore_curbuf()
        end)

        it('will hide the top 3 lines', function()
          screen:expect([[
            rows: 5, cols: 28         |
            rows: 3, cols: 26         |
            ^                          |
                                      |
          ]])
          eq(8, api.nvim_buf_line_count(0))
          eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
          feed('3k')
          screen:expect([[
            ^line4                     |
            rows: 5, cols: 28         |
            rows: 3, cols: 26         |
                                      |
          ]])
          feed('gg')
          screen:expect([[
            ^tty ready                 |
            line1                     |
            {101:line2}                     |
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
        may_hide_curbuf()
        screen:try_resize(screen._width, screen._height - 2)
        may_restore_curbuf()
      end)

      local function will_delete_last_two_lines()
        screen:expect([[
          tty ready                     |
          rows: 4, cols: 30             |
          ^                              |
                                        |
          {5:-- TERMINAL --}                |
        ]])
        eq(4, api.nvim_buf_line_count(0))
      end

      it('will delete the last two empty lines', will_delete_last_two_lines)

      describe('and then decreased by 1', function()
        before_each(function()
          will_delete_last_two_lines()
          may_hide_curbuf()
          screen:try_resize(screen._width, screen._height - 1)
          may_restore_curbuf()
        end)

        it('will delete the last line and hide the first', function()
          screen:expect([[
            rows: 4, cols: 30             |
            rows: 3, cols: 30             |
            ^                              |
            {5:-- TERMINAL --}                |
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
            ^                              |
            {5:-- TERMINAL --}                |
          ]])
        end)
      end)
    end)
  end)

  describe('with 4 lines hidden in the scrollback', function()
    before_each(function()
      feed_lines('line', 1, 4)
      screen:expect([[
        tty ready                     |
        line1                         |
        line2                         |
        line3                         |
        line4                         |
        ^                              |
        {5:-- TERMINAL --}                |
      ]])
      fn.setpos("'m", { 0, 3, 4, 0 })
      local ns = api.nvim_create_namespace('test')
      api.nvim_buf_set_extmark(0, ns, 2, 0, { end_col = 5, hl_group = 'ErrorMsg' })
      screen:expect([[
        tty ready                     |
        line1                         |
        {101:line2}                         |
        line3                         |
        line4                         |
        ^                              |
        {5:-- TERMINAL --}                |
      ]])
      may_hide_curbuf()
      screen:try_resize(screen._width, screen._height - 3)
      may_restore_curbuf()
      screen:expect([[
        line4                         |
        rows: 3, cols: 30             |
        ^                              |
        {5:-- TERMINAL --}                |
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
        may_hide_curbuf()
        screen:try_resize(screen._width, screen._height + 1)
        may_restore_curbuf()
        screen:expect([[
          line4                         |
          rows: 3, cols: 30             |
          rows: 4, cols: 30             |
          ^                              |
          {5:-- TERMINAL --}                |
        ]])
        eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
      end

      it('will pop 1 line and then push it back', pop_then_push)

      describe('and then by 3', function()
        before_each(function()
          pop_then_push()
          eq(8, api.nvim_buf_line_count(0))
          may_hide_curbuf()
          screen:try_resize(screen._width, screen._height + 3)
          may_restore_curbuf()
        end)

        local function pop3_then_push1()
          screen:expect([[
            {101:line2}                         |
            line3                         |
            line4                         |
            rows: 3, cols: 30             |
            rows: 4, cols: 30             |
            rows: 7, cols: 30             |
            ^                              |
            {5:-- TERMINAL --}                |
          ]])
          eq(9, api.nvim_buf_line_count(0))
          eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
          feed('<c-\\><c-n>gg')
          screen:expect([[
            ^tty ready                     |
            line1                         |
            {101:line2}                         |
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
            may_hide_curbuf()
            screen:try_resize(screen._width, screen._height + 4)
            may_restore_curbuf()
          end)

          it('will show all lines and leave a blank one at the end', function()
            screen:expect([[
              tty ready                     |
              line1                         |
              {101:line2}                         |
              line3                         |
              line4                         |
              rows: 3, cols: 30             |
              rows: 4, cols: 30             |
              rows: 7, cols: 30             |
              rows: 11, cols: 30            |
              ^                              |
                                            |
              {5:-- TERMINAL --}                |
            ]])
            -- since there's an empty line after the cursor, the buffer line
            -- count equals the terminal screen height
            eq(11, api.nvim_buf_line_count(0))
            eq({ 0, 3, 4, 0 }, fn.getpos("'m"))
          end)
        end)
      end)
    end)
  end)

  it('reducing &scrollback deletes extra lines immediately', function()
    feed_lines('line', 1, 30)
    screen:expect([[
      line26                        |
      line27                        |
      line28                        |
      line29                        |
      line30                        |
      ^                              |
      {5:-- TERMINAL --}                |
    ]])
    local term_height = 6 -- Actual terminal screen height, not the scrollback
    -- Initial
    local scrollback = api.nvim_get_option_value('scrollback', { buf = buf })
    eq(scrollback + term_height, fn.line('$'))
    eq(scrollback + term_height, fn.line('.'))
    n.fn.setpos("'m", { 0, scrollback + 1, 4, 0 })
    local ns = api.nvim_create_namespace('test')
    api.nvim_buf_set_extmark(0, ns, scrollback, 0, { end_col = 6, hl_group = 'ErrorMsg' })
    screen:expect([[
      {101:line26}                        |
      line27                        |
      line28                        |
      line29                        |
      line30                        |
      ^                              |
      {5:-- TERMINAL --}                |
    ]])
    -- Reduction
    scrollback = scrollback - 2
    may_hide_curbuf()
    api.nvim_set_option_value('scrollback', scrollback, { buf = buf })
    may_restore_curbuf()
    eq(scrollback + term_height, fn.line('$'))
    eq(scrollback + term_height, fn.line('.'))
    screen:expect_unchanged(hide_curbuf)
    eq({ 0, scrollback + 1, 4, 0 }, n.fn.getpos("'m"))
  end)
end

describe(':terminal scrollback', function()
  describe('in current buffer', function()
    test_terminal_scrollback(false)
  end)

  describe('in hidden buffer', function()
    test_terminal_scrollback(true)
  end)
end)

describe(':terminal prints more lines than the screen height and exits', function()
  it('will push extra lines to scrollback', function()
    clear()
    local screen = Screen.new(30, 7, { rgb = false })
    screen:add_extra_attr_ids({ [100] = { foreground = 12 } })
    command(
      ("call jobstart(['%s', '10'], {'term':v:true}) | startinsert"):format(testprg('tty-test'))
    )
    screen:expect([[
      line6                         |
      line7                         |
      line8                         |
      line9                         |
                                    |
      [Process exited 0]^            |
      {5:-- TERMINAL --}                |
    ]])
    feed('<cr>')
    -- closes the buffer correctly after pressing a key
    screen:expect([[
      ^                              |
      {100:~                             }|*5
                                    |
    ]])
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
      screen:expect([[
        37: line                      |
        38: line                      |
        39: line                      |
        40: line                      |
                                      |
        $^                             |
        {5:-- TERMINAL --}                |
      ]])
    else
      screen:expect([[
        36: line                      |
        37: line                      |
        38: line                      |
        39: line                      |
        40: line                      |
        {MATCH:.*}|
        {5:-- TERMINAL --}                |
      ]])
    end
    expect_lines(58)

    -- Verify off-screen state
    eq((is_os('win') and '36: line' or '35: line'), eval("getline(line('w0') - 1)->trim(' ', 2)"))
    eq((is_os('win') and '27: line' or '26: line'), eval("getline(line('w0') - 10)->trim(' ', 2)"))
  end)

  it('defaults to 10000 in :terminal buffers', function()
    set_fake_shell()
    command('terminal')
    eq(10000, api.nvim_get_option_value('scrollback', {}))
  end)

  it('error if set to invalid value', function()
    eq('Vim(set):E474: Invalid argument: scrollback=-2', pcall_err(command, 'set scrollback=-2'))
    eq(
      'Vim(set):E474: Invalid argument: scrollback=1000001',
      pcall_err(command, 'set scrollback=1000001')
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
      eq(1000000, api.nvim_get_option_value('scrollback', {}))
    end)

    -- _Local_ scrollback=-1 during TermOpen forces the maximum. #9605
    command('setglobal scrollback=-1')
    command('autocmd TermOpen * setlocal scrollback=-1')
    command('terminal')
    eq(1000000, api.nvim_get_option_value('scrollback', {}))
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
      {8:  1 }^a                         |
      {8:  2 }a                         |
      {8:  3 }a                         |
      {8:  4 }a                         |
      {8:  5 }a                         |
      {8:  6 }a                         |
                                    |
    ]]
    feed('G')
    screen:expect [[
      {8:  7 }a                         |
      {8:  8 }a                         |
      {8:  9 }a                         |
      {8: 10 }a                         |
      {8: 11 }a                         |
      {8: 12 }^a                         |
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
        vim.fn.jobstart(args, { term = true })
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
      [Process exited 0]^            |
      {5:-- TERMINAL --}                |
    ]]
    assert_alive()
  end)
end)
