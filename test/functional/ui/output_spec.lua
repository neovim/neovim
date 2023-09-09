local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')
local assert_alive = helpers.assert_alive
local mkdir, write_file, rmdir = helpers.mkdir, helpers.write_file, helpers.rmdir
local eq = helpers.eq
local feed = helpers.feed
local feed_command = helpers.feed_command
local clear = helpers.clear
local command = helpers.command
local testprg = helpers.testprg
local nvim_dir = helpers.nvim_dir
local has_powershell = helpers.has_powershell
local set_shell_powershell = helpers.set_shell_powershell
local skip = helpers.skip
local is_os = helpers.is_os

clear()  -- for has_powershell()

describe("shell command :!", function()
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
  end)

  it("displays output without LF/EOF. #4646 #4569 #3772", function()
    skip(is_os('win'))
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
    skip(is_os('openbsd'), 'FIXME #10804')
    skip(is_os('win'))
    child_session.feed_data((":!%s REP 30001 foo\n"):format(testprg('shell-test')))

    -- If we observe any line starting with a dot, then throttling occurred.
    -- Avoid false failure on slow systems.
    screen:expect{any="\n%.", timeout=20000}

    -- Final chunk of output should always be displayed, never skipped.
    -- (Throttling is non-deterministic, this test is merely a sanity check.)
    screen:expect([[
      29997: foo                                        |
      29998: foo                                        |
      29999: foo                                        |
      30000: foo                                        |
                                                        |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]], {
      -- test/functional/helpers.lua defaults to background=light.
      [1] = {reverse = true},
      [3] = {bold = true},
      [10] = {foreground = 2},
    })
  end)
end)

describe("shell command :!", function()
  before_each(function()
    clear()
  end)

  it("cat a binary file #4142", function()
    feed(":exe 'silent !cat '.shellescape(v:progpath)<CR>")
    assert_alive()
  end)

  it([[display \x08 char #4142]], function()
    feed(":silent !echo \08<CR>")
    assert_alive()
  end)

  it('handles control codes', function()
    skip(is_os('win'), 'missing printf')
    local screen = Screen.new(50, 4)
    screen:set_default_attr_ids {
      [1] = {bold = true, reverse = true};
      [2] = {bold = true, foreground = Screen.colors.SeaGreen};
      [3] = {foreground = Screen.colors.Blue};
    }
    screen:attach()
    -- Print TAB chars. #2958
    feed([[:!printf '1\t2\t3'<CR>]])
    screen:expect{grid=[[
      {1:                                                  }|
      :!printf '1\t2\t3'                                |
      1       2       3                                 |
      {2:Press ENTER or type command to continue}^           |
    ]]}
    feed([[<CR>]])

    -- Print BELL control code. #4338
    screen.bell = false
    feed([[:!printf '\007\007\007\007text'<CR>]])
    screen:expect{grid=[[
      {1:                                                  }|
      :!printf '\007\007\007\007text'                   |
      text                                              |
      {2:Press ENTER or type command to continue}^           |
    ]], condition=function()
      eq(true, screen.bell)
    end}
    feed([[<CR>]])

    -- Print BS control code.
    feed([[:echo system('printf ''\010\n''')<CR>]])
    screen:expect([[
      {1:                                                  }|
      {3:^H}                                                |
                                                        |
      {2:Press ENTER or type command to continue}^           |
    ]])
    feed([[<CR>]])

    -- Print LF control code.
    feed([[:!printf '\n'<CR>]])
    screen:expect([[
      :!printf '\n'                                     |
                                                        |
                                                        |
      {2:Press ENTER or type command to continue}^           |
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
      command(is_os('win')
        and [[nnoremap <silent>\l :!dir /b bang_filter_spec<cr>]]
        or  [[nnoremap <silent>\l :!ls bang_filter_spec<cr>]])
      local result = (is_os('win')
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
      screen:expect{grid=[[
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
      ]], condition=function()
        eq(true, screen.bell)
      end}
    end)

    it('handles multibyte sequences split over buffer boundaries', function()
      command('cd '..nvim_dir)
      local cmd = is_os('win') and '!shell-test UTF-8  ' or '!./shell-test UTF-8'
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
  if has_powershell() then
    it('powershell supports literal strings', function()
      set_shell_powershell()
      local screen = Screen.new(45, 4)
      screen:attach()
      feed_command([[!'Write-Output $a']])
      screen:expect([[
        :!'Write-Output $a'                          |
        Write-Output $a                              |
                                                     |
        Press ENTER or type command to continue^      |
      ]])
      feed_command([[!$a = 1; Write-Output '$a']])
      screen:expect([[
        :!$a = 1; Write-Output '$a'                  |
        $a                                           |
                                                     |
        Press ENTER or type command to continue^      |
      ]])
      feed_command([[!"Write-Output $a"]])
      screen:expect([[
        :!"Write-Output $a"                          |
        Write-Output                                 |
                                                     |
        Press ENTER or type command to continue^      |
      ]])
      feed_command([[!$a = 1; Write-Output "$a"]])
      screen:expect([[
        :!$a = 1; Write-Output "$a"                  |
        1                                            |
                                                     |
        Press ENTER or type command to continue^      |
      ]])
      if is_os('win') then
        feed_command([[!& 'cmd.exe' /c 'echo $a']])
        screen:expect([[
          :!& 'cmd.exe' /c 'echo $a'                   |
          $a                                           |
                                                       |
          Press ENTER or type command to continue^      |
        ]])
      else
        feed_command([[!& '/bin/sh' -c 'echo ''$a''']])
        screen:expect([[
          :!& '/bin/sh' -c 'echo ''$a'''               |
          $a                                           |
                                                       |
          Press ENTER or type command to continue^      |
        ]])
      end
    end)
  end
end)
