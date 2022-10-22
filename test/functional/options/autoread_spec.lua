local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local lfs = require('lfs')
local clear = helpers.clear
local feed_command = helpers.feed_command
local iswin = helpers.iswin

if iswin() then return end

describe('autoread libuv', function()
  local f1 = 'xtest-foo'
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
    screen:attach()
    feed_command('runtime plugin/autoread.vim')
  end)

  teardown(function()
    os.remove(f1)
  end)

  it('external file change, autoread enabled', function()
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

    screen:expect{grid=[[
      ^                                          |
      {1:~                                         }|
      {1:~                                         }|
      {1:~                                         }|
      :edit xtest-foo                           |
    ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1};
    }}

    helpers.write_file(path, expected_addition)
    screen:expect{grid=[[
      ^line 1                                    |
      line 2                                    |
      line 3                                    |
      line 4                                    |
      "xtest-foo" 4L, 28B                       |
    ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1};
    }}
  end)
end)
