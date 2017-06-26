local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear, eq, curbuf = helpers.clear, helpers.eq, helpers.curbuf
local feed, nvim_dir, feed_command = helpers.feed, helpers.nvim_dir, helpers.feed_command
local eval = helpers.eval
local command = helpers.command
local wait = helpers.wait
local retry = helpers.retry
local curbufmeths = helpers.curbufmeths
local nvim = helpers.nvim
local feed_data = thelpers.feed_data

if helpers.pending_win32(pending) then return end

describe('terminal scrollback', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(nil, nil, 30)
  end)

  after_each(function()
    screen:detach()
  end)

  describe('when the limit is exceeded', function()
    before_each(function()
      local lines = {}
      for i = 1, 30 do
        table.insert(lines, 'line'..tostring(i))
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

  describe('with the cursor at the last row', function()
    before_each(function()
      feed_data({'line1', 'line2', 'line3', 'line4', ''})
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
      before_each(function() feed_data({'line5', ''}) end)

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
        eq(7, curbuf('line_count'))
      end)

      describe('and then 3 more lines are printed', function()
        before_each(function() feed_data({'line6', 'line7', 'line8'}) end)

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


    describe('and the height is decreased by 1', function()
      local function will_hide_top_line()
        screen:try_resize(screen._width, screen._height - 1)
        screen:expect([[
          line2                         |
          line3                         |
          line4                         |
          rows: 5, cols: 30             |
          {1: }                             |
          {3:-- TERMINAL --}                |
        ]])
      end

      it('will hide top line', will_hide_top_line)

      describe('and then decreased by 2', function()
        before_each(function()
          will_hide_top_line()
          screen:try_resize(screen._width, screen._height - 2)
        end)

        it('will hide the top 3 lines', function()
          screen:expect([[
            rows: 5, cols: 30             |
            rows: 3, cols: 30             |
            {1: }                             |
            {3:-- TERMINAL --}                |
          ]])
          eq(8, curbuf('line_count'))
          feed('<c-\\><c-n>3k')
          screen:expect([[
            ^line4                         |
            rows: 5, cols: 30             |
            rows: 3, cols: 30             |
                                          |
          ]])
        end)
      end)
    end)
  end)

  describe('with empty lines after the cursor', function()
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
        eq(4, curbuf('line_count'))
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
          eq(4, curbuf('line_count'))
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
      feed_data({'line1', 'line2', 'line3', 'line4', ''})
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
      eq(7, curbuf('line_count'))
    end)

    describe('and the height is increased by 1', function()
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
          eq(8, curbuf('line_count'))
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
          eq(9, curbuf('line_count'))
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
            eq(11, curbuf('line_count'))
          end)
        end)
      end)
    end)
  end)
end)

describe('terminal prints more lines than the screen height and exits', function()
  it('will push extra lines to scrollback', function()
    clear()
    local screen = Screen.new(30, 7)
    screen:attach({rgb=false})
    feed_command('call termopen(["'..nvim_dir..'/tty-test", "10"]) | startinsert')
    wait()
    screen:expect([[
      line6                         |
      line7                         |
      line8                         |
      line9                         |
                                    |
      [Process exited 0]            |
      -- TERMINAL --                |
    ]])
    feed('<cr>')
    -- closes the buffer correctly after pressing a key
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
                                    |
    ]])
  end)
end)

describe("'scrollback' option", function()
  before_each(function()
    clear()
  end)

  local function set_fake_shell()
    -- shell-test.c is a fake shell that prints its arguments and exits.
    nvim('set_option', 'shell', nvim_dir..'/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')
  end

  local function expect_lines(expected, epsilon)
    local ep = epsilon and epsilon or 0
    local actual = eval("line('$')")
    if expected > actual + ep and expected < actual - ep then
      error('expected (+/- '..ep..'): '..expected..', actual: '..tostring(actual))
    end
  end

  it('set to 0 behaves as 1', function()
    local screen = thelpers.screen_setup(nil, "['sh']", 30)

    curbufmeths.set_option('scrollback', 0)
    feed_data('for i in $(seq 1 30); do echo "line$i"; done\n')
    screen:expect('line30                        ', nil, nil, nil, true)
    retry(nil, nil, function() expect_lines(7) end)

    screen:detach()
  end)

  it('deletes lines (only) if necessary', function()
    local screen = thelpers.screen_setup(nil, "['sh']", 30)

    curbufmeths.set_option('scrollback', 200)

    -- Wait for prompt.
    screen:expect('$', nil, nil, nil, true)

    wait()
    feed_data('for i in $(seq 1 30); do echo "line$i"; done\n')

    screen:expect('line30                        ', nil, nil, nil, true)

    retry(nil, nil, function() expect_lines(33, 2) end)
    curbufmeths.set_option('scrollback', 10)
    wait()
    retry(nil, nil, function() expect_lines(16) end)
    curbufmeths.set_option('scrollback', 10000)
    retry(nil, nil, function() expect_lines(16) end)
    -- Terminal job data is received asynchronously, may happen before the
    -- 'scrollback' option is synchronized with the internal sb_buffer.
    command('sleep 100m')
    feed_data('for i in $(seq 1 40); do echo "line$i"; done\n')

    screen:expect('line40                        ', nil, nil, nil, true)

    retry(nil, nil, function() expect_lines(58) end)
    -- Verify off-screen state
    eq('line35', eval("getline(line('w0') - 1)"))
    eq('line26', eval("getline(line('w0') - 10)"))

    screen:detach()
  end)

  it('defaults to 1000 in terminal buffers', function()
    set_fake_shell()
    command('terminal')
    eq(1000, curbufmeths.get_option('scrollback'))
  end)

  it('error if set to invalid value', function()
    local status, rv = pcall(command, 'set scrollback=-2')
    eq(false, status)  -- assert failure
    eq('E474:', string.match(rv, "E%d*:"))

    status, rv = pcall(command, 'set scrollback=100001')
    eq(false, status)  -- assert failure
    eq('E474:', string.match(rv, "E%d*:"))
  end)

  it('defaults to -1 on normal buffers', function()
    command('new')
    eq(-1, curbufmeths.get_option('scrollback'))
  end)

  it(':setlocal in a normal buffer is an error', function()
    command('new')

    -- :setlocal to -1 is NOT an error.
    feed_command('setlocal scrollback=-1')
    eq(nil, string.match(eval("v:errmsg"), "E%d*:"))
    feed('<CR>')

    -- :setlocal to anything except -1 is an error.
    feed_command('setlocal scrollback=42')
    feed('<CR>')
    eq('E474:', string.match(eval("v:errmsg"), "E%d*:"))
    eq(-1, curbufmeths.get_option('scrollback'))
  end)

  it(':set updates local value and global default', function()
    set_fake_shell()
    command('set scrollback=42')                  -- set global and (attempt) local
    eq(-1, curbufmeths.get_option('scrollback'))  -- normal buffer: -1
    command('terminal')
    eq(42, curbufmeths.get_option('scrollback'))  -- inherits global default
    command('setlocal scrollback=99')
    eq(99, curbufmeths.get_option('scrollback'))
    command('set scrollback<')                    -- reset to global default
    eq(42, curbufmeths.get_option('scrollback'))
    command('setglobal scrollback=734')           -- new global default
    eq(42, curbufmeths.get_option('scrollback'))  -- local value did not change
    command('terminal')
    eq(734, curbufmeths.get_option('scrollback'))
  end)

end)
