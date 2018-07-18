local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')
local mkdir, write_file, rmdir = helpers.mkdir, helpers.write_file, helpers.rmdir
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local feed_command = helpers.feed_command
local iswin = helpers.iswin
local clear = helpers.clear
local command = helpers.command
local nvim_dir = helpers.nvim_dir

describe("shell command :!", function()
  if helpers.pending_win32(pending) then return end

  local screen
  before_each(function()
    clear()
    screen = child_session.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "'..helpers.nvim_set..'"]')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  after_each(function()
    child_session.feed_data("\3") -- Ctrl-C
    screen:detach()
  end)

  it("displays output without LF/EOF. #4646 #4569 #3772", function()
    -- NOTE: We use a child nvim (within a :term buffer)
    --       to avoid triggering a UI flush.
    child_session.feed_data(":!printf foo; sleep 200\n")
    screen:expect([[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:                                                  }|
      :!printf foo; sleep 200                           |
      foo                                               |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it("throttles shell-command output greater than ~10KB", function()
    if os.getenv("TRAVIS") and helpers.os_name() == "osx" then
      pending("[Unreliable on Travis macOS.]", function() end)
      return
    end

    screen.timeout = 20000  -- Avoid false failure on slow systems.
    child_session.feed_data(
      ":!for i in $(seq 2 3000); do echo XXXXXXXXXX $i; done\n")

    -- If we observe any line starting with a dot, then throttling occurred.
    screen:expect("\n.", nil, nil, nil, true)

    -- Final chunk of output should always be displayed, never skipped.
    -- (Throttling is non-deterministic, this test is merely a sanity check.)
    screen:expect([[
      XXXXXXXXXX 2997                                   |
      XXXXXXXXXX 2998                                   |
      XXXXXXXXXX 2999                                   |
      XXXXXXXXXX 3000                                   |
                                                        |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe("shell command :!", function()
  before_each(function()
    clear()
  end)

  it("cat a binary file #4142", function()
    feed(":exe 'silent !cat '.shellescape(v:progpath)<CR>")
    eq(2, eval('1+1'))  -- Still alive?
  end)

  it([[display \x08 char #4142]], function()
    feed(":silent !echo \08<CR>")
    eq(2, eval('1+1'))  -- Still alive?
  end)

  it([[handles control codes]], function()
    if iswin() then
      pending('missing printf', function() end)
      return
    end
    local screen = Screen.new(50, 4)
    screen:attach()
    command("set display-=msgsep")
    -- Print TAB chars. #2958
    feed([[:!printf '1\t2\t3'<CR>]])
    screen:expect([[
      ~                                                 |
      :!printf '1\t2\t3'                                |
      1       2       3                                 |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
    -- Print BELL control code. #4338
    screen.bell = false
    feed([[:!printf '\007\007\007\007text'<CR>]])
    screen:expect([[
      ~                                                 |
      :!printf '\007\007\007\007text'                   |
      text                                              |
      Press ENTER or type command to continue^           |
    ]], nil, nil, function()
      eq(true, screen.bell)
    end)
    feed([[<CR>]])
    -- Print BS control code.
    feed([[:echo system('printf ''\010\n''')<CR>]])
    screen:expect([[
      ~                                                 |
      ^H                                                |
                                                        |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
    -- Print LF control code.
    feed([[:!printf '\n'<CR>]])
    screen:expect([[
      :!printf '\n'                                     |
                                                        |
                                                        |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
  end)

  describe('', function()
    local screen
    before_each(function()
      rmdir('bang_filter_spec')
      mkdir('bang_filter_spec')
      write_file('bang_filter_spec/f1', 'f1')
      write_file('bang_filter_spec/f2', 'f2')
      write_file('bang_filter_spec/f3', 'f3')
      screen = Screen.new(53,10)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
        [2] = {foreground = Screen.colors.Blue1},
        [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
        [4] = {bold = true, reverse = true},
      })
      screen:attach()
    end)

    after_each(function()
      rmdir('bang_filter_spec')
    end)

    it("doesn't truncate Last line of shell output #3269", function()
      command(helpers.iswin()
        and [[nnoremap <silent>\l :!dir /b bang_filter_spec<cr>]]
        or  [[nnoremap <silent>\l :!ls bang_filter_spec<cr>]])
      local result = (helpers.iswin()
        and [[:!dir /b bang_filter_spec]]
        or  [[:!ls bang_filter_spec    ]])
      feed([[\l]])
      screen:expect([[
                                                             |
        {1:~                                                    }|
        {1:~                                                    }|
        {4:                                                     }|
        ]]..result..[[                            |
        f1                                                   |
        f2                                                   |
        f3                                                   |
                                                             |
        {3:Press ENTER or type command to continue}^              |
      ]])
    end)

    it('handles binary and multibyte data', function()
      feed_command('!cat test/functional/fixtures/shell_data.txt')
      screen.bell = false
      screen:expect([[
                                                             |
        {1:~                                                    }|
        {4:                                                     }|
        :!cat test/functional/fixtures/shell_data.txt        |
        {2:^@^A^B^C^D^E^F^H}                                     |
        {2:^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^^^_}                 |
        ö 한글 {2:<a5><c3>}                                      |
        t       {2:<ff>}                                         |
                                                             |
        {3:Press ENTER or type command to continue}^              |
    ]], nil, nil, function()
        eq(true, screen.bell)
      end)
    end)

    it('handles multibyte sequences split over buffer boundaries', function()
      command('cd '..nvim_dir)
      local cmd
      if iswin() then
        cmd = '!shell-test UTF-8  '
      else
        cmd = '!./shell-test UTF-8'
      end
      feed_command(cmd)
      -- Note: only the first example of split composed char works
      screen:expect([[
                                                             |
        {4:                                                     }|
        :]]..cmd..[[                                 |
        å                                                    |
        ref: å̲                                               |
        1: å̲                                                 |
        2: å ̲                                               |
        3: å ̲                                               |
                                                             |
        {3:Press ENTER or type command to continue}^              |
      ]])
    end)
  end)
end)
