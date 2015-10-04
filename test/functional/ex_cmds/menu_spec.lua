local helpers = require('test.functional.helpers')
local clear, execute, nvim = helpers.clear, helpers.execute, helpers.nvim
local expect, feed, command = helpers.expect, helpers.feed, helpers.command
local eq, eval = helpers.eq, helpers.eval

describe(':emenu', function()

  before_each(function()
    clear()
    execute('nnoremenu Test.Test inormal<ESC>')
    execute('inoremenu Test.Test insert')
    execute('vnoremenu Test.Test x')
    execute('cnoremenu Test.Test cmdmode')

    execute('nnoremenu Edit.Paste p')
    execute('cnoremenu Edit.Paste <C-R>"')
  end)

  it('executes correct bindings in normal mode without using API', function()
    execute('emenu Test.Test')
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
      feed('ithis is a sentence<esc>^"+yiwo<esc>')

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
