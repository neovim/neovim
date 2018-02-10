-- Specs for bang/filter commands

local helpers = require('test.functional.helpers')(after_each)
local feed, command, clear = helpers.feed, helpers.command, helpers.clear
local mkdir, write_file, rmdir = helpers.mkdir, helpers.write_file, helpers.rmdir
local feed_command = helpers.feed_command

if helpers.pending_win32(pending) then return end

local Screen = require('test.functional.ui.screen')


describe(':! command', function()
  local screen

  before_each(function()
    clear()
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
    })
    screen:attach()
  end)

  after_each(function()
    rmdir('bang_filter_spec')
  end)

  it("doesn't truncate Last line of shell output #3269", function()
    command([[nnoremap <silent>\l :!ls bang_filter_spec<cr>]])
    feed([[\l]])
    screen:expect([[
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      :!ls bang_filter_spec                                |
      f1                                                   |
      f2                                                   |
      f3                                                   |
                                                           |
      {3:Press ENTER or type command to continue}^              |
    ]])
  end)

  it('handles binary and multibyte data', function()
    feed_command('!cat test/functional/fixtures/shell_data.txt')
    screen:expect([[
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      :!cat test/functional/fixtures/shell_data.txt        |
      {2:^@^A^B^C^D^E^F^G^H}                                   |
      {2:^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^^^_}                 |
      ö 한글 {2:<a5><c3>}                                      |
      t       {2:<ff>}                                         |
                                                           |
      {3:Press ENTER or type command to continue}^              |
  ]])
  end)

end)
