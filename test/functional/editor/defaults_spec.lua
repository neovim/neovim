--
-- Tests for default autocmds, mappings, commands, and menus.
--
-- See options/defaults_spec.lua for default options and environment decisions.
--

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

describe('default', function()
  describe('autocommands', function()
    it('nvim_terminal.TermClose closes terminal with default shell on success', function()
      n.clear()
      n.api.nvim_set_option_value('shell', n.testprg('shell-test'), {})
      n.command('set shellcmdflag=EXIT shellredir= shellpipe= shellquote= shellxquote=')

      -- Should not block other events
      n.command('let g:n=0')
      n.command('au BufEnter * let g:n = g:n + 1')

      n.command('terminal')
      t.eq(1, n.eval('get(g:, "n", 0)'))

      t.retry(nil, 1000, function()
        t.neq('terminal', n.api.nvim_get_option_value('buftype', { buf = 0 }))
        t.eq(2, n.eval('get(g:, "n", 0)'))
      end)
    end)
  end)

  describe('popupmenu', function()
    it('can be disabled by user', function()
      n.clear {
        args = { '+autocmd! nvim_popupmenu', '+aunmenu PopUp' },
      }
      local screen = Screen.new(40, 8)
      screen:attach()
      n.insert([[
        1 line 1
        2 https://example.com
        3 line 3
        4 line 4]])

      n.api.nvim_input_mouse('right', 'press', '', 0, 1, 4)
      screen:expect({
        grid = [[
          1 line 1                                |
          2 ht^tps://example.com                   |
          3 line 3                                |
          4 line 4                                |
          {1:~                                       }|*3
                                                  |
        ]],
      })
    end)

    it('right-click on URL shows "Open in web browser"', function()
      n.clear()
      local screen = Screen.new(40, 8)
      screen:attach()
      n.insert([[
        1 line 1
        2 https://example.com
        3 line 3
        4 line 4]])

      n.api.nvim_input_mouse('right', 'press', '', 0, 3, 4)
      screen:expect({
        grid = [[
          1 line 1                                |
          2 https://example.com                   |
          3 line 3                                |
          4 li^ne 4                                |
          {1:~  }{4: Inspect              }{1:               }|
          {1:~  }{4:                      }{1:               }|
          {1:~  }{4: Paste                }{1:               }|
             {4: Select All           }               |
        ]],
      })

      n.api.nvim_input_mouse('right', 'press', '', 0, 1, 4)
      screen:expect({
        grid = [[
          1 line 1                                |
          2 ht^tps://example.com                   |
          3 l{4: Open in web browser  }               |
          4 l{4: Inspect              }               |
          {1:~  }{4:                      }{1:               }|
          {1:~  }{4: Paste                }{1:               }|
          {1:~  }{4: Select All           }{1:               }|
             {4:                      }               |
        ]],
      })
    end)
  end)

  -- describe('key mappings', function()
  -- end)
end)
