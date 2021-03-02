-- See also: src/nvim/testdir/test_options.vim
local helpers = require('test.functional.helpers')(after_each)
local command, clear = helpers.command, helpers.clear
local source, expect = helpers.source, helpers.expect
local exc_exec = helpers.exc_exec;
local matches = helpers.matches;
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
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
      ~                                         |
                                                |
        scroll=7                                |
              Last set from changed window size |
      Press ENTER or type command to continue^   |
    ]])
  end)
end)
