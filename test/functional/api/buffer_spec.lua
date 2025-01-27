local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local ok = t.ok
local describe_lua_and_rpc = n.describe_lua_and_rpc(describe)
local api = n.api
local fn = n.fn
local request = n.request
local exc_exec = n.exc_exec
local exec_lua = n.exec_lua
local feed_command = n.feed_command
local insert = n.insert
local NIL = vim.NIL
local command = n.command
local feed = n.feed
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive

describe('api/buf', function()
  before_each(clear)

  -- access deprecated functions
  local function curbuf_depr(method, ...)
    return request('buffer_' .. method, 0, ...)
  end

  describe('nvim_buf_set_lines, nvim_buf_line_count', function()
    it('deprecated forms', function()
      eq(1, curbuf_depr('line_count'))
      curbuf_depr('insert', -1, { 'line' })
      eq(2, curbuf_depr('line_count'))
      curbuf_depr('insert', -1, { 'line' })
      eq(3, curbuf_depr('line_count'))
      curbuf_depr('del_line', -1)
      eq(2, curbuf_depr('line_count'))
      curbuf_depr('del_line', -1)
      curbuf_depr('del_line', -1)
      -- There's always at least one line
      eq(1, curbuf_depr('line_count'))
    end)

    it("doesn't crash just after set undolevels=1 #24894", function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_option(buf, 'undolevels', -1)
      api.nvim_buf_set_lines(buf, 0, 1, false, {})

      assert_alive()
    end)

    it('cursor position is maintained after lines are inserted #9961', function()
      -- replace the buffer contents with these three lines.
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      -- Set the current cursor to {3, 2}.
      api.nvim_win_set_cursor(0, { 3, 2 })

      -- add 2 lines and delete 1 line above the current cursor position.
      api.nvim_buf_set_lines(0, 1, 2, true, { 'line5', 'line6' })
      -- check the current set of lines in the buffer.
      eq({ 'line1', 'line5', 'line6', 'line3', 'line4' }, api.nvim_buf_get_lines(0, 0, -1, true))
      -- cursor should be moved below by 1 line.
      eq({ 4, 2 }, api.nvim_win_get_cursor(0))

      -- add a line after the current cursor position.
      api.nvim_buf_set_lines(0, 5, 5, true, { 'line7' })
      -- check the current set of lines in the buffer.
      eq(
        { 'line1', 'line5', 'line6', 'line3', 'line4', 'line7' },
        api.nvim_buf_get_lines(0, 0, -1, true)
      )
      -- cursor position is unchanged.
      eq({ 4, 2 }, api.nvim_win_get_cursor(0))

      -- overwrite current cursor line.
      api.nvim_buf_set_lines(0, 3, 5, true, { 'line8', 'line9' })
      -- check the current set of lines in the buffer.
      eq(
        { 'line1', 'line5', 'line6', 'line8', 'line9', 'line7' },
        api.nvim_buf_get_lines(0, 0, -1, true)
      )
      -- cursor position is unchanged.
      eq({ 4, 2 }, api.nvim_win_get_cursor(0))

      -- delete current cursor line.
      api.nvim_buf_set_lines(0, 3, 5, true, {})
      -- check the current set of lines in the buffer.
      eq({ 'line1', 'line5', 'line6', 'line7' }, api.nvim_buf_get_lines(0, 0, -1, true))
      -- cursor position is unchanged.
      eq({ 4, 2 }, api.nvim_win_get_cursor(0))
    end)

    it('cursor position is maintained in non-current window', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      api.nvim_win_set_cursor(0, { 3, 2 })
      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()

      command('new')

      api.nvim_buf_set_lines(buf, 1, 2, true, { 'line5', 'line6' })
      eq({ 'line1', 'line5', 'line6', 'line3', 'line4' }, api.nvim_buf_get_lines(buf, 0, -1, true))
      eq({ 4, 2 }, api.nvim_win_get_cursor(win))
    end)

    it('cursor position is maintained in TWO non-current windows', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      api.nvim_win_set_cursor(0, { 3, 2 })
      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()

      command('split')
      api.nvim_win_set_cursor(0, { 4, 2 })
      local win2 = api.nvim_get_current_win()

      -- set current window to third one with another buffer
      command('new')

      api.nvim_buf_set_lines(buf, 1, 2, true, { 'line5', 'line6' })
      eq({ 'line1', 'line5', 'line6', 'line3', 'line4' }, api.nvim_buf_get_lines(buf, 0, -1, true))
      eq({ 4, 2 }, api.nvim_win_get_cursor(win))
      eq({ 5, 2 }, api.nvim_win_get_cursor(win2))
    end)

    it('cursor position is maintained consistently with viewport', function()
      local screen = Screen.new(20, 12)

      local lines = { 'line1', 'line2', 'line3', 'line4', 'line5', 'line6' }
      local buf = api.nvim_get_current_buf()

      api.nvim_buf_set_lines(buf, 0, -1, true, lines)

      command('6')
      command('new')
      screen:expect {
        grid = [[
        ^                    |
        {1:~                   }|*4
        {3:[No Name]           }|
        line5               |
        line6               |
        {1:~                   }|*2
        {2:[No Name] [+]       }|
                            |
      ]],
      }

      lines[5] = 'boogalo 5'
      api.nvim_buf_set_lines(buf, 0, -1, true, lines)
      screen:expect {
        grid = [[
        ^                    |
        {1:~                   }|*4
        {3:[No Name]           }|
        boogalo 5           |
        line6               |
        {1:~                   }|*2
        {2:[No Name] [+]       }|
                            |
      ]],
      }

      command('wincmd w')
      screen:expect {
        grid = [[
                            |
        {1:~                   }|*4
        {2:[No Name]           }|
        boogalo 5           |
        ^line6               |
        {1:~                   }|*2
        {3:[No Name] [+]       }|
                            |
      ]],
      }
    end)

    it('line_count has defined behaviour for unloaded buffers', function()
      -- we'll need to know our bufnr for when it gets unloaded
      local bufnr = api.nvim_buf_get_number(0)
      -- replace the buffer contents with these three lines
      api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      -- check the line count is correct
      eq(4, api.nvim_buf_line_count(bufnr))
      -- force unload the buffer (this will discard changes)
      command('new')
      command('bunload! ' .. bufnr)
      -- line count for an unloaded buffer should always be 0
      eq(0, api.nvim_buf_line_count(bufnr))
    end)

    it('get_lines has defined behaviour for unloaded buffers', function()
      -- we'll need to know our bufnr for when it gets unloaded
      local bufnr = api.nvim_buf_get_number(0)
      -- replace the buffer contents with these three lines
      api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      -- confirm that getting lines works
      eq({ 'line2', 'line3' }, api.nvim_buf_get_lines(bufnr, 1, 3, true))
      -- force unload the buffer (this will discard changes)
      command('new')
      command('bunload! ' .. bufnr)
      -- attempting to get lines now always gives empty list
      eq({}, api.nvim_buf_get_lines(bufnr, 1, 3, true))
      -- it's impossible to get out-of-bounds errors for an unloaded buffer
      eq({}, api.nvim_buf_get_lines(bufnr, 8888, 9999, true))
    end)

    describe('handles topline', function()
      local screen
      before_each(function()
        screen = Screen.new(20, 12)
        api.nvim_buf_set_lines(
          0,
          0,
          -1,
          true,
          { 'aaa', 'bbb', 'ccc', 'ddd', 'www', 'xxx', 'yyy', 'zzz' }
        )
        api.nvim_set_option_value('modified', false, {})
      end)

      it('of current window', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('new | wincmd w')
        api.nvim_win_set_cursor(win, { 8, 0 })

        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name]           }|
                              |
        ]],
        }

        api.nvim_buf_set_lines(buf, 0, 2, true, { 'aaabbb' })
        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name] [+]       }|
                              |
        ]],
        }

        -- replacing topline keeps it the topline
        api.nvim_buf_set_lines(buf, 3, 4, true, { 'wwweeee' })
        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          wwweeee             |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name] [+]       }|
                              |
        ]],
        }

        -- inserting just before topline does not scroll up if cursor would be moved
        api.nvim_buf_set_lines(buf, 3, 3, true, { 'mmm' })
        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          wwweeee             |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name] [+]       }|
                              |
        ]],
          unchanged = true,
        }

        api.nvim_win_set_cursor(0, { 7, 0 })
        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          wwweeee             |
          xxx                 |
          ^yyy                 |
          zzz                 |
          {3:[No Name] [+]       }|
                              |
        ]],
        }

        api.nvim_buf_set_lines(buf, 4, 4, true, { 'mmmeeeee' })
        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          mmmeeeee            |
          wwweeee             |
          xxx                 |
          ^yyy                 |
          {3:[No Name] [+]       }|
                              |
        ]],
        }
      end)

      it('of non-current window', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('new')
        api.nvim_win_set_cursor(win, { 8, 0 })

        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name]           }|
                              |
        ]],
        }

        api.nvim_buf_set_lines(buf, 0, 2, true, { 'aaabbb' })
        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }

        -- replacing topline keeps it the topline
        api.nvim_buf_set_lines(buf, 3, 4, true, { 'wwweeee' })
        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          wwweeee             |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }

        api.nvim_buf_set_lines(buf, 3, 3, true, { 'mmm' })
        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          wwweeee             |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
          unchanged = true,
        }
      end)

      it('of split windows with same buffer', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('split')
        api.nvim_win_set_cursor(win, { 8, 0 })
        api.nvim_win_set_cursor(0, { 1, 0 })

        screen:expect {
          grid = [[
          ^aaa                 |
          bbb                 |
          ccc                 |
          ddd                 |
          www                 |
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name]           }|
                              |
        ]],
        }
        api.nvim_buf_set_lines(buf, 0, 2, true, { 'aaabbb' })

        screen:expect {
          grid = [[
          ^aaabbb              |
          ccc                 |
          ddd                 |
          www                 |
          xxx                 |
          {3:[No Name] [+]       }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }

        -- replacing topline keeps it the topline
        api.nvim_buf_set_lines(buf, 3, 4, true, { 'wwweeee' })
        screen:expect {
          grid = [[
          ^aaabbb              |
          ccc                 |
          ddd                 |
          wwweeee             |
          xxx                 |
          {3:[No Name] [+]       }|
          wwweeee             |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }

        api.nvim_buf_set_lines(buf, 3, 3, true, { 'mmm' })
        screen:expect {
          grid = [[
          ^aaabbb              |
          ccc                 |
          ddd                 |
          mmm                 |
          wwweeee             |
          {3:[No Name] [+]       }|
          wwweeee             |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }
      end)
    end)

    it('handles clearing out non-current buffer #24911', function()
      local buf = api.nvim_get_current_buf()
      api.nvim_buf_set_lines(buf, 0, -1, true, { 'aaa', 'bbb', 'ccc' })
      command('new')

      api.nvim_buf_set_lines(0, 0, -1, true, { 'xxx', 'yyy', 'zzz' })

      api.nvim_buf_set_lines(buf, 0, -1, true, {})
      eq({ 'xxx', 'yyy', 'zzz' }, api.nvim_buf_get_lines(0, 0, -1, true))
      eq({ '' }, api.nvim_buf_get_lines(buf, 0, -1, true))
    end)
  end)

  describe('deprecated: {get,set,del}_line', function()
    it('works', function()
      eq('', curbuf_depr('get_line', 0))
      curbuf_depr('set_line', 0, 'line1')
      eq('line1', curbuf_depr('get_line', 0))
      curbuf_depr('set_line', 0, 'line2')
      eq('line2', curbuf_depr('get_line', 0))
      curbuf_depr('del_line', 0)
      eq('', curbuf_depr('get_line', 0))
    end)

    it('get_line: out-of-bounds is an error', function()
      curbuf_depr('set_line', 0, 'line1.a')
      eq(1, curbuf_depr('line_count')) -- sanity
      eq(false, pcall(curbuf_depr, 'get_line', 1))
      eq(false, pcall(curbuf_depr, 'get_line', -2))
    end)

    it('set_line, del_line: out-of-bounds is an error', function()
      curbuf_depr('set_line', 0, 'line1.a')
      eq(false, pcall(curbuf_depr, 'set_line', 1, 'line1.b'))
      eq(false, pcall(curbuf_depr, 'set_line', -2, 'line1.b'))
      eq(false, pcall(curbuf_depr, 'del_line', 2))
      eq(false, pcall(curbuf_depr, 'del_line', -3))
    end)

    it('can handle NULs', function()
      curbuf_depr('set_line', 0, 'ab\0cd')
      eq('ab\0cd', curbuf_depr('get_line', 0))
    end)
  end)

  describe('deprecated: {get,set}_line_slice', function()
    it('get_line_slice: out-of-bounds returns empty array', function()
      curbuf_depr('set_line_slice', 0, 0, true, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, 2, true, true)) --sanity

      eq({}, curbuf_depr('get_line_slice', 2, 3, false, true))
      eq({}, curbuf_depr('get_line_slice', 3, 9, true, true))
      eq({}, curbuf_depr('get_line_slice', 3, -1, true, true))
      eq({}, curbuf_depr('get_line_slice', -3, -4, false, true))
      eq({}, curbuf_depr('get_line_slice', -4, -5, true, true))
    end)

    it('set_line_slice: out-of-bounds extends past end', function()
      curbuf_depr('set_line_slice', 0, 0, true, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, 2, true, true)) --sanity

      eq({ 'c' }, curbuf_depr('get_line_slice', -1, 4, true, true))
      eq({ 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, 5, true, true))
      curbuf_depr('set_line_slice', 4, 5, true, true, { 'd' })
      eq({ 'a', 'b', 'c', 'd' }, curbuf_depr('get_line_slice', 0, 5, true, true))
      curbuf_depr('set_line_slice', -4, -5, true, true, { 'e' })
      eq({ 'e', 'a', 'b', 'c', 'd' }, curbuf_depr('get_line_slice', 0, 5, true, true))
    end)

    it('works', function()
      eq({ '' }, curbuf_depr('get_line_slice', 0, -1, true, true))
      -- Replace buffer
      curbuf_depr('set_line_slice', 0, -1, true, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, -1, true, true))
      eq({ 'b', 'c' }, curbuf_depr('get_line_slice', 1, -1, true, true))
      eq({ 'b' }, curbuf_depr('get_line_slice', 1, 2, true, false))
      eq({}, curbuf_depr('get_line_slice', 1, 1, true, false))
      eq({ 'a', 'b' }, curbuf_depr('get_line_slice', 0, -1, true, false))
      eq({ 'b' }, curbuf_depr('get_line_slice', 1, -1, true, false))
      eq({ 'b', 'c' }, curbuf_depr('get_line_slice', -2, -1, true, true))
      curbuf_depr('set_line_slice', 1, 2, true, false, { 'a', 'b', 'c' })
      eq({ 'a', 'a', 'b', 'c', 'c' }, curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', -1, -1, true, true, { 'a', 'b', 'c' })
      eq({ 'a', 'a', 'b', 'c', 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', 0, -3, true, false, {})
      eq({ 'a', 'b', 'c' }, curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', 0, -1, true, true, {})
      eq({ '' }, curbuf_depr('get_line_slice', 0, -1, true, true))
    end)
  end)

  describe_lua_and_rpc('nvim_buf_get_lines, nvim_buf_set_lines', function(lua_or_rpc)
    local function get_lines(...)
      return lua_or_rpc.nvim_buf_get_lines(0, ...)
    end

    local function set_lines(...)
      return lua_or_rpc.nvim_buf_set_lines(0, ...)
    end

    local function line_count()
      return lua_or_rpc.nvim_buf_line_count(0)
    end

    it('fails correctly when input is not valid', function()
      eq(1, lua_or_rpc.nvim_buf_get_number(0))
      eq(
        [['replacement string' item contains newlines]],
        pcall_err(lua_or_rpc.nvim_buf_set_lines, 1, 1, 2, false, { 'b\na' })
      )
    end)

    it("fails if 'nomodifiable'", function()
      command('set nomodifiable')
      eq(
        [[Buffer is not 'modifiable']],
        pcall_err(lua_or_rpc.nvim_buf_set_lines, 1, 1, 2, false, { 'a', 'b' })
      )
    end)

    it('has correct line_count when inserting and deleting', function()
      eq(1, line_count())
      set_lines(-1, -1, true, { 'line' })
      eq(2, line_count())
      set_lines(-1, -1, true, { 'line' })
      eq(3, line_count())
      set_lines(-2, -1, true, {})
      eq(2, line_count())
      set_lines(-2, -1, true, {})
      set_lines(-2, -1, true, {})
      -- There's always at least one line
      eq(1, line_count())
    end)

    it('can get, set and delete a single line', function()
      eq({ '' }, get_lines(0, 1, true))
      set_lines(0, 1, true, { 'line1' })
      eq({ 'line1' }, get_lines(0, 1, true))
      set_lines(0, 1, true, { 'line2' })
      eq({ 'line2' }, get_lines(0, 1, true))
      set_lines(0, 1, true, {})
      eq({ '' }, get_lines(0, 1, true))
    end)

    it('can get a single line with strict indexing', function()
      set_lines(0, 1, true, { 'line1.a' })
      eq(1, line_count()) -- sanity
      eq('Index out of bounds', pcall_err(get_lines, 1, 2, true))
      eq('Index out of bounds', pcall_err(get_lines, -3, -2, true))
    end)

    it('can get a single line with non-strict indexing', function()
      set_lines(0, 1, true, { 'line1.a' })
      eq(1, line_count()) -- sanity
      eq({}, get_lines(1, 2, false))
      eq({}, get_lines(-3, -2, false))
    end)

    it('can set and delete a single line with strict indexing', function()
      set_lines(0, 1, true, { 'line1.a' })
      eq('Index out of bounds', pcall_err(set_lines, 1, 2, true, { 'line1.b' }))
      eq('Index out of bounds', pcall_err(set_lines, -3, -2, true, { 'line1.c' }))
      eq({ 'line1.a' }, get_lines(0, -1, true))
      eq('Index out of bounds', pcall_err(set_lines, 1, 2, true, {}))
      eq('Index out of bounds', pcall_err(set_lines, -3, -2, true, {}))
      eq({ 'line1.a' }, get_lines(0, -1, true))
    end)

    it('can set and delete a single line with non-strict indexing', function()
      set_lines(0, 1, true, { 'line1.a' })
      set_lines(1, 2, false, { 'line1.b' })
      set_lines(-4, -3, false, { 'line1.c' })
      eq({ 'line1.c', 'line1.a', 'line1.b' }, get_lines(0, -1, true))
      set_lines(3, 4, false, {})
      set_lines(-5, -4, false, {})
      eq({ 'line1.c', 'line1.a', 'line1.b' }, get_lines(0, -1, true))
    end)

    it('can handle NULs', function()
      set_lines(0, 1, true, { 'ab\0cd' })
      eq({ 'ab\0cd' }, get_lines(0, -1, true))
    end)

    it('works with multiple lines', function()
      eq({ '' }, get_lines(0, -1, true))
      -- Replace buffer
      for _, mode in pairs({ false, true }) do
        set_lines(0, -1, mode, { 'a', 'b', 'c' })
        eq({ 'a', 'b', 'c' }, get_lines(0, -1, mode))
        eq({ 'b', 'c' }, get_lines(1, -1, mode))
        eq({ 'b' }, get_lines(1, 2, mode))
        eq({}, get_lines(1, 1, mode))
        eq({ 'a', 'b' }, get_lines(0, -2, mode))
        eq({ 'b' }, get_lines(1, -2, mode))
        eq({ 'b', 'c' }, get_lines(-3, -1, mode))
        set_lines(1, 2, mode, { 'a', 'b', 'c' })
        eq({ 'a', 'a', 'b', 'c', 'c' }, get_lines(0, -1, mode))
        set_lines(-2, -1, mode, { 'a', 'b', 'c' })
        eq({ 'a', 'a', 'b', 'c', 'a', 'b', 'c' }, get_lines(0, -1, mode))
        set_lines(0, -4, mode, {})
        eq({ 'a', 'b', 'c' }, get_lines(0, -1, mode))
        set_lines(0, -1, mode, {})
        eq({ '' }, get_lines(0, -1, mode))
      end
    end)

    it('can get line ranges with non-strict indexing', function()
      set_lines(0, -1, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, get_lines(0, -1, true)) --sanity

      eq({}, get_lines(3, 4, false))
      eq({}, get_lines(3, 10, false))
      eq({}, get_lines(-5, -5, false))
      eq({}, get_lines(3, -1, false))
      eq({}, get_lines(-3, -4, false))
    end)

    it('can get line ranges with strict indexing', function()
      set_lines(0, -1, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, get_lines(0, -1, true)) --sanity

      eq('Index out of bounds', pcall_err(get_lines, 3, 4, true))
      eq('Index out of bounds', pcall_err(get_lines, 3, 10, true))
      eq('Index out of bounds', pcall_err(get_lines, -5, -5, true))
      -- empty or inverted ranges are not errors
      eq({}, get_lines(3, -1, true))
      eq({}, get_lines(-3, -4, true))
    end)

    it('set_lines: out-of-bounds can extend past end', function()
      set_lines(0, -1, true, { 'a', 'b', 'c' })
      eq({ 'a', 'b', 'c' }, get_lines(0, -1, true)) --sanity

      eq({ 'c' }, get_lines(-2, 5, false))
      eq({ 'a', 'b', 'c' }, get_lines(0, 6, false))
      eq('Index out of bounds', pcall_err(set_lines, 4, 6, true, { 'd' }))
      set_lines(4, 6, false, { 'd' })
      eq({ 'a', 'b', 'c', 'd' }, get_lines(0, -1, true))
      eq('Index out of bounds', pcall_err(set_lines, -6, -6, true, { 'e' }))
      set_lines(-6, -6, false, { 'e' })
      eq({ 'e', 'a', 'b', 'c', 'd' }, get_lines(0, -1, true))
    end)

    it('set_lines on alternate buffer does not access invalid line (E315)', function()
      feed_command('set hidden')
      insert('Initial file')
      command('enew')
      insert([[
      More
      Lines
      Than
      In
      The
      Other
      Buffer]])
      feed_command('$')
      local retval = exc_exec("call nvim_buf_set_lines(1, 0, 1, v:false, ['test'])")
      eq(0, retval)
    end)

    it("set_lines of invisible buffer doesn't move cursor in current window", function()
      local screen = Screen.new(20, 5)

      insert([[
        Who would win?
        A real window
        with proper text]])
      local buf = lua_or_rpc.nvim_create_buf(false, true)
      screen:expect([[
        Who would win?      |
        A real window       |
        with proper tex^t    |
        {1:~                   }|
                            |
      ]])

      lua_or_rpc.nvim_buf_set_lines(buf, 0, -1, true, { 'or some', 'scratchy text' })
      feed('i') -- provoke redraw
      screen:expect([[
        Who would win?      |
        A real window       |
        with proper tex^t    |
        {1:~                   }|
        {5:-- INSERT --}        |
      ]])
    end)

    it('set_lines on hidden buffer preserves "previous window" #9741', function()
      insert([[
        visible buffer line 1
        line 2
      ]])
      local hiddenbuf = lua_or_rpc.nvim_create_buf(false, true)
      command('vsplit')
      command('vsplit')
      feed('<c-w>l<c-w>l<c-w>l')
      eq(3, fn.winnr())
      feed('<c-w>h')
      eq(2, fn.winnr())
      lua_or_rpc.nvim_buf_set_lines(hiddenbuf, 0, -1, true, { 'hidden buffer line 1', 'line 2' })
      feed('<c-w>p')
      eq(3, fn.winnr())
    end)

    it('set_lines on unloaded buffer #8659 #22670', function()
      local bufnr = api.nvim_get_current_buf()
      lua_or_rpc.nvim_buf_set_lines(bufnr, 0, -1, false, { 'a', 'b', 'c' })
      lua_or_rpc.nvim_buf_set_name(bufnr, 'set_lines')
      finally(function()
        os.remove('set_lines')
      end)
      command('write!')
      command('new')
      command('bunload! ' .. bufnr)
      local new_bufnr = fn.bufnr('set_lines', true)
      lua_or_rpc.nvim_buf_set_lines(new_bufnr, 0, -1, false, {})
      eq({ '' }, lua_or_rpc.nvim_buf_get_lines(new_bufnr, 0, -1, false))
    end)
  end)

  describe('nvim_buf_set_text', function()
    local function get_lines(...)
      return api.nvim_buf_get_lines(0, ...)
    end

    local function set_text(...)
      return api.nvim_buf_set_text(0, ...)
    end

    it('works', function()
      insert([[
      hello foo!
      text
      ]])

      eq({ 'hello foo!' }, get_lines(0, 1, true))

      -- can replace a single word
      set_text(0, 6, 0, 9, { 'world' })
      eq({ 'hello world!', 'text' }, get_lines(0, 2, true))

      -- can insert text
      set_text(0, 0, 0, 0, { 'well ' })
      eq({ 'well hello world!', 'text' }, get_lines(0, 2, true))

      -- can delete text
      set_text(0, 0, 0, 5, { '' })
      eq({ 'hello world!', 'text' }, get_lines(0, 2, true))

      -- can replace with multiple lines
      set_text(0, 6, 0, 11, { 'foo', 'wo', 'more' })
      eq({ 'hello foo', 'wo', 'more!', 'text' }, get_lines(0, 4, true))

      -- will join multiple lines if needed
      set_text(0, 6, 3, 4, { 'bar' })
      eq({ 'hello bar' }, get_lines(0, 1, true))

      -- can use negative line numbers
      set_text(-2, 0, -2, 5, { 'goodbye' })
      eq({ 'goodbye bar', '' }, get_lines(0, -1, true))

      set_text(-1, 0, -1, 0, { 'text' })
      eq({ 'goodbye bar', 'text' }, get_lines(0, 2, true))

      -- can append to a line
      set_text(1, 4, -1, 4, { ' and', 'more' })
      eq({ 'goodbye bar', 'text and', 'more' }, get_lines(0, 3, true))

      -- can use negative column numbers
      set_text(0, -5, 0, -1, { '!' })
      eq({ 'goodbye!' }, get_lines(0, 1, true))
    end)

    it('works with undo', function()
      insert([[
        hello world!
        foo bar
        ]])

      -- setting text
      set_text(0, 0, 0, 0, { 'well ' })
      feed('u')
      eq({ 'hello world!' }, get_lines(0, 1, true))

      -- deleting text
      set_text(0, 0, 0, 6, { '' })
      feed('u')
      eq({ 'hello world!' }, get_lines(0, 1, true))

      -- inserting newlines
      set_text(0, 0, 0, 0, { 'hello', 'mr ' })
      feed('u')
      eq({ 'hello world!' }, get_lines(0, 1, true))

      -- deleting newlines
      set_text(0, 0, 1, 4, { 'hello' })
      feed('u')
      eq({ 'hello world!' }, get_lines(0, 1, true))
    end)

    it('updates the cursor position', function()
      insert([[
      hello world!
      ]])

      -- position the cursor on `!`
      api.nvim_win_set_cursor(0, { 1, 11 })
      -- replace 'world' with 'foo'
      set_text(0, 6, 0, 11, { 'foo' })
      eq('hello foo!', curbuf_depr('get_line', 0))
      -- cursor should be moved left by two columns (replacement is shorter by 2 chars)
      eq({ 1, 9 }, api.nvim_win_get_cursor(0))
    end)

    it('updates the cursor position in non-current window', function()
      insert([[
      hello world!]])

      -- position the cursor on `!`
      api.nvim_win_set_cursor(0, { 1, 11 })

      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()

      command('new')

      -- replace 'world' with 'foo'
      api.nvim_buf_set_text(buf, 0, 6, 0, 11, { 'foo' })
      eq({ 'hello foo!' }, api.nvim_buf_get_lines(buf, 0, -1, true))
      -- cursor should be moved left by two columns (replacement is shorter by 2 chars)
      eq({ 1, 9 }, api.nvim_win_get_cursor(win))
    end)

    it('updates the cursor position in TWO non-current windows', function()
      insert([[
      hello world!]])

      -- position the cursor on `!`
      api.nvim_win_set_cursor(0, { 1, 11 })
      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()

      command('split')
      local win2 = api.nvim_get_current_win()
      -- position the cursor on `w`
      api.nvim_win_set_cursor(0, { 1, 6 })

      command('new')

      -- replace 'hello' with 'foo'
      api.nvim_buf_set_text(buf, 0, 0, 0, 5, { 'foo' })
      eq({ 'foo world!' }, api.nvim_buf_get_lines(buf, 0, -1, true))

      -- both cursors should be moved left by two columns (replacement is shorter by 2 chars)
      eq({ 1, 9 }, api.nvim_win_get_cursor(win))
      eq({ 1, 4 }, api.nvim_win_get_cursor(win2))
    end)

    describe('when text is being added right at cursor position #22526', function()
      it('updates the cursor position in NORMAL mode', function()
        insert([[
        abcd]])

        -- position the cursor on 'c'
        api.nvim_win_set_cursor(0, { 1, 2 })
        -- add 'xxx' before 'c'
        set_text(0, 2, 0, 2, { 'xxx' })
        eq({ 'abxxxcd' }, get_lines(0, -1, true))
        -- cursor should be on 'c'
        eq({ 1, 5 }, api.nvim_win_get_cursor(0))
      end)

      it('updates the cursor position only in non-current window when in INSERT mode', function()
        insert([[
        abcd]])

        -- position the cursor on 'c'
        api.nvim_win_set_cursor(0, { 1, 2 })
        -- open vertical split
        feed('<c-w>v')
        -- get into INSERT mode to treat cursor
        -- as being after 'b', not on 'c'
        feed('i')
        -- add 'xxx' between 'b' and 'c'
        set_text(0, 2, 0, 2, { 'xxx' })
        eq({ 'abxxxcd' }, get_lines(0, -1, true))
        -- in the current window cursor should stay after 'b'
        eq({ 1, 2 }, api.nvim_win_get_cursor(0))
        -- quit INSERT mode
        feed('<esc>')
        -- close current window
        feed('<c-w>c')
        -- in another window cursor should be on 'c'
        eq({ 1, 5 }, api.nvim_win_get_cursor(0))
      end)
    end)

    describe('when text is being deleted right at cursor position', function()
      it('leaves cursor at the same position in NORMAL mode', function()
        insert([[
        abcd]])

        -- position the cursor on 'b'
        api.nvim_win_set_cursor(0, { 1, 1 })
        -- delete 'b'
        set_text(0, 1, 0, 2, {})
        eq({ 'acd' }, get_lines(0, -1, true))
        -- cursor is now on 'c'
        eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      end)

      it('maintains INSERT-mode cursor position current/non-current window', function()
        insert([[
        abcd]])

        -- position the cursor on 'b'
        api.nvim_win_set_cursor(0, { 1, 1 })
        -- open vertical split
        feed('<c-w>v')
        -- get into INSERT mode to treat cursor
        -- as being after 'a', not on 'b'
        feed('i')
        -- delete 'b'
        set_text(0, 1, 0, 2, {})
        eq({ 'acd' }, get_lines(0, -1, true))
        -- cursor in the current window should stay after 'a'
        eq({ 1, 1 }, api.nvim_win_get_cursor(0))
        -- quit INSERT mode
        feed('<esc>')
        -- close current window
        feed('<c-w>c')
        -- cursor in non-current window should stay on 'c'
        eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      end)
    end)

    describe('when cursor is inside replaced row range', function()
      it('maintains cursor position if at start_row, but before start_col', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on ' ' before 'first'
        api.nvim_win_set_cursor(0, { 1, 14 })

        set_text(0, 15, 2, 11, {
          'the line we do not want',
          'but hopefully',
        })

        eq({
          'This should be the line we do not want',
          'but hopefully the last one',
        }, get_lines(0, -1, true))
        -- cursor should stay at the same position
        eq({ 1, 14 }, api.nvim_win_get_cursor(0))
      end)

      it('maintains cursor position if at start_row and column is still valid', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'f' in 'first'
        api.nvim_win_set_cursor(0, { 1, 15 })

        set_text(0, 15, 2, 11, {
          'the line we do not want',
          'but hopefully',
        })

        eq({
          'This should be the line we do not want',
          'but hopefully the last one',
        }, get_lines(0, -1, true))
        -- cursor should stay at the same position
        eq({ 1, 15 }, api.nvim_win_get_cursor(0))
      end)

      it('adjusts cursor column to keep it valid if start_row got smaller', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 't' in 'first'
        api.nvim_win_set_cursor(0, { 1, 19 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 24, {'last'})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'This should be last' }, get_lines(0, -1, true))
        -- cursor should end up on 't' in 'last'
        eq({ 1, 18 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 18 }, cursor)
      end)

      it('adjusts cursor column to keep it valid if start_row decreased in INSERT mode', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 't' in 'first'
        api.nvim_win_set_cursor(0, { 1, 19 })
        -- enter INSERT mode to treat cursor as being after 't'
        feed('a')

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 24, {'last'})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'This should be last' }, get_lines(0, -1, true))
        -- cursor should end up after 't' in 'last'
        eq({ 1, 19 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 19 }, cursor)
      end)

      it('adjusts cursor to valid column in row after start_row if it got smaller', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'w' in 'want'
        api.nvim_win_set_cursor(0, { 2, 31 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
            '1',
            'then 2',
            'and then',
          })
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({
          'This should be 1',
          'then 2',
          'and then the last one',
        }, get_lines(0, -1, true))
        -- cursor column should end up at the end of a row
        eq({ 2, 5 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 2, 5 }, cursor)
      end)

      it(
        'adjusts cursor to valid column in row after start_row if it got smaller in INSERT mode',
        function()
          insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

          -- position the cursor on 'w' in 'want'
          api.nvim_win_set_cursor(0, { 2, 31 })
          -- enter INSERT mode
          feed('a')

          local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
            '1',
            'then 2',
            'and then',
          })
          return vim.api.nvim_win_get_cursor(0)
        ]])

          eq({
            'This should be 1',
            'then 2',
            'and then the last one',
          }, get_lines(0, -1, true))
          -- cursor column should end up at the end of a row
          eq({ 2, 6 }, api.nvim_win_get_cursor(0))
          -- immediate call to nvim_win_get_cursor should have returned the same position
          eq({ 2, 6 }, cursor)
        end
      )

      it('adjusts cursor line and column to keep it inside replacement range', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'n' in 'finally'
        api.nvim_win_set_cursor(0, { 3, 6 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
            'the line we do not want',
            'but hopefully',
          })
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({
          'This should be the line we do not want',
          'but hopefully the last one',
        }, get_lines(0, -1, true))
        -- cursor should end up on 'y' in 'hopefully'
        -- to stay in the range, because it got smaller
        eq({ 2, 12 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 2, 12 }, cursor)
      end)

      it('adjusts cursor line and column if replacement is empty', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'r' in 'there'
        api.nvim_win_set_cursor(0, { 2, 8 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 15, 2, 12, {})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'This should be the last one' }, get_lines(0, -1, true))
        -- cursor should end up on the next column after deleted range
        eq({ 1, 15 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 15 }, cursor)
      end)

      it('adjusts cursor line and column if replacement is empty and start_col == 0', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'r' in 'there'
        api.nvim_win_set_cursor(0, { 2, 8 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 0, 2, 4, {})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'finally the last one' }, get_lines(0, -1, true))
        -- cursor should end up in column 0
        eq({ 1, 0 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 0 }, cursor)
      end)

      it('adjusts cursor column if replacement ends at cursor row, after cursor column', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'y' in 'finally'
        api.nvim_win_set_cursor(0, { 3, 10 })
        set_text(0, 15, 2, 11, { '1', 'this 2', 'and then' })

        eq({
          'This should be 1',
          'this 2',
          'and then the last one',
        }, get_lines(0, -1, true))
        -- cursor should end up on 'n' in 'then'
        eq({ 3, 7 }, api.nvim_win_get_cursor(0))
      end)

      it(
        'adjusts cursor column if replacement ends at cursor row, at cursor column in INSERT mode',
        function()
          insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

          -- position the cursor on 'y' at 'finally'
          api.nvim_win_set_cursor(0, { 3, 10 })
          -- enter INSERT mode to treat cursor as being between 'l' and 'y'
          feed('i')
          set_text(0, 15, 2, 11, { '1', 'this 2', 'and then' })

          eq({
            'This should be 1',
            'this 2',
            'and then the last one',
          }, get_lines(0, -1, true))
          -- cursor should end up after 'n' in 'then'
          eq({ 3, 8 }, api.nvim_win_get_cursor(0))
        end
      )

      it('adjusts cursor column if replacement is inside of a single line', function()
        insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

        -- position the cursor on 'y' in 'finally'
        api.nvim_win_set_cursor(0, { 3, 10 })
        set_text(2, 4, 2, 11, { 'then' })

        eq({
          'This should be first',
          'then there is a line we do not want',
          'and then the last one',
        }, get_lines(0, -1, true))
        -- cursor should end up on 'n' in 'then'
        eq({ 3, 7 }, api.nvim_win_get_cursor(0))
      end)

      it('does not move cursor column after end of a line', function()
        insert([[
        This should be the only line here
        !!!]])

        -- position cursor on the last '1'
        api.nvim_win_set_cursor(0, { 2, 2 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 33, 1, 3, {})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'This should be the only line here' }, get_lines(0, -1, true))
        -- cursor should end up on '!'
        eq({ 1, 32 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 32 }, cursor)
      end)

      it('does not move cursor column before start of a line', function()
        insert('\n!!!')

        -- position cursor on the last '1'
        api.nvim_win_set_cursor(0, { 2, 2 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 0, 1, 3, {})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ '' }, get_lines(0, -1, true))
        -- cursor should end up on '!'
        eq({ 1, 0 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 0 }, cursor)
      end)

      describe('with virtualedit', function()
        it('adjusts cursor line/col to keep inside replacement range if not after eol', function()
          insert([[
          This should be first
          then there is a line we do not want
          and finally the last one]])

          -- position cursor on 't' in 'want'
          api.nvim_win_set_cursor(0, { 2, 34 })
          -- turn on virtualedit
          command('set virtualedit=all')

          local cursor = exec_lua([[
            vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
              'the line we do not want',
              'but hopefully',
            })
            return vim.api.nvim_win_get_cursor(0)
          ]])

          eq({
            'This should be the line we do not want',
            'but hopefully the last one',
          }, get_lines(0, -1, true))
          -- cursor should end up on 'y' in 'hopefully'
          -- to stay in the range
          eq({ 2, 12 }, api.nvim_win_get_cursor(0))
          -- immediate call to nvim_win_get_cursor should have returned the same position
          eq({ 2, 12 }, cursor)
          -- coladd should be 0
          eq(0, fn.winsaveview().coladd)
        end)

        it('does not change cursor screen column when cursor >EOL and row got shorter', function()
          insert([[
          This should be first
          then there is a line we do not want
          and finally the last one]])

          -- position cursor on 't' in 'want'
          api.nvim_win_set_cursor(0, { 2, 34 })
          -- turn on virtualedit
          command('set virtualedit=all')
          -- move cursor after eol
          fn.winrestview({ coladd = 5 })

          local cursor = exec_lua([[
            vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
              'the line we do not want',
              'but hopefully',
            })
            return vim.api.nvim_win_get_cursor(0)
          ]])

          eq({
            'This should be the line we do not want',
            'but hopefully the last one',
          }, get_lines(0, -1, true))
          -- cursor should end up at eol of a new row
          eq({ 2, 26 }, api.nvim_win_get_cursor(0))
          -- immediate call to nvim_win_get_cursor should have returned the same position
          eq({ 2, 26 }, cursor)
          -- coladd should be increased so that cursor stays in the same screen column
          eq(13, fn.winsaveview().coladd)
        end)

        it(
          'does not change cursor screen column when cursor is after eol and row got longer',
          function()
            insert([[
          This should be first
          then there is a line we do not want
          and finally the last one]])

            -- position cursor on 't' in 'first'
            api.nvim_win_set_cursor(0, { 1, 19 })
            -- turn on virtualedit
            command('set virtualedit=all')
            -- move cursor after eol
            fn.winrestview({ coladd = 21 })

            local cursor = exec_lua([[
            vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
              'the line we do not want',
              'but hopefully',
            })
            return vim.api.nvim_win_get_cursor(0)
          ]])

            eq({
              'This should be the line we do not want',
              'but hopefully the last one',
            }, get_lines(0, -1, true))
            -- cursor should end up at eol of a new row
            eq({ 1, 38 }, api.nvim_win_get_cursor(0))
            -- immediate call to nvim_win_get_cursor should have returned the same position
            eq({ 1, 38 }, cursor)
            -- coladd should be increased so that cursor stays in the same screen column
            eq(2, fn.winsaveview().coladd)
          end
        )

        it(
          'does not change cursor screen column when cursor is after eol and row extended past cursor column',
          function()
            insert([[
          This should be first
          then there is a line we do not want
          and finally the last one]])

            -- position cursor on 't' in 'first'
            api.nvim_win_set_cursor(0, { 1, 19 })
            -- turn on virtualedit
            command('set virtualedit=all')
            -- move cursor after eol just a bit
            fn.winrestview({ coladd = 3 })

            local cursor = exec_lua([[
            vim.api.nvim_buf_set_text(0, 0, 15, 2, 11, {
              'the line we do not want',
              'but hopefully',
            })
            return vim.api.nvim_win_get_cursor(0)
          ]])

            eq({
              'This should be the line we do not want',
              'but hopefully the last one',
            }, get_lines(0, -1, true))
            -- cursor should stay at the same screen column
            eq({ 1, 22 }, api.nvim_win_get_cursor(0))
            -- immediate call to nvim_win_get_cursor should have returned the same position
            eq({ 1, 22 }, cursor)
            -- coladd should become 0
            eq(0, fn.winsaveview().coladd)
          end
        )

        it(
          'does not change cursor screen column when cursor is after eol and row range decreased',
          function()
            insert([[
          This should be first
          then there is a line we do not want
          and one more
          and finally the last one]])

            -- position cursor on 'e' in 'more'
            api.nvim_win_set_cursor(0, { 3, 11 })
            -- turn on virtualedit
            command('set virtualedit=all')
            -- move cursor after eol
            fn.winrestview({ coladd = 28 })

            local cursor = exec_lua([[
            vim.api.nvim_buf_set_text(0, 0, 15, 3, 11, {
              'the line we do not want',
              'but hopefully',
            })
            return vim.api.nvim_win_get_cursor(0)
          ]])

            eq({
              'This should be the line we do not want',
              'but hopefully the last one',
            }, get_lines(0, -1, true))
            -- cursor should end up at eol of a new row
            eq({ 2, 26 }, api.nvim_win_get_cursor(0))
            -- immediate call to nvim_win_get_cursor should have returned the same position
            eq({ 2, 26 }, cursor)
            -- coladd should be increased so that cursor stays in the same screen column
            eq(13, fn.winsaveview().coladd)
          end
        )
      end)
    end)

    describe('when cursor is at end_row and after end_col', function()
      it('adjusts cursor column when only a newline is added or deleted', function()
        insert([[
        first line
        second
         line]])

        -- position the cursor on 'i'
        api.nvim_win_set_cursor(0, { 3, 2 })
        set_text(1, 6, 2, 0, {})
        eq({ 'first line', 'second line' }, get_lines(0, -1, true))
        -- cursor should stay on 'i'
        eq({ 2, 8 }, api.nvim_win_get_cursor(0))

        -- add a newline back
        set_text(1, 6, 1, 6, { '', '' })
        eq({ 'first line', 'second', ' line' }, get_lines(0, -1, true))
        -- cursor should return back to the original position
        eq({ 3, 2 }, api.nvim_win_get_cursor(0))
      end)

      it(
        'adjusts cursor column if the range is not bound to either start or end of a line',
        function()
          insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

          -- position the cursor on 'h' in 'the'
          api.nvim_win_set_cursor(0, { 3, 13 })
          set_text(0, 14, 2, 11, {})
          eq({ 'This should be the last one' }, get_lines(0, -1, true))
          -- cursor should stay on 'h'
          eq({ 1, 16 }, api.nvim_win_get_cursor(0))
          -- add deleted lines back
          set_text(0, 14, 0, 14, {
            ' first',
            'then there is a line we do not want',
            'and finally',
          })
          eq({
            'This should be first',
            'then there is a line we do not want',
            'and finally the last one',
          }, get_lines(0, -1, true))
          -- cursor should return back to the original position
          eq({ 3, 13 }, api.nvim_win_get_cursor(0))
        end
      )

      it(
        'adjusts cursor column if replacing lines in range, not just deleting and adding',
        function()
          insert([[
        This should be first
        then there is a line we do not want
        and finally the last one]])

          -- position the cursor on 's' in 'last'
          api.nvim_win_set_cursor(0, { 3, 18 })
          set_text(0, 15, 2, 11, {
            'the line we do not want',
            'but hopefully',
          })

          eq({
            'This should be the line we do not want',
            'but hopefully the last one',
          }, get_lines(0, -1, true))
          -- cursor should stay on 's'
          eq({ 2, 20 }, api.nvim_win_get_cursor(0))

          set_text(0, 15, 1, 13, {
            'first',
            'then there is a line we do not want',
            'and finally',
          })

          eq({
            'This should be first',
            'then there is a line we do not want',
            'and finally the last one',
          }, get_lines(0, -1, true))
          -- cursor should return back to the original position
          eq({ 3, 18 }, api.nvim_win_get_cursor(0))
        end
      )

      it('does not move cursor column after end of a line', function()
        insert([[
        This should be the only line here
        ]])

        -- position cursor at the empty line
        api.nvim_win_set_cursor(0, { 2, 0 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 33, 1, 0, {'!'})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ 'This should be the only line here!' }, get_lines(0, -1, true))
        -- cursor should end up on '!'
        eq({ 1, 33 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 33 }, cursor)
      end)

      it('does not move cursor column before start of a line', function()
        insert('\n')

        eq({ '', '' }, get_lines(0, -1, true))

        -- position cursor on the last '1'
        api.nvim_win_set_cursor(0, { 2, 2 })

        local cursor = exec_lua([[
          vim.api.nvim_buf_set_text(0, 0, 0, 1, 0, {''})
          return vim.api.nvim_win_get_cursor(0)
        ]])

        eq({ '' }, get_lines(0, -1, true))
        -- cursor should end up on '!'
        eq({ 1, 0 }, api.nvim_win_get_cursor(0))
        -- immediate call to nvim_win_get_cursor should have returned the same position
        eq({ 1, 0 }, cursor)
      end)
    end)

    it('can handle NULs', function()
      set_text(0, 0, 0, 0, { 'ab\0cd' })
      eq('ab\0cd', curbuf_depr('get_line', 0))
    end)

    it('adjusts extmarks', function()
      local ns = api.nvim_create_namespace('my-fancy-plugin')
      insert([[
      foo bar
      baz
      ]])
      local id1 = api.nvim_buf_set_extmark(0, ns, 0, 1, {})
      local id2 = api.nvim_buf_set_extmark(0, ns, 0, 7, {})
      local id3 = api.nvim_buf_set_extmark(0, ns, 1, 1, {})
      set_text(0, 4, 0, 7, { 'q' })

      eq({ 'foo q', 'baz' }, get_lines(0, 2, true))
      -- mark before replacement point is unaffected
      eq({ 0, 1 }, api.nvim_buf_get_extmark_by_id(0, ns, id1, {}))
      -- mark gets shifted back because the replacement was shorter
      eq({ 0, 5 }, api.nvim_buf_get_extmark_by_id(0, ns, id2, {}))
      -- mark on the next line is unaffected
      eq({ 1, 1 }, api.nvim_buf_get_extmark_by_id(0, ns, id3, {}))

      -- replacing the text spanning two lines will adjust the mark on the next line
      set_text(0, 3, 1, 3, { 'qux' })
      eq({ 'fooqux', '' }, get_lines(0, 2, true))
      eq({ 0, 6 }, api.nvim_buf_get_extmark_by_id(0, ns, id3, {}))
      -- but mark before replacement point is still unaffected
      eq({ 0, 1 }, api.nvim_buf_get_extmark_by_id(0, ns, id1, {}))
      -- and the mark in the middle was shifted to the end of the insertion
      eq({ 0, 6 }, api.nvim_buf_get_extmark_by_id(0, ns, id2, {}))

      -- marks should be put back into the same place after undoing
      set_text(0, 0, 0, 2, { '' })
      feed('u')
      eq({ 0, 1 }, api.nvim_buf_get_extmark_by_id(0, ns, id1, {}))
      eq({ 0, 6 }, api.nvim_buf_get_extmark_by_id(0, ns, id2, {}))
      eq({ 0, 6 }, api.nvim_buf_get_extmark_by_id(0, ns, id3, {}))

      -- marks should be shifted over by the correct number of bytes for multibyte
      -- chars
      set_text(0, 0, 0, 0, { 'Ø' })
      eq({ 0, 3 }, api.nvim_buf_get_extmark_by_id(0, ns, id1, {}))
      eq({ 0, 8 }, api.nvim_buf_get_extmark_by_id(0, ns, id2, {}))
      eq({ 0, 8 }, api.nvim_buf_get_extmark_by_id(0, ns, id3, {}))
    end)

    it('correctly marks changed region for redraw #13890', function()
      local screen = Screen.new(20, 5)

      insert([[
      AAA
      BBB
      ]])

      api.nvim_buf_set_text(0, 0, 0, 1, 3, { 'XXX', 'YYY' })

      screen:expect([[
        XXX                 |
        YYY                 |
        ^                    |
        {1:~                   }|
                            |
      ]])
    end)

    it('errors on out-of-range', function()
      insert([[
      hello foo!
      text]])
      eq("Invalid 'start_row': out of range", pcall_err(set_text, 2, 0, 3, 0, {}))
      eq("Invalid 'start_row': out of range", pcall_err(set_text, -3, 0, 0, 0, {}))
      eq("Invalid 'end_row': out of range", pcall_err(set_text, 0, 0, 2, 0, {}))
      eq("Invalid 'end_row': out of range", pcall_err(set_text, 0, 0, -3, 0, {}))
      eq("Invalid 'start_col': out of range", pcall_err(set_text, 1, 5, 1, 5, {}))
      eq("Invalid 'end_col': out of range", pcall_err(set_text, 1, 0, 1, 5, {}))
    end)

    it('errors when start is greater than end', function()
      insert([[
      hello foo!
      text]])
      eq("'start' is higher than 'end'", pcall_err(set_text, 1, 0, 0, 0, {}))
      eq("'start' is higher than 'end'", pcall_err(set_text, 0, 1, 0, 0, {}))
    end)

    it('no heap-use-after-free when called consecutively #19643', function()
      set_text(0, 0, 0, 0, { 'one', '', '', 'two' })
      eq({ 'one', '', '', 'two' }, get_lines(0, 4, true))
      api.nvim_win_set_cursor(0, { 1, 0 })
      exec_lua([[
        vim.api.nvim_buf_set_text(0, 0, 3, 1, 0, {''})
        vim.api.nvim_buf_set_text(0, 0, 3, 1, 0, {''})
      ]])
      eq({ 'one', 'two' }, get_lines(0, 2, true))
    end)

    describe('handles topline', function()
      local screen
      before_each(function()
        screen = Screen.new(20, 12)
        api.nvim_buf_set_lines(
          0,
          0,
          -1,
          true,
          { 'aaa', 'bbb', 'ccc', 'ddd', 'www', 'xxx', 'yyy', 'zzz' }
        )
        api.nvim_set_option_value('modified', false, {})
      end)

      it('of current window', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('new | wincmd w')
        api.nvim_win_set_cursor(win, { 8, 0 })

        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name]           }|
                              |
        ]],
        }
        api.nvim_buf_set_text(buf, 0, 3, 1, 0, { 'X' })

        screen:expect {
          grid = [[
                              |
          {1:~                   }|*4
          {2:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          ^zzz                 |
          {3:[No Name] [+]       }|
                              |
        ]],
        }
      end)

      it('of non-current window', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('new')
        api.nvim_win_set_cursor(win, { 8, 0 })

        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name]           }|
                              |
        ]],
        }

        api.nvim_buf_set_text(buf, 0, 3, 1, 0, { 'X' })
        screen:expect {
          grid = [[
          ^                    |
          {1:~                   }|*4
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }
      end)

      it('of split windows with same buffer', function()
        local win = api.nvim_get_current_win()
        local buf = api.nvim_get_current_buf()

        command('split')
        api.nvim_win_set_cursor(win, { 8, 0 })
        api.nvim_win_set_cursor(0, { 1, 1 })

        screen:expect {
          grid = [[
          a^aa                 |
          bbb                 |
          ccc                 |
          ddd                 |
          www                 |
          {3:[No Name]           }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name]           }|
                              |
        ]],
        }
        api.nvim_buf_set_text(buf, 0, 3, 1, 0, { 'X' })

        screen:expect {
          grid = [[
          a^aaXbbb             |
          ccc                 |
          ddd                 |
          www                 |
          xxx                 |
          {3:[No Name] [+]       }|
          www                 |
          xxx                 |
          yyy                 |
          zzz                 |
          {2:[No Name] [+]       }|
                              |
        ]],
        }
      end)
    end)
  end)

  describe_lua_and_rpc('nvim_buf_get_text', function(lua_or_rpc)
    local get_text = lua_or_rpc.nvim_buf_get_text
    before_each(function()
      insert([[
      hello foo!
      text
      more]])
    end)

    it('works', function()
      eq({ 'hello' }, get_text(0, 0, 0, 0, 5, {}))
      eq({ 'hello foo!' }, get_text(0, 0, 0, 0, 42, {}))
      eq({ 'foo!' }, get_text(0, 0, 6, 0, 10, {}))
      eq({ 'foo!', 'tex' }, get_text(0, 0, 6, 1, 3, {}))
      eq({ 'foo!', 'tex' }, get_text(0, -3, 6, -2, 3, {}))
      eq({ '' }, get_text(0, 0, 18, 0, 20, {}))
      eq({ 'ext' }, get_text(0, -2, 1, -2, 4, {}))
      eq({ 'hello foo!', 'text', 'm' }, get_text(0, 0, 0, 2, 1, {}))
      eq({ 'hello foo!' }, get_text(0, 0, -987654321, 0, 987654321, {}))
      eq({ '' }, get_text(0, 0, -15, 0, -20, {}))
    end)

    it('errors on out-of-range', function()
      eq('Index out of bounds', pcall_err(get_text, 0, 2, 0, 4, 0, {}))
      eq('Index out of bounds', pcall_err(get_text, 0, -4, 0, 0, 0, {}))
      eq('Index out of bounds', pcall_err(get_text, 0, 0, 0, 3, 0, {}))
      eq('Index out of bounds', pcall_err(get_text, 0, 0, 0, -4, 0, {}))
      -- no ml_get errors should happen #19017
      eq('', api.nvim_get_vvar('errmsg'))
    end)

    it('errors when start is greater than end', function()
      eq("'start' is higher than 'end'", pcall_err(get_text, 0, 1, 0, 0, 0, {}))
      eq('start_col must be less than or equal to end_col', pcall_err(get_text, 0, 0, 1, 0, 0, {}))
    end)
  end)

  describe('nvim_buf_get_offset', function()
    local get_offset = api.nvim_buf_get_offset
    it('works', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'Some\r', 'exa\000mple', '', 'buf\rfer', 'text' })
      eq(5, api.nvim_buf_line_count(0))
      eq(0, get_offset(0, 0))
      eq(6, get_offset(0, 1))
      eq(15, get_offset(0, 2))
      eq(16, get_offset(0, 3))
      eq(24, get_offset(0, 4))
      eq(29, get_offset(0, 5))
      eq('Index out of bounds', pcall_err(get_offset, 0, 6))
      eq('Index out of bounds', pcall_err(get_offset, 0, -1))

      api.nvim_set_option_value('eol', false, {})
      api.nvim_set_option_value('fixeol', false, {})
      eq(28, get_offset(0, 5))

      -- fileformat is ignored
      api.nvim_set_option_value('fileformat', 'dos', {})
      eq(0, get_offset(0, 0))
      eq(6, get_offset(0, 1))
      eq(15, get_offset(0, 2))
      eq(16, get_offset(0, 3))
      eq(24, get_offset(0, 4))
      eq(28, get_offset(0, 5))
      api.nvim_set_option_value('eol', true, {})
      eq(29, get_offset(0, 5))

      command('set hidden')
      command('enew')
      eq(6, api.nvim_buf_get_offset(1, 1))
      command('bunload! 1')
      eq(-1, api.nvim_buf_get_offset(1, 1))
      eq(-1, api.nvim_buf_get_offset(1, 0))
    end)

    it('works in empty buffer', function()
      eq(0, get_offset(0, 0))
      eq(1, get_offset(0, 1))
      eq(-1, fn.line2byte('$'))
    end)

    it('works in buffer with one line inserted', function()
      feed('itext')
      eq(0, get_offset(0, 0))
      eq(5, get_offset(0, 1))
    end)
  end)

  describe('nvim_buf_get_var, nvim_buf_set_var, nvim_buf_del_var', function()
    it('works', function()
      api.nvim_buf_set_var(0, 'lua', { 1, 2, { ['3'] = 1 } })
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_buf_get_var(0, 'lua'))
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_eval('b:lua'))
      eq(1, fn.exists('b:lua'))
      api.nvim_buf_del_var(0, 'lua')
      eq(0, fn.exists('b:lua'))
      eq('Key not found: lua', pcall_err(api.nvim_buf_del_var, 0, 'lua'))
      api.nvim_buf_set_var(0, 'lua', 1)
      command('lockvar b:lua')
      eq('Key is locked: lua', pcall_err(api.nvim_buf_del_var, 0, 'lua'))
      eq('Key is locked: lua', pcall_err(api.nvim_buf_set_var, 0, 'lua', 1))
      eq('Key is read-only: changedtick', pcall_err(api.nvim_buf_del_var, 0, 'changedtick'))
      eq('Key is read-only: changedtick', pcall_err(api.nvim_buf_set_var, 0, 'changedtick', 1))
    end)
  end)

  describe('nvim_buf_get_changedtick', function()
    it('works', function()
      eq(2, api.nvim_buf_get_changedtick(0))
      api.nvim_buf_set_lines(0, 0, 1, false, { 'abc\0', '\0def', 'ghi' })
      eq(3, api.nvim_buf_get_changedtick(0))
      eq(3, api.nvim_buf_get_var(0, 'changedtick'))
    end)

    it('buffer_set_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('buffer_set_var', 0, 'lua', val1))
      eq(val1, request('buffer_set_var', 0, 'lua', val2))
    end)

    it('buffer_del_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('buffer_set_var', 0, 'lua', val1))
      eq(val1, request('buffer_set_var', 0, 'lua', val2))
      eq(val2, request('buffer_del_var', 0, 'lua'))
    end)
  end)

  describe('nvim_get_option_value, nvim_set_option_value', function()
    it('works', function()
      eq(8, api.nvim_get_option_value('shiftwidth', {}))
      api.nvim_set_option_value('shiftwidth', 4, {})
      eq(4, api.nvim_get_option_value('shiftwidth', {}))
      -- global-local option
      api.nvim_set_option_value('define', 'test', { buf = 0 })
      eq('test', api.nvim_get_option_value('define', { buf = 0 }))
      -- Doesn't change the global value
      eq('', api.nvim_get_option_value('define', { scope = 'global' }))
    end)

    it('returns values for unset local options', function()
      -- 'undolevels' is only set to its "unset" value when a new buffer is
      -- created
      command('enew')
      eq(-123456, api.nvim_get_option_value('undolevels', { buf = 0 }))
    end)
  end)

  describe('nvim_buf_get_name, nvim_buf_set_name', function()
    it('works', function()
      command('new')
      eq('', api.nvim_buf_get_name(0))
      local new_name = api.nvim_eval('resolve(tempname())')
      api.nvim_buf_set_name(0, new_name)
      eq(new_name, api.nvim_buf_get_name(0))
      command('w!')
      eq(1, fn.filereadable(new_name))
      os.remove(new_name)
    end)

    describe("with 'autochdir'", function()
      local topdir
      local oldbuf
      local newbuf

      before_each(function()
        command('set shellslash')
        topdir = fn.getcwd()
        t.mkdir(topdir .. '/Xacd')

        oldbuf = api.nvim_get_current_buf()
        command('vnew')
        newbuf = api.nvim_get_current_buf()
        command('set autochdir')
      end)

      after_each(function()
        n.rmdir(topdir .. '/Xacd')
      end)

      it('does not change cwd with non-current buffer', function()
        api.nvim_buf_set_name(oldbuf, topdir .. '/Xacd/foo.txt')
        eq(topdir, fn.getcwd())
      end)

      it('changes cwd with current buffer', function()
        api.nvim_buf_set_name(newbuf, topdir .. '/Xacd/foo.txt')
        eq(topdir .. '/Xacd', fn.getcwd())
      end)
    end)
  end)

  describe('nvim_buf_is_loaded', function()
    it('works', function()
      -- record our buffer number for when we unload it
      local bufnr = api.nvim_buf_get_number(0)
      -- api should report that the buffer is loaded
      ok(api.nvim_buf_is_loaded(bufnr))
      -- hide the current buffer by switching to a new empty buffer
      -- Careful! we need to modify the buffer first or vim will just reuse it
      api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'line1' })
      command('hide enew')
      -- confirm the buffer is hidden, but still loaded
      local infolist = api.nvim_eval('getbufinfo(' .. bufnr .. ')')
      eq(1, #infolist)
      eq(1, infolist[1].hidden)
      eq(1, infolist[1].loaded)
      -- now force unload the buffer
      command('bunload! ' .. bufnr)
      -- confirm the buffer is unloaded
      infolist = api.nvim_eval('getbufinfo(' .. bufnr .. ')')
      eq(0, infolist[1].loaded)
      -- nvim_buf_is_loaded() should also report the buffer as unloaded
      eq(false, api.nvim_buf_is_loaded(bufnr))
    end)
  end)

  describe('nvim_buf_is_valid', function()
    it('works', function()
      command('new')
      local b = api.nvim_get_current_buf()
      ok(api.nvim_buf_is_valid(b))
      command('bw!')
      ok(not api.nvim_buf_is_valid(b))
    end)
  end)

  describe('nvim_buf_delete', function()
    it('allows for just deleting', function()
      command('new')
      local b = api.nvim_get_current_buf()
      ok(api.nvim_buf_is_valid(b))
      api.nvim_buf_delete(b, {})
      ok(not api.nvim_buf_is_loaded(b))
      ok(not api.nvim_buf_is_valid(b))
    end)

    it('allows for just unloading', function()
      command('new')
      local b = api.nvim_get_current_buf()
      ok(api.nvim_buf_is_valid(b))
      api.nvim_buf_delete(b, { unload = true })
      ok(not api.nvim_buf_is_loaded(b))
      ok(api.nvim_buf_is_valid(b))
    end)
  end)

  describe('nvim_buf_get_mark', function()
    it('works', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_win_set_cursor(0, { 3, 4 })
      command('mark v')
      eq({ 3, 0 }, api.nvim_buf_get_mark(0, 'v'))
    end)
  end)

  describe('nvim_buf_set_mark', function()
    it('works with buffer local marks', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      eq(true, api.nvim_buf_set_mark(0, 'z', 1, 1, {}))
      eq({ 1, 1 }, api.nvim_buf_get_mark(0, 'z'))
      eq({ 0, 1, 2, 0 }, fn.getpos("'z"))
    end)
    it('works with file/uppercase marks', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      eq(true, api.nvim_buf_set_mark(0, 'Z', 3, 2, {}))
      eq({ 3, 2 }, api.nvim_buf_get_mark(0, 'Z'))
      eq({ api.nvim_get_current_buf(), 3, 3, 0 }, fn.getpos("'Z"))
    end)
    it('fails when invalid marks names are used', function()
      eq(false, pcall(api.nvim_buf_set_mark, 0, '!', 1, 0, {}))
      eq(false, pcall(api.nvim_buf_set_mark, 0, 'fail', 1, 0, {}))
    end)
    it('fails when invalid buffer number is used', function()
      eq(false, pcall(api.nvim_buf_set_mark, 99, 'a', 1, 1, {}))
    end)
  end)

  describe('nvim_buf_del_mark', function()
    it('works with buffer local marks', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_buf_set_mark(0, 'z', 3, 1, {})
      eq(true, api.nvim_buf_del_mark(0, 'z'))
      eq({ 0, 0 }, api.nvim_buf_get_mark(0, 'z'))
    end)
    it('works with file/uppercase marks', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_buf_set_mark(0, 'Z', 3, 3, {})
      eq(true, api.nvim_buf_del_mark(0, 'Z'))
      eq({ 0, 0 }, api.nvim_buf_get_mark(0, 'Z'))
    end)
    it('returns false in marks not set in this buffer', function()
      local abuf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(abuf, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_buf_set_mark(abuf, 'A', 2, 2, {})
      eq(false, api.nvim_buf_del_mark(0, 'A'))
      eq({ 2, 2 }, api.nvim_buf_get_mark(abuf, 'A'))
    end)
    it('returns false if mark was not deleted', function()
      api.nvim_buf_set_lines(0, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_buf_set_mark(0, 'z', 3, 1, {})
      eq(true, api.nvim_buf_del_mark(0, 'z'))
      eq(false, api.nvim_buf_del_mark(0, 'z')) -- Mark was already deleted
    end)
    it('fails when invalid marks names are used', function()
      eq(false, pcall(api.nvim_buf_del_mark, 0, '!'))
      eq(false, pcall(api.nvim_buf_del_mark, 0, 'fail'))
    end)
    it('fails when invalid buffer number is used', function()
      eq(false, pcall(api.nvim_buf_del_mark, 99, 'a'))
    end)
  end)
end)
