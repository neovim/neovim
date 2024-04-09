-- See also: test/old/testdir/test_options.vim
local t = require('test.functional.testutil')()
local command, clear = t.command, t.clear
local source, expect = t.source, t.expect
local exc_exec = t.exc_exec
local matches = t.matches
local Screen = require('test.functional.ui.screen')

describe('options', function()
  setup(clear)

  it('should not throw any exception', function()
    command('options')
  end)
end)

describe('set', function()
  before_each(clear)

  it("should keep two comma when 'path' is changed", function()
    source([[
      set path=foo,,bar
      set path-=bar
      set path+=bar
      $put =&path]])

    expect([[

      foo,,bar]])
  end)

  it('winminheight works', function()
    local screen = Screen.new(20, 11)
    screen:attach()
    source([[
      set wmh=0 stal=2
      below sp | wincmd _
      below sp | wincmd _
      below sp | wincmd _
      below sp
    ]])
    matches('E36: Not enough room', exc_exec('set wmh=1'))
  end)

  it('winminheight works with tabline', function()
    local screen = Screen.new(20, 11)
    screen:attach()
    source([[
      set wmh=0 stal=2
      split
      split
      split
      split
      tabnew
    ]])
    matches('E36: Not enough room', exc_exec('set wmh=1'))
  end)

  it('scroll works', function()
    local screen = Screen.new(42, 16)
    screen:attach()
    source([[
      set scroll=2
      set laststatus=2
    ]])
    command('verbose set scroll?')
    screen:expect([[
                                                |
      {1:~                                         }|*11
      {3:                                          }|
        scroll=7                                |
              Last set from changed window size |
      {6:Press ENTER or type command to continue}^   |
    ]])
  end)

  it('foldcolumn and signcolumn to empty string is disallowed', function()
    matches('E474: Invalid argument: fdc=', exc_exec('set fdc='))
    matches('E474: Invalid argument: scl=', exc_exec('set scl='))
  end)
end)
