local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local os = require('os')

local clear, command, api, fn = n.clear, n.command, n.api, n.fn
local eq, pcall_err, write_file = t.eq, t.pcall_err, t.write_file
local exec, feed = n.exec, n.feed

describe('previewpopup option', function()
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
      }
      screen:set_default_attr_ids(attrs)
    end)

    -- oldtest: Test_previewpopup
    it('works with tags and search', function()
      screen:try_resize(40, 20)
      write_file(
        'Xtags',
        [[
!_TAG_FILE_ENCODING	utf-8	//
another	Xtagfile	/^this is another
theword	Xtagfile	/^theword
      ]]
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
            ┌────────────{11:Xtagfile}────────────┐|
            │{1:20                              }│|
            │{13:theword}{1: is here                 }│|
            │{1:22                              }│|
            │{1:23                              }│|
            └────────────────────────────────┘|
          ]],
          win_pos = {
            [2] = { height = 19, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = {
            [4] = { 1001, 'NW', 1, 8, 6, false, 50, 1, 8, 6 },
          },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 12,
              curline = 7,
              curcol = 5,
              linecount = 11,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 19,
              botline = 24,
              curline = 20,
              curcol = 0,
              linecount = 40,
              sum_scroll_delta = 19,
            },
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
          nine  ┌────────────{11:Xtagfile}────────────┐|
          this i│{1:20                              }│|
          very l│{13:theword}{1: is here                 }│|
          other │{1:22                              }│|
          {0:~     }│{1:23                              }│|
          {0:~     }└────────────────────────────────┘|
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
            [2] = {
              height = 19,
              startcol = 0,
              startrow = 0,
              width = 40,
              win = 1000,
            },
          },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 12,
              curline = 7,
              curcol = 5,
              linecount = 11,
              sum_scroll_delta = 0,
            },
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
      if not multigrid then
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {13:^theword} somewhere                  |
          nine  ┌────────────{11:Xtagfile}────────────┐|
          this i│{1:20                              }│|
          very l│{13:theword}{1: is here                 }│|
          other │{1:22                              }│|
          {0:~     }│{1:23                              }│|
          {0:~     }└────────────────────────────────┘|
          {0:~                                       }|*5
          /theword                                |
        ]])
      end

      command('pclose')
      command('psearch searched')
      if not multigrid then
        screen:expect([[
          one                                     |
          #include "Xheader.h"                    |
          three                                   |
          four                                    |
          five                                    |
          six                                     |
          seven                                   |
          find {13:^theword} somewhere                  |
          nine  ┌───────────{11:Xheader.h}────────────┐|
          this i│{1:10                              }│|
          very l│{1:searched word is here           }│|
          other │{1:12                              }│|
          {0:~     }│{1:13                              }│|
          {0:~     }└────────────────────────────────┘|
          {0:~                                       }|*5
          /theword                                |
        ]])
      end

      -- Cleanup
      os.remove('Xtags')
      os.remove('Xtagfile')
      os.remove('Xheader.h')
    end)

    describe("'previewpopup' with pum", function()
      before_each(function()
        write_file(
          'XpreviewText.vim',
          [[
let a = 3
let b = 1
echo a
echo b
call system('echo hello')
" the end
    ]]
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
      it("'previewpopup' pum pedit", function()
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
      it("'previewpopup' pum pbuffer", function()
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

    it("'previewpopup' pedit with reconfig and move", function()
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
            ┌─{11:foo}─┐|
            │{1:bar  }│|
            │{1:     }│|
            └─────┘|
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
            [4] = { 1001, 'NW', 1, 1, 1, false, 50, 1, 1, 1 },
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
          {0:~}┌─{11:foo}─┐{0:                                }|
          {0:~}│{1:bar  }│{0:                                }|
          {0:~}│{1:     }│{0:                                }|
          {0:~}└─────┘{0:                                }|
          {0:~                                       }|
                                                  |
        ]])
      end

      -- reconfig it by using set
      command('set previewpopup=height:1,width:3')
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
            ┌{11:foo}┐|
            │{1:bar}│|
            └───┘|
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
            [4] = { 1001, 'NW', 1, 1, 1, false, 50, 1, 1, 1 },
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
          ^                                        |
          {0:~}┌{11:foo}┐{0:                                  }|
          {0:~}│{1:bar}│{0:                                  }|
          {0:~}└───┘{0:                                  }|
          {0:~                                       }|*2
                                                  |
        ]])
      end

      -- move floting preview window to current split window
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
            ┌{11:<st}┐|
            │{1:   }│|
            └───┘|
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
            [4] = { 1001, 'NW', 1, 1, 21, false, 50, 1, 1, 21 },
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
              botline = 1,
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
        })
      else
        screen:expect([[
                             │^                    |
          {0:~                  }│{0:~}┌{11:<st}┐{0:              }|
          {0:~                  }│{0:~}│{1:   }│{0:              }|
          {0:~                  }│{0:~}└───┘{0:              }|
          {0:~                  }│{0:~                   }|
          {5:[No Name]           }{4:[No Name]           }|
                                                  |
        ]])
      end

      -- can close by pclose command
      command('pclose')
      eq(2, #api.nvim_list_wins())
    end)

    it('invalid argument in previewpopup', function()
      local err = pcall_err(n.exec_capture, 'set previewpopup=height:yes')
      eq('nvim_exec2(), line 1: Vim(set):E474: Invalid argument: previewpopup=height:yes', err)

      err = pcall_err(n.exec_capture, 'set previewpopup=width:yes')
      eq('nvim_exec2(), line 1: Vim(set):E474: Invalid argument: previewpopup=width:yes', err)

      err = pcall_err(n.exec_capture, 'set previewpopup=width:20,height;10')
      eq(
        'nvim_exec2(), line 1: Vim(set):E474: Invalid argument: previewpopup=width:20,height;10',
        err
      )
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
