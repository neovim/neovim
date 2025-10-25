local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed

describe('cmdwin', function()
  before_each(clear)

  -- oldtest: Test_cmdwin_interrupted()
  it('still uses a new buffer when interrupting more prompt on open', function()
    local screen = Screen.new(30, 16)
    command('set more')
    command('autocmd WinNew * highlight')
    feed('q:')
    screen:expect({ any = vim.pesc('{6:-- More --}^') })
    feed('q')
    screen:expect([[
                                    |
      {1:~                             }|*5
      {2:[No Name]                     }|
      {1::}^                             |
      {1:~                             }|*6
      {3:[Command Line]                }|
                                    |
    ]])
    feed([[aecho 'done']])
    screen:expect([[
                                    |
      {1:~                             }|*5
      {2:[No Name]                     }|
      {1::}echo 'done'^                  |
      {1:~                             }|*6
      {3:[Command Line]                }|
      {5:-- INSERT --}                  |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                              |
      {1:~                             }|*14
      done                          |
    ]])
  end)

  -- oldtest: Test_cmdwin_showcmd()
  it('has correct showcmd', function()
    local screen = Screen.new(60, 18)
    command('set showcmd')
    for _, keys in ipairs({ 'q:', ':<C-F>' }) do
      feed(keys)
      local fmt = [[
                                                                    |
        {1:~                                                           }|*7
        {2:[No Name]                                                   }|
        {1::}^                                                           |
        {1:~                                                           }|*6
        {3:[Command Line]                                              }|
        :                                                %s |
      ]]
      screen:expect(fmt:format('          '))
      feed('"')
      screen:expect(fmt:format('"         '))
      feed('x')
      screen:expect(fmt:format('"x        '))
      feed('y')
      screen:expect(fmt:format('"xy       '))
      feed('y')
      screen:expect(fmt:format('          '))
      feed('<C-C>')
      n.poke_eventloop()
      feed('<C-C>')
      screen:expect([[
        ^                                                            |
        {1:~                                                           }|*16
                                                                    |
      ]])
    end
  end)
end)
