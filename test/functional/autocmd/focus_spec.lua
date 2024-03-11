local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data

if helpers.skip(helpers.is_os('win')) then
  return
end

describe('autoread TUI FocusGained/FocusLost', function()
  local f1 = 'xtest-foo'
  local screen

  before_each(function()
    clear()
    screen = thelpers.setup_child_nvim({
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

    helpers.write_file(path, '')
    local atime = os.time() - 10
    vim.uv.fs_utime(path, atime, atime)

    screen:expect {
      grid = [[
      {1: }                                                 |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_command('edit ' .. path)
    screen:expect {
      grid = [[
      {1: }                                                 |
      {4:~                                                 }|*3
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data('\027[O')
    feed_data('\027[O')
    screen:expect {
      grid = [[
      {1: }                                                 |
      {4:~                                                 }|*3
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]],
      unchanged = true,
    }

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')

    screen:expect {
      grid = [[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)
end)
