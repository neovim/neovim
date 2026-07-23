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

describe("'previewpopup' and 'completepopup'", function()
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
        [101] = { background = Screen.colors.Grey0 },
      })
    end)

    describe("'previewpopup'", function()
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
              [2] = { height = 6, startcol = 0, startrow = 0, width = 40, win = 1000 },
            },
            float_pos = {
              [4] = { 1001, 'NW', 1, 1, 1, true, 50, 1, 1, 1 },
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
              [2] = { height = 5, startcol = 20, startrow = 0, width = 20, win = 1000 },
              [5] = { height = 5, startcol = 0, startrow = 0, width = 19, win = 1002 },
            },
            float_pos = {
              [4] = { 1001, 'NW', 1, 1, 21, true, 50, 1, 1, 21 },
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
    end)

    describe("'completepopup'", function()
      ---@return integer
      local function info_win()
        return fn.complete_info().preview_winid
      end

      -- oldtest: Get_popupmenu_lines()
      local function setup_popupmenu()
        exec([[
          set completeopt+=preview,popup
          set completefunc=CompleteFuncDict

          func CompleteFuncDict(findstart, base)
            if a:findstart
              return col('.') > 10 ? col('.') - 10 : 0
            endif
            return {'words': [
              \ {'word': 'aword', 'abbr': 'wrd', 'menu': 'extra text',
              \  'info': 'words are cool', 'kind': 'W', 'user_data': 'test'},
              \ {'word': 'anotherword', 'abbr': 'anotwrd', 'menu': 'extra text',
              \  'info': "other words are\ncooler than this and some more text\nto make wrap",
              \  'kind': 'W', 'user_data': 'notest'},
              \ {'word': 'noinfo', 'abbr': 'noawrd', 'menu': 'extra text',
              \  'info': "lets\nshow\na\nscrollbar\nhere", 'kind': 'W', 'user_data': 'notest'},
              \ {'word': 'thatword', 'abbr': 'thatwrd', 'menu': 'extra text',
              \  'info': 'that word is cool', 'kind': 'W', 'user_data': 'notest'},
              \ ]}
          endfunc

          call setline(1, 'text text text text text text text ')
        ]])
      end

      it('validation', function()
        local err = pcall_err(n.exec_capture, 'set completepopup=height:yes')
        eq(
          "nvim_exec2(), line 1: Vim(set):E474: 'height' requires a number: completepopup=height:yes",
          err
        )
        err = pcall_err(n.exec_capture, 'set completepopup=align:middle')
        eq(
          "nvim_exec2(), line 1: Vim(set):E474: 'align' must be one of: item, menu: completepopup=align:middle",
          err
        )
        err = pcall_err(n.exec_capture, 'set completepopup=bogus:1')
        eq("nvim_exec2(), line 1: Vim(set):E474: Unknown item 'bogus': completepopup=bogus:1", err)
        err = pcall_err(n.exec_capture, 'set previewpopup=align:menu')
        eq(
          "nvim_exec2(), line 1: Vim(set):E474: Unknown item 'align': previewpopup=align:menu",
          err
        )
        eq('', api.nvim_get_option_value('completepopup', {}))
      end)

      -- oldtest: Test_popupmenu_info_border
      it('info border', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=height:4,border:single,align:item')
        feed('A<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text taword^                                            |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
            ## grid 4
              {4:┌──────────────┐}|
              {4:│words are cool│}|
              {4:└──────────────┘}|
            ## grid 5
              {12: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = {
                height = 13,
                startcol = 0,
                startrow = 0,
                width = 75,
                win = 1000,
              },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 2, 1, 25 },
              [4] = { 1001, 'NW', 1, 0, 47, true, 50, 1, 0, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text taword^                {4:┌──────────────┐}            |
            {1:~                        }{12: wrd     W extra text }{4:│words are cool│}{1:            }|
            {1:~                        }{4: anotwrd W extra text └──────────────┘}{1:            }|
            {1:~                        }{4: noawrd  W extra text }{1:                            }|
            {1:~                        }{4: thatwrd W extra text }{1:                            }|
            {1:~                                                                          }|*8
            {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
          ]])
        end

        feed('<C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text tanotherword^                                      |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 2 of 4}                           |
            ## grid 4
              {4:┌─────────────────────────┐}|
              {4:│other words are          │}|
              {4:│cooler than this and some│}|
              {4:│ more text               │}|
              {4:│to make wrap             │}|
              {4:└─────────────────────────┘}|
            ## grid 5
              {4: wrd     W extra text }|
              {12: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 2, 1, 25 },
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tanotherword^                                      |
            {1:~                        }{4: wrd     W extra text ┌─────────────────────────┐}{1: }|
            {1:~                        }{12: anotwrd W extra text }{4:│other words are          │}{1: }|
            {1:~                        }{4: noawrd  W extra text │cooler than this and some│}{1: }|
            {1:~                        }{4: thatwrd W extra text │ more text               │}{1: }|
            {1:~                                              }{4:│to make wrap             │}{1: }|
            {1:~                                              }{4:└─────────────────────────┘}{1: }|
            {1:~                                                                          }|*6
            {5:-- User defined completion (^U^N^P) }{6:match 2 of 4}                           |
          ]])
        end

        feed('<C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text tnoinfo^                                           |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 3 of 4}                           |
            ## grid 4
              {4:┌─────────┐}|
              {4:│lets     │}|
              {4:│show     │}|
              {4:│a        │}|
              {4:│scrollbar│}|
              {4:└─────────┘}|
            ## grid 5
              {4: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {12: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 2, 1, 25 },
              [4] = { 1001, 'NW', 1, 2, 47, true, 50, 1, 2, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tnoinfo^                                           |
            {1:~                        }{4: wrd     W extra text }{1:                            }|
            {1:~                        }{4: anotwrd W extra text ┌─────────┐}{1:                 }|
            {1:~                        }{12: noawrd  W extra text }{4:│lets     │}{1:                 }|
            {1:~                        }{4: thatwrd W extra text │show     │}{1:                 }|
            {1:~                                              }{4:│a        │}{1:                 }|
            {1:~                                              }{4:│scrollbar│}{1:                 }|
            {1:~                                              }{4:└─────────┘}{1:                 }|
            {1:~                                                                          }|*5
            {5:-- User defined completion (^U^N^P) }{6:match 3 of 4}                           |
          ]])
        end

        feed('<C-n><C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text text text ^                                        |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{19:Back at original}                       |
            ## grid 4 (hidden)
              {4:┌─────────────────┐}|
              {4:│that word is cool│}|
              {4:└─────────────────┘}|
            ## grid 5
              {4: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 1, 1, 25 },
            },
          })
        else
          screen:expect([[
            text text text text text text text ^                                        |
            {1:~                        }{4: wrd     W extra text }{1:                            }|
            {1:~                        }{4: anotwrd W extra text }{1:                            }|
            {1:~                        }{4: noawrd  W extra text }{1:                            }|
            {1:~                        }{4: thatwrd W extra text }{1:                            }|
            {1:~                                                                          }|*8
            {5:-- User defined completion (^U^N^P) }{19:Back at original}                       |
          ]])
        end

        feed('test text test text<C-x><C-u>')
        feed('<C-n><C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text text text test text noinfo^                        |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 3 of 4}                           |
            ## grid 4
              {4:┌─────────┐}|
              {4:│lets     │}|
              {4:│show     │}|
              {4:│a        │}|
              {4:│scrollbar│}|
              {4:└─────────┘}|
            ## grid 5
              {4: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {12: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 44, false, 100, 2, 1, 44 },
              [4] = { 1001, 'NW', 1, 2, 33, true, 50, 1, 2, 33 },
            },
          })
        else
          screen:expect([[
            text text text text text text text test text noinfo^                        |
            {1:~                                           }{4: wrd     W extra text }{1:         }|
            {1:~                                }{4:┌─────────┐ anotwrd W extra text }{1:         }|
            {1:~                                }{4:│lets     │}{12: noawrd  W extra text }{1:         }|
            {1:~                                }{4:│show     │ thatwrd W extra text }{1:         }|
            {1:~                                }{4:│a        │}{1:                               }|
            {1:~                                }{4:│scrollbar│}{1:                               }|
            {1:~                                }{4:└─────────┘}{1:                               }|
            {1:~                                                                          }|*5
            {5:-- User defined completion (^U^N^P) }{6:match 3 of 4}                           |
          ]])
        end

        feed('<Esc>')
        command('set hidden')
        command('bn')
        command('bn')
        feed('otest text test text<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text text text test text noinfo                        |
              test text aword^                                                            |
              {1:~                                                                          }|*11
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ## grid 6
              {4:┌──────────────┐}|
              {4:│words are cool│}|
              {4:└──────────────┘}|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 2, 9, false, 100, 2, 2, 9 },
              [6] = { 1002, 'NW', 1, 1, 31, true, 50, 1, 1, 31 },
            },
          })
        else
          screen:expect([[
            text text text text text text text test text noinfo                        |
            test text aword^                {4:┌──────────────┐}                            |
            {1:~        }{12: wrd     W extra text }{4:│words are cool│}{1:                            }|
            {1:~        }{4: anotwrd W extra text └──────────────┘}{1:                            }|
            {1:~        }{4: noawrd  W extra text }{1:                                            }|
            {1:~        }{4: thatwrd W extra text }{1:                                            }|
            {1:~                                                                          }|*7
            {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
          ]])
        end

        -- Test that when the option is changed the popup changes.
        feed(' <Esc>')
        command('set completepopup+=width:10')
        feed('a<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text text text test text noinfo                        |
              test teaword^                                                               |
              {1:~                                                                          }|*11
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ## grid 7
              {4:┌──────────┐}|
              {4:│words are │}|
              {4:│cool      │}|
              {4:└──────────┘}|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 2, 6, false, 100, 2, 2, 6 },
              [7] = { 1003, 'NW', 1, 1, 28, true, 50, 1, 1, 28 },
            },
          })
        else
          screen:expect([[
            text text text text text text text test text noinfo                        |
            test teaword^                {4:┌──────────┐}                                   |
            {1:~     }{12: wrd     W extra text }{4:│words are │}{1:                                   }|
            {1:~     }{4: anotwrd W extra text │cool      │}{1:                                   }|
            {1:~     }{4: noawrd  W extra text └──────────┘}{1:                                   }|
            {1:~     }{4: thatwrd W extra text }{1:                                               }|
            {1:~                                                                          }|*7
            {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
          ]])
        end
      end)

      -- oldtest: Test_popupmenu_info_noborder
      it('info noborder', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=height:4,border:none')

        feed('A<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text taword^                                            |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
            ## grid 4
              {4:words are cool}|
            ## grid 5
              {12: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 2, 1, 25 },
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text taword^                                            |
            {1:~                        }{12: wrd     W extra text }{4:words are cool}{1:              }|
            {1:~                        }{4: anotwrd W extra text }{1:                            }|
            {1:~                        }{4: noawrd  W extra text }{1:                            }|
            {1:~                        }{4: thatwrd W extra text }{1:                            }|
            {1:~                                                                          }|*8
            {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
          ]])
        end
      end)

      -- oldtest: Test_popupmenu_info_align_menu
      it('info align menu', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=height:4,border:none,align:menu')

        feed('A<C-x><C-u>')
        feed('<C-n>')
        feed('<C-n>')
        feed('<C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text tthatword^                                         |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 4 of 4}                           |
            ## grid 4
              {4:that word is cool}|
            ## grid 5
              {4: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {12: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 2, 1, 25 },
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatword^                                         |
            {1:~                        }{4: wrd     W extra text that word is cool}{1:           }|
            {1:~                        }{4: anotwrd W extra text }{1:                            }|
            {1:~                        }{4: noawrd  W extra text }{1:                            }|
            {1:~                        }{12: thatwrd W extra text }{1:                            }|
            {1:~                                                                          }|*8
            {5:-- User defined completion (^U^N^P) }{6:match 4 of 4}                           |
          ]])
        end

        feed('test text test text test<C-x><C-u>')
        feed('<C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text tthatwordtest text test anotherword^               |
              {1:~                                                                          }|*12
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 2 of 4}                           |
            ## grid 4
              {4:other words are                    }|
              {4:cooler than this and some more text}|
              {4:to make wrap                       }|
            ## grid 5
              {4: wrd     W extra text }|
              {12: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'NW', 2, 1, 48, false, 100, 2, 1, 48 },
              [4] = { 1001, 'NW', 1, 1, 13, true, 50, 1, 1, 13 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatwordtest text test anotherword^               |
            {1:~            }{4:other words are                     wrd     W extra text }{1:     }|
            {1:~            }{4:cooler than this and some more text}{12: anotwrd W extra text }{1:     }|
            {1:~            }{4:to make wrap                        noawrd  W extra text }{1:     }|
            {1:~                                               }{4: thatwrd W extra text }{1:     }|
            {1:~                                                                          }|*8
            {5:-- User defined completion (^U^N^P) }{6:match 2 of 4}                           |
          ]])
        end

        feed('<Esc>')
        command("call setline(2, ['x']->repeat(10))")
        feed('Gotest text test text<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text tthatwordtest text test anotherword               |
              x                                                                          |*10
              test text aword^                                                            |
              {1:~                                                                          }|
            ## grid 3
              {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }|
              {4: anotwrd W extra text }|
              {4: noawrd  W extra text }|
              {4: thatwrd W extra text }|
            ## grid 6
              {4:words are cool}|
            ]],
            win_pos = {
              [2] = { height = 13, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'SW', 2, 11, 9, false, 100, 2, 7, 9 },
              [6] = { 1002, 'NW', 1, 7, 31, true, 50, 1, 7, 31 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatwordtest text test anotherword               |
            x                                                                          |*6
            x        {12: wrd     W extra text }{4:words are cool}                              |
            x        {4: anotwrd W extra text }                                            |
            x        {4: noawrd  W extra text }                                            |
            x        {4: thatwrd W extra text }                                            |
            test text aword^                                                            |
            {1:~                                                                          }|
            {5:-- User defined completion (^U^N^P) }{6:match 1 of 4}                           |
          ]])
        end
      end)

      -- oldtest: Test_popupmenu_info_align_item
      it('info align item', function()
        screen:try_resize(75, 15)
        exec([[
          func Omni_test(findstart, base)
            if a:findstart
              return col(".")
            endif
            return [
              \ #{word: "cp_match_array", info: "One\nTwo\nThree\nFour"},
              \ #{word: "cp_str", info: "Five\nSix\nSeven\nEight"},
              \ #{word: "cp_score", info: "Nine\nTen\nEleven\nTwelve"},
              \ ]
          endfunc
          set completepopup=border:single,align:item
          set cot=menu,menuone,popup,
          set omnifunc=Omni_test
          set number
        ]])
        feed('A' .. string.rep('<CR>', 12))
        feed('<C-x><C-o><C-n><C-n>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*14
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              {8:  1 }                                                                       |
              {8:  2 }                                                                       |
              {8:  3 }                                                                       |
              {8:  4 }                                                                       |
              {8:  5 }                                                                       |
              {8:  6 }                                                                       |
              {8:  7 }                                                                       |
              {8:  8 }                                                                       |
              {8:  9 }                                                                       |
              {8: 10 }                                                                       |
              {8: 11 }                                                                       |
              {8: 12 }                                                                       |
              {8: 13 }cp_score^                                                               |
              {1:~                                                                          }|
            ## grid 3
              {5:-- Omni completion (^O^N^P) }{6:match 3 of 3}                                   |
            ## grid 4
              {4:┌──────┐}|
              {4:│Nine  │}|
              {4:│Ten   │}|
              {4:│Eleven│}|
              {4:│Twelve│}|
              {4:└──────┘}|
            ## grid 5
              {4: cp_match_array }|
              {4: cp_str         }|
              {12: cp_score       }|
            ]],
            win_pos = {
              [2] = { height = 14, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [5] = { -1, 'SW', 2, 12, 3, false, 100, 2, 9, 3 },
              [4] = { 1001, 'SW', 1, 11, 19, true, 50, 1, 5, 19 },
            },
          })
        else
          screen:expect([[
            {8:  1 }                                                                       |
            {8:  2 }                                                                       |
            {8:  3 }                                                                       |
            {8:  4 }                                                                       |
            {8:  5 }                                                                       |
            {8:  6 }               {4:┌──────┐}                                                |
            {8:  7 }               {4:│Nine  │}                                                |
            {8:  8 }               {4:│Ten   │}                                                |
            {8:  9 }               {4:│Eleven│}                                                |
            {8: 10}{4: cp_match_array │Twelve│}                                                |
            {8: 11}{4: cp_str         └──────┘}                                                |
            {8: 12}{12: cp_score       }                                                        |
            {8: 13 }cp_score^                                                               |
            {1:~                                                                          }|
            {5:-- Omni completion (^O^N^P) }{6:match 3 of 3}                                   |
          ]])
        end
      end)

      -- oldtest: Test_popupmenu_info_too_wide
      it('info too wide', function()
        screen:try_resize(75, 8)
        exec([[
          call setline(1, range(10))

          set completeopt+=preview,popup
          set completepopup=align:menu
          set omnifunc=OmniFunc

          func OmniFunc(findstart, base)
            if a:findstart
              return 0
            endif

            let menuText = 'some long text to make sure the menu takes up all of the width of the window'
            return {'words': [
              \ {'word': 'scrap', 'menu': menuText,
              \  'info': "other words are\ncooler than this and some more text\nto make wrap"},
              \ {'word': 'scappier', 'menu': menuText, 'info': 'words are cool'},
              \ {'word': 'scrappier2', 'menu': menuText, 'info': 'words are cool'},
              \ ]}
          endfunc
        ]])
        feed('Ascr<C-x><C-o>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*7
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              scrap^                                                                      |
              1                                                                          |
              2                                                                          |
              3                                                                          |
              4                                                                          |
              5                                                                          |
              6                                                                          |
            ## grid 3
              {5:-- Omni completion (^O^N^P) }{6:match 1 of 3}                                   |
            ## grid 4
              {12:scrap      some long text to make sure the menu takes up all of the width >}|
              {4:scappier   some long text to make sure the menu takes up all of the width >}|
              {4:scrappier2 some long text to make sure the menu takes up all of the width >}|
            ]],
            win_pos = {
              [2] = { height = 7, startcol = 0, startrow = 0, width = 75, win = 1000 },
            },
            float_pos = {
              [4] = { -1, 'NW', 2, 1, 0, false, 100, 1, 1, 0 },
            },
          })
        else
          screen:expect([[
            scrap^                                                                      |
            {12:scrap      some long text to make sure the menu takes up all of the width >}|
            {4:scappier   some long text to make sure the menu takes up all of the width >}|
            {4:scrappier2 some long text to make sure the menu takes up all of the width >}|
            4                                                                          |
            5                                                                          |
            6                                                                          |
            {5:-- Omni completion (^O^N^P) }{6:match 1 of 3}                                   |
          ]])
        end
      end)

      it('cmdline completion', function()
        eq(
          { 'align:', 'border:', 'height:', 'width:' },
          fn.getcompletion('set completepopup=', 'cmdline')
        )
        eq({ 'item', 'menu' }, fn.getcompletion('set completepopup=align:', 'cmdline'))
        eq({ 'menu' }, fn.getcompletion('set completepopup=height:4,align:m', 'cmdline'))
        eq({ 'rounded' }, fn.getcompletion('set completepopup=border:ro', 'cmdline'))
        eq({ 'height:', 'width:', 'border:' }, fn.getcompletion('set previewpopup=', 'cmdline'))
        eq({ 'rounded' }, fn.getcompletion('set previewpopup=border:ro', 'cmdline'))
        eq({}, fn.getcompletion('set previewpopup=align:', 'cmdline'))
      end)

      it('align:item follows the selection', function()
        screen:try_resize(75, 15)
        exec([[
          func Omni_test(findstart, base)
            if a:findstart
              return col(".")
            endif
            return [
              \ #{word: "cp_match_array", info: "One\nTwo\nThree\nFour"},
              \ #{word: "cp_str", info: "Five\nSix\nSeven\nEight"},
              \ #{word: "cp_score", info: "Nine\nTen\nEleven\nTwelve"},
              \ ]
          endfunc
          set completepopup=border:single,align:item
          set cot=menu,menuone,popup,
          set omnifunc=Omni_test
        ]])
        feed('A<C-x><C-o>')
        local first = api.nvim_win_get_config(info_win())
        eq('NW', first.anchor)
        eq(false, first.hide)

        feed('<C-n>')
        eq(first.row + 1, api.nvim_win_get_config(info_win()).row)
        feed('<C-n>')
        eq(first.row + 2, api.nvim_win_get_config(info_win()).row)
        feed('<C-p>')
        eq(first.row + 1, api.nvim_win_get_config(info_win()).row)
      end)

      it('align:menu is the default', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=border:none')
        feed('A<C-x><C-u>')
        local row = api.nvim_win_get_config(info_win()).row
        feed('<C-n>')
        eq(row, api.nvim_win_get_config(info_win()).row)
      end)

      it('cmdline info popup with laststatus=2 follows selection', function()
        screen:try_resize(55, 12)
        exec([[
          set laststatus=2
          func CmdDictComp(A, L, P)
            return [
                  \ {'word': 'apple',  'info': 'A red fruit'},
                  \ {'word': 'banana', 'info': 'A yellow fruit'},
                  \ ]
          endfunc
          command -nargs=1 -complete=customlist,CmdDictComp DictCmd echo <q-args>
          set wildmenu wildoptions=pum completeopt=menu,popup
          set completepopup=align:item
        ]])
        local function cmdline_info_win()
          for _, win in ipairs(api.nvim_list_wins()) do
            if api.nvim_win_get_config(win).relative ~= '' then
              return win
            end
          end
        end

        feed(':DictCmd <Tab>')
        t.retry(nil, nil, function()
          eq(9, api.nvim_win_get_config(cmdline_info_win()).row)
        end)

        feed('<Tab>')
        t.retry(nil, nil, function()
          eq(10, api.nvim_win_get_config(cmdline_info_win()).row)
        end)
        feed('<Esc>')
      end)

      it('width caps the info window but does not pad it', function()
        screen:try_resize(75, 14)
        setup_popupmenu()

        command('set completepopup=border:none')
        feed('A<C-x><C-u><C-n>')
        local full = api.nvim_win_get_config(info_win()).width
        t.ok(full > 10)

        feed('<C-e><Esc>')
        command('set completepopup+=width:10')
        feed('A<C-x><C-u><C-n>')
        eq(10, api.nvim_win_get_config(info_win()).width)

        feed('<C-e><Esc>')
        command('set completepopup=border:none,width:30')
        feed('A<C-x><C-u>') -- aword: "words are cool" = 14
        eq(14, api.nvim_win_get_config(info_win()).width)
      end)

      it('width lifts the 10 column minimum when it fits', function()
        screen:try_resize(60, 12)
        exec([[
          call setline(1, range(10))
          set completeopt+=preview,popup
          set omnifunc=OmniFunc
          func OmniFunc(findstart, base)
            if a:findstart
              return 0
            endif
            let m = repeat('m', 12)
            let i = repeat('i', 60)
            return {'words': [
              \ {'word': 'scrap', 'menu': m, 'info': i},
              \ {'word': 'scappier', 'menu': m, 'info': i},
              \ {'word': 'scrappier2', 'menu': m, 'info': i},
              \ ]}
          endfunc
        ]])

        command('set completepopup=align:menu')
        feed('Ascr<C-x><C-o>')
        local avail = api.nvim_win_get_config(info_win()).width
        t.ok(avail >= 10)

        feed('<C-e><Esc>')
        screen:try_resize(60 - (avail - 8), 12)
        feed('Ascr<C-x><C-o>')
        eq(true, api.nvim_win_get_config(info_win()).hide)

        feed('<C-e><Esc>')
        command('set completepopup=align:menu,width:5')
        feed('Ascr<C-x><C-o>')
        eq(false, api.nvim_win_get_config(info_win()).hide)

        feed('<C-e><Esc>')
        command('set completepopup=align:menu,width:40')
        feed('Ascr<C-x><C-o>')
        eq(true, api.nvim_win_get_config(info_win()).hide)
      end)

      it('height caps the info window', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=height:2,border:none')
        feed('A<C-x><C-u><C-n><C-n>')
        eq(2, api.nvim_win_get_config(info_win()).height)

        feed('<C-e><Esc>')
        command('set completepopup=border:none')
        feed('A<C-x><C-u><C-n><C-n>')
        eq(5, api.nvim_win_get_config(info_win()).height)
      end)

      it('closes an existing info window when the option changes', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=border:none')
        feed('A<C-x><C-u>')
        local win = info_win()
        t.ok(win ~= nil and win ~= 0)

        command('set completepopup=border:single')
        eq(false, api.nvim_win_is_valid(win))
      end)
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
