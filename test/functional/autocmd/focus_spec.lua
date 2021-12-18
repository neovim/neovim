local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local lfs = require('lfs')
local clear = helpers.clear
local nvim_prog = helpers.nvim_prog
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data

if helpers.pending_win32(pending) then return end

describe('autoread TUI FocusGained/FocusLost', function()
  local f1 = 'xtest-foo'
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
  end)

  teardown(function()
    os.remove(f1)
  end)

  it('external file change', function()
    local path = f1
    local expected_addition = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_data('\027[O')

    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')

    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:xtest-foo                                         }|
      "xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)
