local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen').new(40,4)
local clear, execute, nvim = helpers.clear, helpers.execute, helpers.nvim
local expect = helpers.expect
local feed = helpers.feed
local command = helpers.command

describe(':emenu', function()

  before_each(function()
    clear()
    execute('nnoremenu Test.Test inormal<ESC>')
    execute('inoremenu Test.Test insert')
    execute('vnoremenu Test.Test x')
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

end)

describe('emenu Edit.Paste while in commandline', function()
    before_each(function()
      clear()
      screen = Screen.new(40, 4)
      screen:attach()
    end)

    it('ok', function()
        nvim('command', 'runtime menu.vim')
        feed('ithis is a sentence<esc>^"+yiwo<esc>')
        nvim('command', 'emenu Edit.Paste')
        feed(':')
        nvim('command', 'emenu Edit.Paste')
        screen:expect([[
          this is a sentence                      |
          this                                    |
          ~                                       |
          :this^                                   |
        ]])
    end)
end)
