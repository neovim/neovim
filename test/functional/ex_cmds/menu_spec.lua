local helpers = require('test.functional.helpers')(after_each)
local clear, command, nvim = helpers.clear, helpers.command, helpers.nvim
local expect, feed = helpers.expect, helpers.feed
local eq, eval = helpers.eq, helpers.eval

describe(':emenu', function()

  before_each(function()
    clear()
    command('nnoremenu Test.Test inormal<ESC>')
    command('inoremenu Test.Test insert')
    command('vnoremenu Test.Test x')
    command('cnoremenu Test.Test cmdmode')

    command('nnoremenu Edit.Paste p')
    command('cnoremenu Edit.Paste <C-R>"')
  end)

  it('executes correct bindings in normal mode without using API', function()
    command('emenu Test.Test')
    expect('normal')
  end)

  it('executes correct bindings in normal mode', function()
    command('emenu Test.Test')
    expect('normal')
  end)

  it('executes correct bindings in insert mode', function()
    feed('i')
    command('emenu Test.Test')
    expect('insert')
  end)

  it('executes correct bindings in visual mode', function()
    feed('iabcde<ESC>0lvll')
    command('emenu Test.Test')
    expect('ae')
  end)

  it('executes correct bindings in command mode', function()
      feed('ithis is a sentence<esc>^yiwo<esc>')

      -- Invoke "Edit.Paste" in normal-mode.
      nvim('command', 'emenu Edit.Paste')

      -- Invoke "Edit.Paste" and "Test.Test" in command-mode.
      feed(':')
      nvim('command', 'emenu Edit.Paste')
      nvim('command', 'emenu Test.Test')

      expect([[
        this is a sentence
        this]])
      -- Assert that Edit.Paste pasted @" into the commandline.
      eq('thiscmdmode', eval('getcmdline()'))
  end)
end)
