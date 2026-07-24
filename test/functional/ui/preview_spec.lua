local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local os = require('os')

local describe, it, before_each = t.describe, t.it, t.before_each
local after_each, finally = t.after_each, t.finally
local clear, command, api, fn = n.clear, n.command, n.api, n.fn
local eq, pcall_err, write_file = t.eq, t.pcall_err, t.write_file
local exec, feed = n.exec, n.feed

describe("'previewpopup' and 'completepopup'", function()
  before_each(function()
    clear()
  end)

  local function with_ext_multigrid(multigrid)
    local screen, attrs
    before_each(function()
      screen = Screen.new(40, 7, { ext_multigrid = multigrid })
      attrs = {
        [0] = { bold = true, foreground = Screen.colors.Blue },
        [1] = { background = Screen.colors.LightMagenta },
        [2] = {
          background = Screen.colors.LightMagenta,
          bold = true,
          foreground = Screen.colors.Blue1,
        },
        [3] = { bold = true },
        [4] = { bold = true, reverse = true },
        [5] = { reverse = true },
        [6] = { background = Screen.colors.LightMagenta, bold = true, reverse = true },
        [7] = { foreground = Screen.colors.White, background = Screen.colors.Red },
        [8] = { bold = true, foreground = Screen.colors.SeaGreen4 },
        [9] = { background = Screen.colors.LightGrey, underline = true },
        [10] = {
          background = Screen.colors.LightGrey,
          underline = true,
          bold = true,
          foreground = Screen.colors.Magenta,
        },
        [11] = { bold = true, foreground = Screen.colors.Magenta },
        [12] = { background = Screen.colors.WebGrey },
        [13] = { background = Screen.colors.Yellow },
        [14] = {
          foreground = Screen.colors.Magenta1,
          background = Screen.colors.Plum1,
          bold = true,
        },
        [15] = { foreground = Screen.colors.Brown },
        [16] = { foreground = Screen.colors.Red },
        [17] = { background = Screen.colors.Grey0 },
      }
      screen:set_default_attr_ids(attrs)
    end)

    describe("'previewpopup'", function()
      it('validation', function()
        local err = pcall_err(n.exec_capture, 'set previewpopup=height:yes')
        eq("nvim_exec2(), line 1: Vim(set):E474: 'height' requires a number: previewpopup=height:yes", err)

        err = pcall_err(n.exec_capture, 'set previewpopup=width:yes')
        eq("nvim_exec2(), line 1: Vim(set):E474: 'width' requires a number: previewpopup=width:yes", err)

        err = pcall_err(n.exec_capture, 'set previewpopup=width:20,height;10')
        eq(
          "nvim_exec2(), line 1: Vim(set):E474: Unknown item 'height;10': previewpopup=width:20,height;10",
          err
        )
      end)

      -- oldtest: Test_previewpopup
      it('works with tags and search', function()
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
        local tagfile_lines = {}
        for i = 1, 20 do
          table.insert(tagfile_lines, tostring(i))
        end
        table.insert(tagfile_lines, 'theword is here')
        for i = 22, 27 do
          table.insert(tagfile_lines, tostring(i))
        end
        table.insert(tagfile_lines, 'this is another place')
        for i = 29, 40 do
          table.insert(tagfile_lines, tostring(i))
        end
        write_file('Xtagfile', table.concat(tagfile_lines, '\n'))

        local header_lines = {}
        for i = 1, 10 do
          table.insert(header_lines, tostring(i))
        end
        table.insert(header_lines, 'searched word is here')
        for i = 12, 20 do
          table.insert(header_lines, tostring(i))
        end
        write_file('Xheader.h', table.concat(header_lines, '\n'))
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
              find {13:^theword} somewhere                  |
              nine                                    |
              this is another word                    |
              very long line where the word is also an|
              other                                   |
              {0:~                                       }|*7
            ## grid 3
              /theword                                |
            ## grid 4
              {1:┌────────────}{14:Xtagfile}{1:────────────┐}|
              {1:│20                              │}|
              {1:│}{13:theword}{1: is here                 │}|
              {1:│22                              │}|
              {1:│23                              │}|
              {1:└────────────────────────────────┘}|
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
            find {13:^theword} somewhere                  |
            nine  {1:┌────────────}{14:Xtagfile}{1:────────────┐}|
            this i{1:│20                              │}|
            very l{1:│}{13:theword}{1: is here                 │}|
            other {1:│22                              │}|
            {0:~     }{1:│23                              │}|
            {0:~     }{1:└────────────────────────────────┘}|
            {0:~                                       }|*5
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
              find {13:^theword} somewhere                  |
              nine                                    |
              this is another word                    |
              very long line where the word is also an|
              other                                   |
              {0:~                                       }|*7
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
            find {13:^theword} somewhere                  |
            nine                                    |
            this is another word                    |
            very long line where the word is also an|
            other                                   |
            {0:~                                       }|*7
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
              find {13:^theword} somewhere                  |
              nine                                    |
              this is another word                    |
              very long line where the word is also an|
              other                                   |
              {0:~                                       }|*7
            ## grid 3
              /theword                                |
            ## grid 5
              {1:┌────────────}{14:Xtagfile}{1:────────────┐}|
              {1:│20                              │}|
              {1:│}{13:theword}{1: is here                 │}|
              {1:│22                              │}|
              {1:│23                              │}|
              {1:└────────────────────────────────┘}|
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
            find {13:^theword} somewhere                  |
            nine  {1:┌────────────}{14:Xtagfile}{1:────────────┐}|
            this i{1:│20                              │}|
            very l{1:│}{13:theword}{1: is here                 │}|
            other {1:│22                              │}|
            {0:~     }{1:│23                              │}|
            {0:~     }{1:└────────────────────────────────┘}|
            {0:~                                       }|*5
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
              find {13:^theword} somewhere                  |
              nine                                    |
              this is another word                    |
              very long line where the word is also an|
              other                                   |
              {0:~                                       }|*7
            ## grid 3
              /theword                                |
            ## grid 6
              {1:┌───────────}{14:Xheader.h}{1:────────────┐}|
              {1:│10                              │}|
              {1:│searched word is here           │}|
              {1:│12                              │}|
              {1:│13                              │}|
              {1:└────────────────────────────────┘}|
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
            find {13:^theword} somewhere                  |
            nine  {1:┌───────────}{14:Xheader.h}{1:────────────┐}|
            this i{1:│10                              │}|
            very l{1:│searched word is here           │}|
            other {1:│12                              │}|
            {0:~     }{1:│13                              │}|
            {0:~     }{1:└────────────────────────────────┘}|
            {0:~                                       }|*5
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
          t{1:le}{12: other          }{1:           }|
          t{1:le once                      }|
          o{1:ec only                      }|
          o{1:ec off                       }|
          o{1:ca one            hello')    }|
          o{1:" the end                    }|
          {0:~                             }|*2
          {3:-- }{8:match 1 of 5}               |
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

      it('pedit and border overrides', function()
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
              {0:~                                       }|*5
            ## grid 3
                                                      |
            ## grid 4
              {1:┌─}{14:foo}{1:─┐}|
              {1:│bar  │}|
              {1:│     │}|
              {1:└─────┘}|
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
            {0:~}{1:┌─}{14:foo}{1:─┐}{0:                                }|
            {0:~}{1:│bar  │}{0:                                }|
            {0:~}{1:│     │}{0:                                }|
            {0:~}{1:└─────┘}{0:                                }|
            {0:~                                       }|
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
              {5:[No Name]           }{4:[No Name]           }|
              [3:----------------------------------------]|
            ## grid 2
              ^                    |
              {0:~                   }|*4
            ## grid 3
                                                      |
            ## grid 4
              {1:┌}{14:<xist}{1:┐}|
              {1:│     │}|*2
              {1:└─────┘}|
            ## grid 5
                                 |
              {0:~                  }|*4
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
            {0:~                  }│{0:~}{1:┌}{14:<xist}{1:┐}{0:            }|
            {0:~                  }│{0:~}{1:│     │}{0:            }|*2
            {0:~                  }│{0:~}{1:└─────┘}{0:            }|
            {5:[No Name]           }{4:[No Name]           }|
                                                    |
          ]])
        end
        command('pclose') -- can close by pclose command
        eq(2, #api.nvim_list_wins())

        -- border overrides and falls back to 'winborder'
        command('only | set previewpopup=height:2,width:5,border:rounded | pedit foo')
        if multigrid then
        else
          screen:expect([[
            ^                                        |
            {0:~}{1:╭─}{14:foo}{1:─╮}{0:                                }|
            {0:~}{1:│bar  │}{0:                                }|
            {0:~}{1:│     │}{0:                                }|
            {0:~}{1:╰─────╯}{0:                                }|
            {0:~                                       }|
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
              {0:~                                       }|*5
            ## grid 3
                                                      |
            ## grid 7
              {1:bar  }|
              {1:     }|
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
            {0:~}{1:bar  }{0:                                  }|
            {0:~}{1:     }{0:                                  }|
            {0:~                                       }|*3
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
        eq("nvim_exec2(), line 1: Vim(set):E474: 'height' requires a number: completepopup=height:yes", err)
        err = pcall_err(n.exec_capture, 'set completepopup=align:middle')
        eq("nvim_exec2(), line 1: Vim(set):E474: 'align' must be one of: item, menu: completepopup=align:middle", err)
        err = pcall_err(n.exec_capture, 'set completepopup=bogus:1')
        eq("nvim_exec2(), line 1: Vim(set):E474: Unknown item 'bogus': completepopup=bogus:1", err)
        err = pcall_err(n.exec_capture, 'set previewpopup=align:menu')
        eq("nvim_exec2(), line 1: Vim(set):E474: Unknown item 'align': previewpopup=align:menu", err)
        eq('', api.nvim_get_option_value('completepopup', {}))
      end)

      -- oldtest: Test_popupmenu_info_border
      it('info border', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=height:4,border:single')
        feed('A<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              text text text text text taword^                                            |
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 4
              {1:┌──────────────┐}|
              {1:│words are cool│}|
              {1:└──────────────┘}|
            ## grid 5
              {12: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
            text text text text text taword^                {1:┌──────────────┐}            |
            {0:~                        }{12: wrd     W extra text }{1:│words are cool│}{0:            }|
            {0:~                        }{1: anotwrd W extra text └──────────────┘}{0:            }|
            {0:~                        }{1: noawrd  W extra text }{0:                            }|
            {0:~                        }{1: thatwrd W extra text }{0:                            }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 2 of 4}                           |
            ## grid 4
              {1:┌─────────────────────────┐}|
              {1:│other words are          │}|
              {1:│cooler than this and some│}|
              {1:│ more text               │}|
              {1:│to make wrap             │}|
              {1:└─────────────────────────┘}|
            ## grid 5
              {1: wrd     W extra text }|
              {12: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tanotherword^                                      |
            {0:~                        }{1: wrd     W extra text ┌─────────────────────────┐}{0: }|
            {0:~                        }{12: anotwrd W extra text }{1:│other words are          │}{0: }|
            {0:~                        }{1: noawrd  W extra text │cooler than this and some│}{0: }|
            {0:~                        }{1: thatwrd W extra text │ more text               │}{0: }|
            {0:~                                              }{1:│to make wrap             │}{0: }|
            {0:~                                              }{1:└─────────────────────────┘}{0: }|
            {0:~                                                                          }|*6
            {3:-- User defined completion (^U^N^P) }{8:match 2 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 3 of 4}                           |
            ## grid 4
              {1:┌─────────┐}|
              {1:│lets     │}|
              {1:│show     │}|
              {1:│a        │}|
              {1:│scrollbar│}|
              {1:└─────────┘}|
            ## grid 5
              {1: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {12: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [4] = { 1001, 'NW', 1, 2, 47, true, 50, 1, 2, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tnoinfo^                                           |
            {0:~                        }{1: wrd     W extra text }{0:                            }|
            {0:~                        }{1: anotwrd W extra text ┌─────────┐}{0:                 }|
            {0:~                        }{12: noawrd  W extra text }{1:│lets     │}{0:                 }|
            {0:~                        }{1: thatwrd W extra text │show     │}{0:                 }|
            {0:~                                              }{1:│a        │}{0:                 }|
            {0:~                                              }{1:│scrollbar│}{0:                 }|
            {0:~                                              }{1:└─────────┘}{0:                 }|
            {0:~                                                                          }|*5
            {3:-- User defined completion (^U^N^P) }{8:match 3 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{16:Back at original}                       |
            ## grid 4 (hidden)
              {1:┌─────────────────┐}|
              {1:│that word is cool│}|
              {1:└─────────────────┘}|
            ## grid 5
              {1: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [5] = { -1, 'NW', 2, 1, 25, false, 100, 1, 1, 25 },
            },
          })
        else
          screen:expect([[
            text text text text text text text ^                                        |
            {0:~                        }{1: wrd     W extra text }{0:                            }|
            {0:~                        }{1: anotwrd W extra text }{0:                            }|
            {0:~                        }{1: noawrd  W extra text }{0:                            }|
            {0:~                        }{1: thatwrd W extra text }{0:                            }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{16:Back at original}                       |
          ]])
        end

        -- info on the left with scrollbar
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 3 of 4}                           |
            ## grid 4
              {1:┌─────────┐}|
              {1:│lets     │}|
              {1:│show     │}|
              {1:│a        │}|
              {1:│scrollbar│}|
              {1:└─────────┘}|
            ## grid 5
              {1: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {12: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [5] = { -1, 'NW', 2, 1, 44, false, 100, 2, 1, 44 },
              [4] = { 1001, 'NW', 1, 2, 33, true, 50, 1, 2, 33 },
            },
          })
        else
          screen:expect([[
            text text text text text text text test text noinfo^                        |
            {0:~                                           }{1: wrd     W extra text }{0:         }|
            {0:~                                }{1:┌─────────┐ anotwrd W extra text }{0:         }|
            {0:~                                }{1:│lets     │}{12: noawrd  W extra text }{0:         }|
            {0:~                                }{1:│show     │ thatwrd W extra text }{0:         }|
            {0:~                                }{1:│a        │}{0:                               }|
            {0:~                                }{1:│scrollbar│}{0:                               }|
            {0:~                                }{1:└─────────┘}{0:                               }|
            {0:~                                                                          }|*5
            {3:-- User defined completion (^U^N^P) }{8:match 3 of 4}                           |
          ]])
        end

        -- Test that the popupmenu's scrollbar and infopopup do not overlap
        feed('<Esc>')
        command('set pumheight=3')
        command('set completepopup=border:none')
        feed('cc<C-x><C-u>')
        if multigrid then
          screen:expect({
            grid = [[
            ## grid 1
              [2:---------------------------------------------------------------------------]|*13
              [3:---------------------------------------------------------------------------]|
            ## grid 2
              aword^                                                                      |
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 5
              {12:wrd     W extra text }{17: }|
              {1:anotwrd W extra text }{17: }|
              {1:noawrd  W extra text }{12: }|
            ## grid 6
              {1:words are cool}|
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
              [5] = { -1, 'NW', 2, 1, 0, false, 100, 2, 1, 0 },
              [6] = { 1002, 'NW', 1, 1, 22, true, 50, 1, 1, 22 },
            },
          })
        else
          screen:expect([[
            aword^                                                                      |
            {12:wrd     W extra text }{17: }{1:words are cool}{0:                                       }|
            {1:anotwrd W extra text }{17: }{0:                                                     }|
            {1:noawrd  W extra text }{12: }{0:                                                     }|
            {0:~                                                                          }|*9
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              aword                                                                      |
              test text aword^                                                            |
              {0:~                                                                          }|*11
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }{17: }|
              {1: anotwrd W extra text }{17: }|
              {1: noawrd  W extra text }{12: }|
            ## grid 7
              {1:words are cool}|
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
              [7] = { 1003, 'NW', 1, 2, 32, true, 50, 1, 2, 32 },
              [5] = { -1, 'NW', 2, 2, 9, false, 100, 2, 2, 9 },
            },
          })
        else
          screen:expect([[
            aword                                                                      |
            test text aword^                                                            |
            {0:~        }{12: wrd     W extra text }{17: }{1:words are cool}{0:                             }|
            {0:~        }{1: anotwrd W extra text }{17: }{0:                                           }|
            {0:~        }{1: noawrd  W extra text }{12: }{0:                                           }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              aword                                                                      |
              test teaword^                                                               |
              {0:~                                                                          }|*11
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }{17: }|
              {1: anotwrd W extra text }{17: }|
              {1: noawrd  W extra text }{12: }|
            ## grid 8
              {1:words are }|
              {1:cool      }|
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
              [5] = { -1, 'NW', 2, 2, 6, false, 100, 2, 2, 6 },
              [8] = { 1004, 'NW', 1, 2, 29, true, 50, 1, 2, 29 },
            },
          })
        else
          screen:expect([[
            aword                                                                      |
            test teaword^                                                               |
            {0:~     }{12: wrd     W extra text }{17: }{1:words are }{0:                                    }|
            {0:~     }{1: anotwrd W extra text }{17: }{1:cool      }{0:                                    }|
            {0:~     }{1: noawrd  W extra text }{12: }{0:                                              }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 4
              {1:words are cool}|
            ## grid 5
              {12: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
            win_viewport = {
              [2] = {
                win = 1000,
                topline = 0,
                botline = 2,
                curline = 0,
                curcol = 31,
                linecount = 1,
                sum_scroll_delta = 0,
              },
              [4] = {
                win = 1001,
                topline = 0,
                botline = 1,
                curline = 0,
                curcol = 0,
                linecount = 1,
                sum_scroll_delta = 0,
              },
            },
          })
        else
          screen:expect([[
            text text text text text taword^                                            |
            {0:~                        }{12: wrd     W extra text }{1:words are cool}{0:              }|
            {0:~                        }{1: anotwrd W extra text }{0:                            }|
            {0:~                        }{1: noawrd  W extra text }{0:                            }|
            {0:~                        }{1: thatwrd W extra text }{0:                            }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 4 of 4}                           |
            ## grid 4
              {1:that word is cool}|
            ## grid 5
              {1: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {12: thatwrd W extra text }|
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
              [4] = { 1001, 'NW', 1, 1, 47, true, 50, 1, 1, 47 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatword^                                         |
            {0:~                        }{1: wrd     W extra text that word is cool}{0:           }|
            {0:~                        }{1: anotwrd W extra text }{0:                            }|
            {0:~                        }{1: noawrd  W extra text }{0:                            }|
            {0:~                        }{12: thatwrd W extra text }{0:                            }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 4 of 4}                           |
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
              {0:~                                                                          }|*12
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 2 of 4}                           |
            ## grid 4
              {1:other words are                    }|
              {1:cooler than this and some more text}|
              {1:to make wrap                       }|
            ## grid 5
              {1: wrd     W extra text }|
              {12: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
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
              [5] = { -1, 'NW', 2, 1, 48, false, 100, 2, 1, 48 },
              [4] = { 1001, 'NW', 1, 1, 13, true, 50, 1, 1, 13 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatwordtest text test anotherword^               |
            {0:~            }{1:other words are                     wrd     W extra text }{0:     }|
            {0:~            }{1:cooler than this and some more text}{12: anotwrd W extra text }{0:     }|
            {0:~            }{1:to make wrap                        noawrd  W extra text }{0:     }|
            {0:~                                               }{1: thatwrd W extra text }{0:     }|
            {0:~                                                                          }|*8
            {3:-- User defined completion (^U^N^P) }{8:match 2 of 4}                           |
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
              {0:~                                                                          }|
            ## grid 3
              {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
            ## grid 5
              {12: wrd     W extra text }|
              {1: anotwrd W extra text }|
              {1: noawrd  W extra text }|
              {1: thatwrd W extra text }|
            ## grid 6
              {1:words are cool}|
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
              [5] = { -1, 'SW', 2, 11, 9, false, 100, 2, 7, 9 },
              [6] = { 1002, 'SW', 1, 11, 31, true, 50, 1, 10, 31 },
            },
          })
        else
          screen:expect([[
            text text text text text tthatwordtest text test anotherword               |
            x                                                                          |*6
            x        {12: wrd     W extra text }                                            |
            x        {1: anotwrd W extra text }                                            |
            x        {1: noawrd  W extra text }                                            |
            x        {1: thatwrd W extra text words are cool}                              |
            test text aword^                                                            |
            {0:~                                                                          }|
            {3:-- User defined completion (^U^N^P) }{8:match 1 of 4}                           |
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
              {15:  1 }                                                                       |
              {15:  2 }                                                                       |
              {15:  3 }                                                                       |
              {15:  4 }                                                                       |
              {15:  5 }                                                                       |
              {15:  6 }                                                                       |
              {15:  7 }                                                                       |
              {15:  8 }                                                                       |
              {15:  9 }                                                                       |
              {15: 10 }                                                                       |
              {15: 11 }                                                                       |
              {15: 12 }                                                                       |
              {15: 13 }cp_score^                                                               |
              {0:~                                                                          }|
            ## grid 3
              {3:-- Omni completion (^O^N^P) }{8:match 3 of 3}                                   |
            ## grid 4
              {1:┌──────┐}|
              {1:│Nine  │}|
              {1:│Ten   │}|
              {1:│Eleven│}|
              {1:│Twelve│}|
              {1:└──────┘}|
            ## grid 5
              {1: cp_match_array }|
              {1: cp_str         }|
              {12: cp_score       }|
            ]],
            win_pos = {
              [2] = {
                height = 14,
                startcol = 0,
                startrow = 0,
                width = 75,
                win = 1000,
              },
            },
            float_pos = {
              [5] = { -1, 'SW', 2, 12, 3, false, 100, 2, 9, 3 },
              [4] = { 1001, 'SW', 1, 13, 19, true, 50, 1, 7, 19 },
            },
          })
        else
          screen:expect([[
            {15:  1 }                                                                       |
            {15:  2 }                                                                       |
            {15:  3 }                                                                       |
            {15:  4 }                                                                       |
            {15:  5 }                                                                       |
            {15:  6 }                                                                       |
            {15:  7 }                                                                       |
            {15:  8 }               {1:┌──────┐}                                                |
            {15:  9 }               {1:│Nine  │}                                                |
            {15: 10}{1: cp_match_array │Ten   │}                                                |
            {15: 11}{1: cp_str         │Eleven│}                                                |
            {15: 12}{12: cp_score       }{1:│Twelve│}                                                |
            {15: 13 }cp_score^       {1:└──────┘}                                                |
            {0:~                                                                          }|
            {3:-- Omni completion (^O^N^P) }{8:match 3 of 3}                                   |
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
              {3:-- Omni completion (^O^N^P) }{8:match 1 of 3}                                   |
            ## grid 4
              {12:scrap      some long text to make sure the menu takes up all of the width >}|
              {1:scappier   some long text to make sure the menu takes up all of the width >}|
              {1:scrappier2 some long text to make sure the menu takes up all of the width >}|
            ]],
            win_pos = {
              [2] = {
                height = 7,
                startcol = 0,
                startrow = 0,
                width = 75,
                win = 1000,
              },
            },
            float_pos = {
              [4] = { -1, 'NW', 2, 1, 0, false, 100, 1, 1, 0 },
            },
          })
        else
          screen:expect([[
            scrap^                                                                      |
            {12:scrap      some long text to make sure the menu takes up all of the width >}|
            {1:scappier   some long text to make sure the menu takes up all of the width >}|
            {1:scrappier2 some long text to make sure the menu takes up all of the width >}|
            4                                                                          |
            5                                                                          |
            6                                                                          |
            {3:-- Omni completion (^O^N^P) }{8:match 1 of 3}                                   |
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

      it('align:item is the default', function()
        screen:try_resize(75, 14)
        setup_popupmenu()
        command('set completepopup=border:none')
        feed('A<C-x><C-u>')
        local row = api.nvim_win_get_config(info_win()).row
        feed('<C-n>')
        eq(row + 1, api.nvim_win_get_config(info_win()).row)
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
