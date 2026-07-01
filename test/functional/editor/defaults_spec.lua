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
    it('nvim.terminal.TermClose closes terminal with default shell on success', function()
      n.clear()
      n.api.nvim_set_option_value('shell', n.testprg('shell-test'), {})
      n.command('set shellcmdflag=EXIT shellredir= shellpipe= shellquote= shellxquote=')

      -- Should not block other events
      n.command('let g:n=0')
      n.command('au BufEnter * let g:n = g:n + 1')

      t.eq(1, n.exec_lua('vim.cmd.terminal(); return vim.g.n'))

      t.retry(nil, 1000, function()
        t.neq('terminal', n.api.nvim_get_option_value('buftype', { buf = 0 }))
        t.eq(2, n.eval('g:n'))
      end)
    end)
  end)

  describe('popupmenu', function()
    it('can be disabled by user', function()
      n.clear {
        args = { '+autocmd! nvim.popupmenu', '+aunmenu PopUp' },
      }
      local screen = Screen.new(40, 8)
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

  describe('key mappings', function()
    it('maps - to open parent directories', function()
      local root = t.tmpname(false)
      local file = root .. '/alpha.txt'
      t.mkdir(root)
      t.write_file(file, 'alpha', true)
      finally(function()
        n.rmdir(root)
      end)

      n.clear({ args_rm = { '-u', '--cmd' } })
      n.api.nvim_cmd({ cmd = 'edit', args = { file }, magic = { file = false, bar = false } }, {})
      n.feed('-')
      n.poke_eventloop()

      t.eq(root, n.api.nvim_buf_get_name(0))
      t.eq('directory', n.api.nvim_get_option_value('filetype', { buf = 0 }))
      t.eq({ 'alpha.txt' }, n.api.nvim_buf_get_lines(0, 0, -1, false))

      n.clear({ args_rm = { '--cmd' }, args = { '--noplugin' } })
      n.api.nvim_buf_set_lines(0, 0, -1, false, { '  alpha', '  beta' })
      n.api.nvim_win_set_cursor(0, { 2, 7 })
      n.feed('-')

      t.eq({ 1, 2 }, n.api.nvim_win_get_cursor(0))
      t.eq(false, n.exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    end)

    describe('Visual mode search mappings', function()
      it('handle various chars properly', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(60, 8)
        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGray4 },
          [2] = {
            foreground = Screen.colors.NvimLightGray2,
            background = Screen.colors.NvimDarkGray4,
          },
          [3] = {
            foreground = Screen.colors.NvimLightGrey1,
            background = Screen.colors.NvimDarkYellow,
          },
          [4] = {
            foreground = Screen.colors.NvimDarkGrey1,
            background = Screen.colors.NvimLightYellow,
          },
        })
        n.api.nvim_buf_set_lines(0, 0, -1, true, {
          [[testing <CR> /?\!1]],
          [[testing <CR> /?\!2]],
          [[testing <CR> /?\!3]],
          [[testing <CR> /?\!4]],
        })
        n.feed('gg0vf!')
        n.poke_eventloop()
        n.feed('*')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          /\Vtesting <CR> /?\\!                     [2/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          /\Vtesting <CR> /?\\!                     [3/4]             |
        ]])
        n.feed('G0vf!')
        n.poke_eventloop()
        n.feed('#')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          ?\Vtesting <CR> /?\\!                     [3/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          ?\Vtesting <CR> /?\\!                     [2/4]             |
        ]])
      end)
    end)

    describe('unimpaired-style mappings', function()
      it('show the command output when successful', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(40, 8)
        n.fn.setqflist({
          { filename = 'file1', text = 'item1' },
          { filename = 'file2', text = 'item2' },
        })

        n.feed(']q')

        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGrey4 },
          [2] = {
            background = Screen.colors.NvimDarkGrey4,
            foreground = Screen.colors.NvimLightGray2,
          },
        })
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:file2                 0,0-1          All}|
            (2 of 2): item2                         |
          ]],
        })
      end)

      it('do not show a full stack trace when unsuccessful #30625', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(40, 8)
        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGray4 },
          [2] = {
            background = Screen.colors.NvimDarkGray4,
            foreground = Screen.colors.NvimLightGrey2,
          },
          [3] = { foreground = Screen.colors.NvimLightRed },
          [4] = { foreground = Screen.colors.NvimLightCyan },
        })

        n.feed('[a')
        screen:expect({
          grid = [[
                                                    |
            {1:~                                       }|*4
            {2:                                        }|
            {3:E163: There is only one file to edit}    |
            {4:Press ENTER or type command to continue}^ |
          ]],
        })

        n.feed('[q')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E42: No Errors}                          |
          ]],
        })

        n.feed('[l')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E776: No location list}                  |
          ]],
        })

        n.feed('[t')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E73: Tag stack empty}                    |
          ]],
        })
      end)

      describe('[<Space>', function()
        it('adds an empty line above the current line', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.expect([[

          first line]])
        end)

        it('works with a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('5[<Space>')
          n.expect([[





          first line]])
        end)

        it('supports dot repetition', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.feed('.')
          n.expect([[


          first line]])
        end)

        it('supports dot repetition and a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.feed('3.')
          n.expect([[




          first line]])
        end)
      end)

      describe(']<Space>', function()
        it('adds an empty line below the current line', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.expect([[
          first line
          ]])
        end)

        it('works with a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('5]<Space>')
          n.expect([[
          first line




          ]])
        end)

        it('supports dot repetition', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.feed('.')
          n.expect([[
          first line

          ]])
        end)

        it('supports dot repetition and a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.feed('2.')
          n.expect([[
          first line


          ]])
        end)
      end)
    end)
  end)
end)
