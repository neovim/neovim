local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')

local clear = n.clear
local feed_command = n.feed_command
local feed_data = tt.feed_data

if t.skip(t.is_os('win')) then
  return
end

describe('autoread TUI FocusGained/FocusLost', function()
  local f1 = 'xtest-foo'
  local screen

  before_each(function()
    clear()
    screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile noshowcmd noruler notermguicolors',
    })
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

    t.write_file(path, '')
    local atime = os.time() - 10
    vim.uv.fs_utime(path, atime, atime)

    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*3
      {3:[No Name]                                         }|
                                                        |
      {5:-- TERMINAL --}                                    |
    ]])
    feed_command('edit ' .. path)
    screen:expect([[
      ^                                                  |
      {100:~                                                 }|*3
      {3:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {5:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[O')
    feed_data('\027[O')
    screen:expect_unchanged()

    t.write_file(path, expected_addition)

    feed_data('\027[I')

    screen:expect([[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {3:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {5:-- TERMINAL --}                                    |
    ]])
  end)
end)
