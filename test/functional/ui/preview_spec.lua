local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local os = require('os')

local describe, it, before_each = t.describe, t.it, t.before_each
local after_each, finally = t.after_each, t.finally
local clear, command, api, fn = n.clear, n.command, n.api, n.fn
local eq, pcall_err, write_file = t.eq, t.pcall_err, t.write_file
local exec, feed = n.exec, n.feed

--- Joins lines "1".."count", with `overrides` (1-based row → text) substituted.
--- @param count integer
--- @param overrides table<integer, string>
local function numbered_lines(count, overrides)
  local lines = {} --- @type string[]
  for i = 1, count do
    lines[i] = overrides[i] or tostring(i)
  end
  return table.concat(lines, '\n')
end

describe("'previewpopup'", function()
  before_each(function()
    clear()
  end)

  local function with_ext_multigrid(multigrid)
    local screen ---@type test.functional.ui.screen
    before_each(function()
      screen = Screen.new(40, 7, { ext_multigrid = multigrid })
      screen:add_extra_attr_ids({
        [100] = {
          foreground = Screen.colors.Magenta1,
          background = Screen.colors.Plum1,
          bold = true,
        },
      })
    end)

    it('validation', function()
      local err = pcall_err(n.exec_capture, 'set previewpopup=height:yes')
      eq(
        "nvim_exec2(), line 1: Vim(set):E474: 'height' requires a number: previewpopup=height:yes",
        err
      )

      err = pcall_err(n.exec_capture, 'set previewpopup=width:yes')
      eq(
        "nvim_exec2(), line 1: Vim(set):E474: 'width' requires a number: previewpopup=width:yes",
        err
      )

      err = pcall_err(n.exec_capture, 'set previewpopup=width:20,height;10')
      eq(
        "nvim_exec2(), line 1: Vim(set):E474: Unknown item 'height;10': previewpopup=width:20,height;10",
        err
      )

      err = pcall_err(n.exec_capture, 'set previewpopup=border:fancy')
      eq(
        'nvim_exec2(), line 1: Vim(set):E474: '
          .. "'border' must be one of: double, single, shadow, rounded, solid, bold, none: "
          .. 'previewpopup=border:fancy',
        err
      )

      -- height/width must be >= 1 (semantic check, not the schema).
      err = pcall_err(n.exec_capture, 'set previewpopup=height:0')
      eq('nvim_exec2(), line 1: Vim(set):E474: Invalid argument: previewpopup=height:0', err)
    end)

    -- oldtest: Test_previewpopup
    it('with tags and search', function()
      finally(function()
        os.remove('Xtags')
        os.remove('Xtagfile')
        os.remove('Xheader.h')
      end)
      screen:try_resize(40, 20)
      write_file(
        'Xtags',
        t.dedent([[
          !_TAG_FILE_ENCODING	utf-8	//
          another	Xtagfile	/^this is another
          theword	Xtagfile	/^theword
        ]])
      )
      write_file(
        'Xtagfile',
        numbered_lines(40, { [21] = 'theword is here', [28] = 'this is another place' })
      )
      write_file('Xheader.h', numbered_lines(20, { [11] = 'searched word is here' }))
      command('set tags=Xtags')
      api.nvim_buf_set_lines(0, 0, -1, false, {
        'one',
        '#include "Xheader.h"',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'find theword somewhere',
        'nine',
        'this is another word',
        'very long line where the word is also another',
      })
      command('set previewpopup=height:4,width:40')
      command('set winborder=single')
      command('set path=.')

      feed('/theword<CR><C-W>}')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*19
            [3:----------------------------------------]|
          ## grid 2
            one                                     |
            #include "Xheader.h"                    |
            three                                   |
            four                                    |
            five                                    |
            six                                     |
            seven                                   |
            find {10:^theword} somewhere                  |
            nine                                    |
            this is another word                    |
            very long line where the word is also an|
            other                                   |
            {1:~                                       }|*7
          ## grid 3
            /theword                                |
          ## grid 4
            {4:┌────────────}{100:Xtagfile}{4:────────────┐}|
            {4:│20                              │}|
            {4:│}{10:theword}{4: is here                 │}|
            {4:│22                              │}|
            {4:│23                              │}|
            {4:└────────────────────────────────┘}|
          ]],
          win_pos = {
            [2] = { height = 19, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = {
            [4] = { 1001, 'NW', 1, 8, 6, true, 50, 1, 8, 6 },
          },
        })
      else
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {10:^theword} somewhere                  |
          nine  {4:┌────────────}{100:Xtagfile}{4:────────────┐}|
          this i{4:│20                              │}|
          very l{4:│}{10:theword}{4: is here                 │}|
          other {4:│22                              │}|
          {1:~     }{4:│23                              │}|
          {1:~     }{4:└────────────────────────────────┘}|
          {1:~                                       }|*5
          /theword                                |
        ]])
      end

      command('pclose')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*19
            [3:----------------------------------------]|
          ## grid 2
            one                                     |
            #include "Xheader.h"                    |
            three                                   |
            four                                    |
            five                                    |
            six                                     |
            seven                                   |
            find {10:^theword} somewhere                  |
            nine                                    |
            this is another word                    |
            very long line where the word is also an|
            other                                   |
            {1:~                                       }|*7
          ## grid 3
            /theword                                |
          ]],
          win_pos = {
            [2] = { height = 19, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
        })
      else
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {10:^theword} somewhere                  |
          nine                                    |
          this is another word                    |
          very long line where the word is also an|
          other                                   |
          {1:~                                       }|*7
          /theword                                |
        ]])
      end

      command([[set include=^\s*#\s*include]])
      command('pedit +/theword Xtagfile')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*19
            [3:----------------------------------------]|
          ## grid 2
            one                                     |
            #include "Xheader.h"                    |
            three                                   |
            four                                    |
            five                                    |
            six                                     |
            seven                                   |
            find {10:^theword} somewhere                  |
            nine                                    |
            this is another word                    |
            very long line where the word is also an|
            other                                   |
            {1:~                                       }|*7
          ## grid 3
            /theword                                |
          ## grid 5
            {4:┌────────────}{100:Xtagfile}{4:────────────┐}|
            {4:│20                              │}|
            {4:│}{10:theword}{4: is here                 │}|
            {4:│22                              │}|
            {4:│23                              │}|
            {4:└────────────────────────────────┘}|
          ]],
          win_pos = {
            [2] = { height = 19, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = {
            [5] = { 1002, 'NW', 1, 8, 6, true, 50, 1, 8, 6 },
          },
        })
      else
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {10:^theword} somewhere                  |
          nine  {4:┌────────────}{100:Xtagfile}{4:────────────┐}|
          this i{4:│20                              │}|
          very l{4:│}{10:theword}{4: is here                 │}|
          other {4:│22                              │}|
          {1:~     }{4:│23                              │}|
          {1:~     }{4:└────────────────────────────────┘}|
          {1:~                                       }|*5
          /theword                                |
        ]])
      end

      command('pclose | psearch searched')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*19
            [3:----------------------------------------]|
          ## grid 2
            one                                     |
            #include "Xheader.h"                    |
            three                                   |
            four                                    |
            five                                    |
            six                                     |
            seven                                   |
            find {10:^theword} somewhere                  |
            nine                                    |
            this is another word                    |
            very long line where the word is also an|
            other                                   |
            {1:~                                       }|*7
          ## grid 3
            /theword                                |
          ## grid 6
            {4:┌───────────}{100:Xheader.h}{4:────────────┐}|
            {4:│10                              │}|
            {4:│searched word is here           │}|
            {4:│12                              │}|
            {4:│13                              │}|
            {4:└────────────────────────────────┘}|
          ]],
          win_pos = {
            [2] = { height = 19, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = {
            [6] = { 1003, 'NW', 1, 8, 6, true, 50, 1, 8, 6 },
          },
        })
      else
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {10:^theword} somewhere                  |
          nine  {4:┌───────────}{100:Xheader.h}{4:────────────┐}|
          this i{4:│10                              │}|
          very l{4:│searched word is here           │}|
          other {4:│12                              │}|
          {1:~     }{4:│13                              │}|
          {1:~     }{4:└────────────────────────────────┘}|
          {1:~                                       }|*5
          /theword                                |
        ]])
      end
    end)

    describe('with pum', function()
      before_each(function()
        write_file(
          'XpreviewText.vim',
          t.dedent([[
            let a = 3
            let b = 1
            echo a
            echo b
            call system('echo hello')
            " the end
          ]])
        )
      end)
      after_each(function()
        os.remove('XpreviewText.vim')
      end)
      local expect_screen = [[
        one other^                     |
        t{4:le}{12: other          }{4:           }|
        t{4:le once                      }|
        o{4:ec only                      }|
        o{4:ec off                       }|
        o{4:ca one            hello')    }|
        o{4:" the end                    }|
        {1:~                             }|*2
        {5:-- }{6:match 1 of 5}               |
      ]]

      -- oldtest: Test_previewpopup_pum_pedit
      it('pum pedit', function()
        screen:try_resize(30, 10)
        exec([[
          call setline(1, ['one', 'two', 'three', 'other', 'once', 'only', 'off'])
          set previewpopup=height:6,width:40
        ]])
        command('pedit XpreviewText.vim')
        feed('A o<C-N>')
        if not multigrid then
          screen:expect(expect_screen)
        end
      end)

      -- oldtest: Test_previewpopup_pum_pbuffer
      it('pum pbuffer', function()
        screen:try_resize(30, 10)
        exec([[
          call setline(1, ['one', 'two', 'three', 'other', 'once', 'only', 'off'])
          set previewpopup=height:6,width:40
          badd XpreviewText.vim
        ]])
        command(fn.bufnr('$') .. 'pbuffer')
        feed('A o<C-N>')
        if not multigrid then
          screen:expect(expect_screen)
        end
      end)
    end)

    it(':pedit and border overrides', function()
      command('call writefile(["bar"], "foo", "a")')
      finally(function()
        os.remove('foo')
      end)
      command('set winborder=single | set previewpopup=height:2,width:5 | pedit foo')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
            {1:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            {4:┌─}{100:foo}{4:─┐}|
            {4:│bar  │}|
            {4:│     │}|
            {4:└─────┘}|
          ]],
          win_pos = {
            [2] = {
              height = 6,
              startcol = 0,
              startrow = 0,
              width = 40,
              win = 1000,
            },
          },
          float_pos = {
            [4] = { 1001, 'NW', 1, 1, 1, true, 50, 1, 1, 1 },
          },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
          },
        })
      else
        screen:expect([[
          ^                                        |
          {1:~}{4:┌─}{100:foo}{4:─┐}{1:                                }|
          {1:~}{4:│bar  │}{1:                                }|
          {1:~}{4:│     │}{1:                                }|
          {1:~}{4:└─────┘}{1:                                }|
          {1:~                                       }|
                                                  |
        ]])
      end

      -- move floating preview window to current split window
      command('vs | wincmd p | pedit none_exist')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [5:-------------------]│[2:--------------------]|*5
            {2:[No Name]           }{3:[No Name]           }|
            [3:----------------------------------------]|
          ## grid 2
            ^                    |
            {1:~                   }|*4
          ## grid 3
                                                    |
          ## grid 4
            {4:┌}{100:<xist}{4:┐}|
            {4:│     │}|*2
            {4:└─────┘}|
          ## grid 5
                               |
            {1:~                  }|*4
          ]],
          win_pos = {
            [2] = {
              height = 5,
              startcol = 20,
              startrow = 0,
              width = 20,
              win = 1000,
            },
            [5] = {
              height = 5,
              startcol = 0,
              startrow = 0,
              width = 19,
              win = 1002,
            },
          },
          float_pos = {
            [4] = { 1001, 'NW', 1, 1, 21, true, 50, 1, 1, 21 },
          },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
            [5] = {
              win = 1002,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
          },
          win_viewport_margins = {
            [2] = {
              bottom = 0,
              left = 0,
              right = 0,
              top = 0,
              win = 1000,
            },
            [4] = {
              bottom = 1,
              left = 1,
              right = 1,
              top = 1,
              win = 1001,
            },
            [5] = {
              bottom = 0,
              left = 0,
              right = 0,
              top = 0,
              win = 1002,
            },
          },
        })
      else
        screen:expect([[
                             │^                    |
          {1:~                  }│{1:~}{4:┌}{100:<xist}{4:┐}{1:            }|
          {1:~                  }│{1:~}{4:│     │}{1:            }|*2
          {1:~                  }│{1:~}{4:└─────┘}{1:            }|
          {2:[No Name]           }{3:[No Name]           }|
                                                  |
        ]])
      end
      command('pclose') -- can close by pclose command
      eq(2, #api.nvim_list_wins())

      -- border overrides and falls back to 'winborder'
      command('only | set previewpopup=height:2,width:5,border:rounded | pedit foo')
      if not multigrid then
        screen:expect([[
          ^                                        |
          {1:~}{4:╭─}{100:foo}{4:─╮}{1:                                }|
          {1:~}{4:│bar  │}{1:                                }|
          {1:~}{4:│     │}{1:                                }|
          {1:~}{4:╰─────╯}{1:                                }|
          {1:~                                       }|
                                                  |
        ]])
      end
      command('pclose | set previewpopup+=border:none | pedit foo')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
            {1:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 7
            {4:bar  }|
            {4:     }|
          ]],
          win_pos = {
            [2] = { height = 6, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = {
            [7] = { 1004, 'NW', 1, 1, 1, true, 50, 1, 1, 1 },
          },
        })
      else
        screen:expect([[
          ^                                        |
          {1:~}{4:bar  }{1:                                  }|
          {1:~}{4:     }{1:                                  }|
          {1:~                                       }|*3
                                                  |
        ]])
      end
    end)

    it('autosizes to content when height/width are omitted', function()
      screen:try_resize(40, 20)
      command('call writefile(["short", "a much longer line here"], "foo")')
      finally(function()
        os.remove('foo')
      end)
      command('set previewpopup=border:none | pedit foo')

      local pwin ---@type integer
      for _, w in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_config(w).relative ~= '' then
          pwin = w
          break
        end
      end
      local conf = api.nvim_win_get_config(pwin)
      eq(23, conf.width) -- longest line
      eq(2, conf.height) -- line count
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
