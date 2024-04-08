local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = t.clear
local command = t.command
local api = t.api
local feed = t.feed
local eq = t.eq

describe('matchparen', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear { args = { '-u', 'NORC' } }
    screen = Screen.new(20, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = 255 },
      [1] = { bold = true },
    })
  end)

  it('uses correct column after i_<Up>. Vim patch 7.4.1296', function()
    command('set noautoindent nosmartindent nocindent laststatus=0')
    eq(1, api.nvim_get_var('loaded_matchparen'))
    feed('ivoid f_test()<cr>')
    feed('{<cr>')
    feed('}')

    -- critical part: up + cr should result in an empty line in between the
    -- brackets... if the bug is there, the empty line will be before the '{'
    feed('<up>')
    feed('<cr>')

    screen:expect([[
      void f_test()       |
      {                   |
      ^                    |
      }                   |
      {1:-- INSERT --}        |
    ]])
  end)
end)
