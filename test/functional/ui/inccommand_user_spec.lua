local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local api = n.api
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local insert = n.insert
local feed = n.feed
local command = n.command
local assert_alive = n.assert_alive

-- Implements a :Replace command that works like :substitute and has multibuffer support.
local setup_replace_cmd = [[
  local function show_replace_preview(use_preview_win, preview_ns, preview_buf, matches)
    -- Find the width taken by the largest line number, used for padding the line numbers
    local highest_lnum = math.max(matches[#matches][1], 1)
    local highest_lnum_width = math.floor(math.log10(highest_lnum))
    local preview_buf_line = 0
    local multibuffer = #matches > 1

    for _, match in ipairs(matches) do
      local buf = match[1]
      local buf_matches = match[2]

      if multibuffer and #buf_matches > 0 and use_preview_win then
        local bufname = vim.api.nvim_buf_get_name(buf)

        if bufname == "" then
          bufname = string.format("Buffer #%d", buf)
        end

        vim.api.nvim_buf_set_lines(
          preview_buf,
          preview_buf_line,
          preview_buf_line,
          0,
          { bufname .. ':' }
        )

        preview_buf_line = preview_buf_line + 1
      end

      for _, buf_match in ipairs(buf_matches) do
        local lnum = buf_match[1]
        local line_matches = buf_match[2]
        local prefix

        if use_preview_win then
          prefix = string.format(
            '|%s%d| ',
            string.rep(' ', highest_lnum_width - math.floor(math.log10(lnum))),
            lnum
          )

          vim.api.nvim_buf_set_lines(
            preview_buf,
            preview_buf_line,
            preview_buf_line,
            0,
            { prefix .. vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] }
          )
        end

        for _, line_match in ipairs(line_matches) do
          vim.api.nvim_buf_add_highlight(
            buf,
            preview_ns,
            'Substitute',
            lnum - 1,
            line_match[1],
            line_match[2]
          )

          if use_preview_win then
            vim.api.nvim_buf_add_highlight(
              preview_buf,
              preview_ns,
              'Substitute',
              preview_buf_line,
              #prefix + line_match[1],
              #prefix + line_match[2]
            )
          end
        end

        preview_buf_line = preview_buf_line + 1
      end
    end

    if use_preview_win then
      return 2
    else
      return 1
    end
  end

  local function do_replace(opts, preview, preview_ns, preview_buf)
    local pat1 = opts.fargs[1]

    if not pat1 then return end

    local pat2 = opts.fargs[2] or ''
    local line1 = opts.line1
    local line2 = opts.line2
    local matches = {}

    -- Get list of valid and listed buffers
    local buffers = vim.tbl_filter(
        function(buf)
          if not (vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and buf ~= preview_buf)
          then
            return false
          end

          -- Check if there's at least one window using the buffer
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == buf then
              return true
            end
          end

          return false
        end,
        vim.api.nvim_list_bufs()
    )

    for _, buf in ipairs(buffers) do
      local lines = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
      local buf_matches = {}

      for i, line in ipairs(lines) do
        local startidx, endidx = 0, 0
        local line_matches = {}
        local num = 1

        while startidx ~= -1 do
          local match = vim.fn.matchstrpos(line, pat1, 0, num)
          startidx, endidx = match[2], match[3]

          if startidx ~= -1 then
            line_matches[#line_matches+1] = { startidx, endidx }
          end

          num = num + 1
        end

        if #line_matches > 0 then
          buf_matches[#buf_matches+1] = { line1 + i - 1, line_matches }
        end
      end

      local new_lines = {}

      for _, buf_match in ipairs(buf_matches) do
        local lnum = buf_match[1]
        local line_matches = buf_match[2]
        local line = lines[lnum - line1 + 1]
        local pat_width_differences = {}

        -- If previewing, only replace the text in current buffer if pat2 isn't empty
        -- Otherwise, always replace the text
        if pat2 ~= '' or not preview then
          if preview then
            for _, line_match in ipairs(line_matches) do
              local startidx, endidx = unpack(line_match)
              local pat_match = line:sub(startidx + 1, endidx)

              pat_width_differences[#pat_width_differences+1] =
                #vim.fn.substitute(pat_match, pat1, pat2, 'g') - #pat_match
            end
          end

          new_lines[lnum] = vim.fn.substitute(line, pat1, pat2, 'g')
        end

        -- Highlight the matches if previewing
        if preview then
          local idx_offset = 0
          for i, line_match in ipairs(line_matches) do
            local startidx, endidx = unpack(line_match)
            -- Starting index of replacement text
            local repl_startidx = startidx + idx_offset
            -- Ending index of the replacement text (if pat2 isn't empty)
            local repl_endidx

            if pat2 ~= '' then
              repl_endidx = endidx + idx_offset + pat_width_differences[i]
            else
              repl_endidx = endidx + idx_offset
            end

            if pat2 ~= '' then
              idx_offset = idx_offset + pat_width_differences[i]
            end

            line_matches[i] = { repl_startidx, repl_endidx }
          end
        end
      end

      for lnum, line in pairs(new_lines) do
        vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, { line })
      end

      matches[#matches+1] = { buf, buf_matches }
    end

    if preview then
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      -- Use preview window only if preview buffer is provided and range isn't just the current line
      local use_preview_win = (preview_buf ~= nil) and (line1 ~= lnum or line2 ~= lnum)
      return show_replace_preview(use_preview_win, preview_ns, preview_buf, matches)
    end
  end

  local function replace(opts)
    do_replace(opts, false)
  end

  local function replace_preview(opts, preview_ns, preview_buf)
    return do_replace(opts, true, preview_ns, preview_buf)
  end

  -- ":<range>Replace <pat1> <pat2>"
  -- Replaces all occurrences of <pat1> in <range> with <pat2>
  vim.api.nvim_create_user_command(
    'Replace',
    replace,
    { nargs = '*', range = '%', addr = 'lines',
      preview = replace_preview }
  )
]]

describe("'inccommand' for user commands", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 17)
    exec_lua(setup_replace_cmd)
    command('set cmdwinheight=5')
    insert [[
      text on line 1
      more text on line 2
      oh no, even more text
      will the text ever stop
      oh well
      did the text stop
      why won't it stop
      make the text stop
    ]]
  end)

  it("can preview 'nomodifiable' buffer", function()
    exec_lua([[
      vim.api.nvim_create_user_command("PreviewTest", function() end, {
        preview = function(ev)
          vim.bo.modifiable = true
          vim.api.nvim_buf_set_lines(0, 0, -1, false, {"cats"})
          return 2
        end,
      })
    ]])
    command('set inccommand=split')

    command('set nomodifiable')
    eq(false, api.nvim_get_option_value('modifiable', { buf = 0 }))

    feed(':PreviewTest')

    screen:expect([[
      cats                                    |
      {1:~                                       }|*8
      {3:[No Name] [+]                           }|
                                              |
      {1:~                                       }|*4
      {2:[Preview]                               }|
      :PreviewTest^                            |
    ]])
    feed('<Esc>')
    screen:expect([[
      text on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
      ^                                        |
      {1:~                                       }|*7
                                              |
    ]])

    eq(false, api.nvim_get_option_value('modifiable', { buf = 0 }))
  end)

  it('works with inccommand=nosplit', function()
    command('set inccommand=nosplit')
    feed(':Replace text cats')
    screen:expect([[
      {10:cats} on line 1                          |
      more {10:cats} on line 2                     |
      oh no, even more {10:cats}                   |
      will the {10:cats} ever stop                 |
      oh well                                 |
      did the {10:cats} stop                       |
      why won't it stop                       |
      make the {10:cats} stop                      |
                                              |
      {1:~                                       }|*7
      :Replace text cats^                      |
    ]])
  end)

  it('works with inccommand=split', function()
    command('set inccommand=split')
    feed(':Replace text cats')
    screen:expect([[
      {10:cats} on line 1                          |
      more {10:cats} on line 2                     |
      oh no, even more {10:cats}                   |
      will the {10:cats} ever stop                 |
      oh well                                 |
      did the {10:cats} stop                       |
      why won't it stop                       |
      make the {10:cats} stop                      |
                                              |
      {3:[No Name] [+]                           }|
      |1| {10:cats} on line 1                      |
      |2| more {10:cats} on line 2                 |
      |3| oh no, even more {10:cats}               |
      |4| will the {10:cats} ever stop             |
      |6| did the {10:cats} stop                   |
      {2:[Preview]                               }|
      :Replace text cats^                      |
    ]])
  end)

  it('properly closes preview when inccommand=split', function()
    command('set inccommand=split')
    feed(':Replace text cats<Esc>')
    screen:expect([[
      text on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
      ^                                        |
      {1:~                                       }|*7
                                              |
    ]])
  end)

  it('properly executes command when inccommand=split', function()
    command('set inccommand=split')
    feed(':Replace text cats<CR>')
    screen:expect([[
      cats on line 1                          |
      more cats on line 2                     |
      oh no, even more cats                   |
      will the cats ever stop                 |
      oh well                                 |
      did the cats stop                       |
      why won't it stop                       |
      make the cats stop                      |
      ^                                        |
      {1:~                                       }|*7
      :Replace text cats                      |
    ]])
  end)

  it('shows preview window only when range is not current line', function()
    command('set inccommand=split')
    feed('gg:.Replace text cats')
    screen:expect([[
      {10:cats} on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
                                              |
      {1:~                                       }|*7
      :.Replace text cats^                     |
    ]])
  end)

  it('does not crash on ambiguous command #18825', function()
    command('set inccommand=split')
    command('command Reply echo 1')
    feed(':R')
    assert_alive()
    feed('e')
    assert_alive()
  end)

  it('no crash if preview callback changes inccommand option', function()
    command('set inccommand=nosplit')
    exec_lua([[
      vim.api.nvim_create_user_command('Replace', function() end, {
        nargs = '*',
        preview = function()
          vim.api.nvim_set_option_value('inccommand', 'split', {})
          return 2
        end,
      })
    ]])
    feed(':R')
    assert_alive()
    feed('e')
    assert_alive()
  end)

  it('no crash when adding highlight after :substitute #21495', function()
    command('set inccommand=nosplit')
    exec_lua([[
      vim.api.nvim_create_user_command("Crash", function() end, {
        preview = function(_, preview_ns, _)
          vim.cmd("%s/text/cats/g")
          vim.api.nvim_buf_add_highlight(0, preview_ns, "Search", 0, 0, -1)
          return 1
        end,
      })
    ]])
    feed(':C')
    screen:expect([[
      {10:cats on line 1}                          |
      more cats on line 2                     |
      oh no, even more cats                   |
      will the cats ever stop                 |
      oh well                                 |
      did the cats stop                       |
      why won't it stop                       |
      make the cats stop                      |
                                              |
      {1:~                                       }|*7
      :C^                                      |
    ]])
    assert_alive()
  end)

  it('no crash if preview callback executes undo #20036', function()
    command('set inccommand=nosplit')
    exec_lua([[
      vim.api.nvim_create_user_command('Foo', function() end, {
        nargs = '?',
        preview = function(_, _, _)
          vim.cmd.undo()
        end,
      })
    ]])

    -- Clear undo history
    command('set undolevels=-1')
    feed('ggyyp')
    command('set undolevels=1000')

    feed('yypp:Fo')
    assert_alive()
    feed('<Esc>:Fo')
    assert_alive()
  end)

  local function test_preview_break_undo()
    command('set inccommand=nosplit')
    exec_lua([[
      vim.api.nvim_create_user_command('Test', function() end, {
        nargs = 1,
        preview = function(opts, _, _)
          vim.cmd('norm i' .. opts.args)
          return 1
        end
      })
    ]])
    feed(':Test a.a.a.a.')
    screen:expect([[
      text on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
      a.a.a.a.                                |
      {1:~                                       }|*7
      :Test a.a.a.a.^                          |
    ]])
    feed('<C-V><Esc>u')
    screen:expect([[
      text on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
      a.a.a.                                  |
      {1:~                                       }|*7
      :Test a.a.a.a.{18:^[}u^                       |
    ]])
    feed('<Esc>')
    screen:expect([[
      text on line 1                          |
      more text on line 2                     |
      oh no, even more text                   |
      will the text ever stop                 |
      oh well                                 |
      did the text stop                       |
      why won't it stop                       |
      make the text stop                      |
      ^                                        |
      {1:~                                       }|*7
                                              |
    ]])
  end

  describe('breaking undo chain in Insert mode works properly', function()
    it('when using i_CTRL-G_u #20248', function()
      command('inoremap . .<C-G>u')
      test_preview_break_undo()
    end)

    it('when setting &l:undolevels to itself #24575', function()
      command('inoremap . .<Cmd>let &l:undolevels = &l:undolevels<CR>')
      test_preview_break_undo()
    end)
  end)

  it('disables preview if preview buffer cannot be created #27086', function()
    command('set inccommand=split')
    api.nvim_buf_set_name(0, '[Preview]')
    exec_lua([[
      vim.api.nvim_create_user_command('Test', function() end, {
        nargs = '*',
        preview = function(_, _, _)
          return 2
        end
      })
    ]])
    eq('split', api.nvim_get_option_value('inccommand', {}))
    feed(':Test')
    eq('nosplit', api.nvim_get_option_value('inccommand', {}))
  end)

  it('does not flush intermediate cursor position at end of message grid', function()
    exec_lua([[
      vim.api.nvim_create_user_command('Test', function() end, {
        nargs = '*',
        preview = function(_, _, _)
          vim.api.nvim_buf_set_text(0, 0, 0, 1, -1, { "Preview" })
          vim.cmd.sleep("1m")
          return 1
        end
      })
    ]])
    local cursor_goto = screen._handle_grid_cursor_goto
    screen._handle_grid_cursor_goto = function(...)
      cursor_goto(...)
      assert(screen._cursor.col < 12)
    end
    feed(':Test baz<Left><Left>arb')
    screen:expect({
      grid = [[
        Preview                                 |
        oh no, even more text                   |
        will the text ever stop                 |
        oh well                                 |
        did the text stop                       |
        why won't it stop                       |
        make the text stop                      |
                                                |
        {1:~                                       }|*8
        :Test barb^az                            |
      ]],
    })
  end)
end)

describe("'inccommand' with multiple buffers", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 17)
    exec_lua(setup_replace_cmd)
    command('set cmdwinheight=10')
    insert [[
      foo bar baz
      bar baz foo
      baz foo bar
    ]]
    command('vsplit | enew')
    insert [[
      bar baz foo
      baz foo bar
      foo bar baz
    ]]
  end)

  it('works', function()
    command('set inccommand=nosplit')
    feed(':Replace foo bar')
    screen:expect([[
      bar baz {10:bar}         │{10:bar} bar baz        |
      baz {10:bar} bar         │bar baz {10:bar}        |
      {10:bar} bar baz         │baz {10:bar} bar        |
                          │                   |
      {1:~                   }│{1:~                  }|*11
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      :Replace foo bar^                        |
    ]])
    feed('<CR>')
    screen:expect([[
      bar baz bar         │bar bar baz        |
      baz bar bar         │bar baz bar        |
      bar bar baz         │baz bar bar        |
      ^                    │                   |
      {1:~                   }│{1:~                  }|*11
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      :Replace foo bar                        |
    ]])
  end)

  it('works with inccommand=split', function()
    command('set inccommand=split')
    feed(':Replace foo bar')
    screen:expect([[
      bar baz {10:bar}         │{10:bar} bar baz        |
      baz {10:bar} bar         │bar baz {10:bar}        |
      {10:bar} bar baz         │baz {10:bar} bar        |
                          │                   |
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      Buffer #1:                              |
      |1| {10:bar} bar baz                         |
      |2| bar baz {10:bar}                         |
      |3| baz {10:bar} bar                         |
      Buffer #2:                              |
      |1| bar baz {10:bar}                         |
      |2| baz {10:bar} bar                         |
      |3| {10:bar} bar baz                         |
                                              |
      {1:~                                       }|
      {2:[Preview]                               }|
      :Replace foo bar^                        |
    ]])
    feed('<CR>')
    screen:expect([[
      bar baz bar         │bar bar baz        |
      baz bar bar         │bar baz bar        |
      bar bar baz         │baz bar bar        |
      ^                    │                   |
      {1:~                   }│{1:~                  }|*11
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      :Replace foo bar                        |
    ]])
  end)
end)
