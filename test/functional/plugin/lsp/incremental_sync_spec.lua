-- Test suite for testing interactions with the incremental sync algorithms powering the LSP client
local t = require('test.functional.testutil')()

local api = t.api
local clear = t.clear
local eq = t.eq
local exec_lua = t.exec_lua
local feed = t.feed

before_each(function()
  clear()
  exec_lua [[
    local evname = ...
    local sync = require('vim.lsp.sync')
    local events = {}
    local buffer_cache = {}

    -- local format_line_ending = {
    --   ["unix"] = '\n',
    --   ["dos"] = '\r\n',
    --   ["mac"] = '\r',
    -- }

    -- local line_ending = format_line_ending[vim.api.nvim_get_option_value('fileformat', {})]


    function test_register(bufnr, id, offset_encoding, line_ending)
      local curr_lines
      local prev_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

      local function callback(_, bufnr, changedtick, firstline, lastline, new_lastline)
        if test_unreg == id then
          return true
        end

        local curr_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
        local incremental_change = sync.compute_diff(
          prev_lines, curr_lines, firstline, lastline, new_lastline, offset_encoding, line_ending)

        table.insert(events, incremental_change)
        prev_lines = curr_lines
      end
      local opts = {on_lines=callback, on_detach=callback, on_reload=callback}
      vim.api.nvim_buf_attach(bufnr, false, opts)
    end

    function get_events()
      local ret_events = events
      events = {}
      return ret_events
    end
  ]]
end)

local function test_edit(
  prev_buffer,
  edit_operations,
  expected_text_changes,
  offset_encoding,
  line_ending
)
  offset_encoding = offset_encoding or 'utf-16'
  line_ending = line_ending or '\n'

  api.nvim_buf_set_lines(0, 0, -1, true, prev_buffer)
  exec_lua('return test_register(...)', 0, 'test1', offset_encoding, line_ending)

  for _, edit in ipairs(edit_operations) do
    feed(edit)
  end
  eq(expected_text_changes, exec_lua('return get_events(...)'))
  exec_lua("test_unreg = 'test1'")
end

describe('incremental synchronization', function()
  describe('single line edit', function()
    it('inserting a character in an empty buffer', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 0,
            },
          },
          rangeLength = 0,
          text = 'a',
        },
      }
      test_edit({ '' }, { 'ia' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('inserting a character in the middle of a the first line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 1,
              line = 0,
            },
            ['end'] = {
              character = 1,
              line = 0,
            },
          },
          rangeLength = 0,
          text = 'a',
        },
      }
      test_edit({ 'ab' }, { 'lia' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting the only character in a buffer', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 1,
              line = 0,
            },
          },
          rangeLength = 1,
          text = '',
        },
      }
      test_edit({ 'a' }, { 'x' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting a character in the middle of the line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 1,
              line = 0,
            },
            ['end'] = {
              character = 2,
              line = 0,
            },
          },
          rangeLength = 1,
          text = '',
        },
      }
      test_edit({ 'abc' }, { 'lx' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('replacing a character', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 1,
              line = 0,
            },
          },
          rangeLength = 1,
          text = 'b',
        },
      }
      test_edit({ 'a' }, { 'rb' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting a line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 1,
            },
          },
          rangeLength = 12,
          text = '',
        },
      }
      test_edit({ 'hello world' }, { 'dd' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting an empty line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 0,
              line = 2,
            },
          },
          rangeLength = 1,
          text = '',
        },
      }
      test_edit({ 'hello world', '' }, { 'jdd' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('adding a line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 11,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 1,
            },
          },
          rangeLength = 1,
          text = '\nhello world\n',
        },
      }
      test_edit({ 'hello world' }, { 'yyp' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('adding an empty line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 11,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 1,
            },
          },
          rangeLength = 1,
          text = '\n\n',
        },
      }
      test_edit({ 'hello world' }, { 'o' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('adding a line to an empty buffer', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 1,
            },
          },
          rangeLength = 1,
          text = '\n\n',
        },
      }
      test_edit({ '' }, { 'o' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('insert a line above the current line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 0,
              line = 0,
            },
          },
          rangeLength = 0,
          text = '\n',
        },
      }
      test_edit({ '' }, { 'O' }, expected_text_changes, 'utf-16', '\n')
    end)
  end)
  describe('multi line edit', function()
    it('deletion and insertion', function()
      local expected_text_changes = {
        -- delete "_fsda" from end of line 1
        {
          range = {
            ['start'] = {
              character = 4,
              line = 1,
            },
            ['end'] = {
              character = 9,
              line = 1,
            },
          },
          rangeLength = 5,
          text = '',
        },
        -- delete "hello world\n" from line 2
        {
          range = {
            ['start'] = {
              character = 0,
              line = 2,
            },
            ['end'] = {
              character = 0,
              line = 3,
            },
          },
          rangeLength = 12,
          text = '',
        },
        -- delete "1234" from beginning of line 2
        {
          range = {
            ['start'] = {
              character = 0,
              line = 2,
            },
            ['end'] = {
              character = 4,
              line = 2,
            },
          },
          rangeLength = 4,
          text = '',
        },
        -- add " asdf" to end of line 1
        {
          range = {
            ['start'] = {
              character = 4,
              line = 1,
            },
            ['end'] = {
              character = 4,
              line = 1,
            },
          },
          rangeLength = 0,
          text = ' asdf',
        },
        -- delete " asdf\n" from line 2
        {
          range = {
            ['start'] = {
              character = 0,
              line = 2,
            },
            ['end'] = {
              character = 0,
              line = 3,
            },
          },
          rangeLength = 6,
          text = '',
        },
        -- undo entire deletion
        {
          range = {
            ['start'] = {
              character = 4,
              line = 1,
            },
            ['end'] = {
              character = 9,
              line = 1,
            },
          },
          rangeLength = 5,
          text = '_fdsa\nhello world\n1234 asdf',
        },
        -- redo entire deletion
        {
          range = {
            ['start'] = {
              character = 4,
              line = 1,
            },
            ['end'] = {
              character = 9,
              line = 3,
            },
          },
          rangeLength = 27,
          text = ' asdf',
        },
      }
      local original_lines = {
        '\\begin{document}',
        'test_fdsa',
        'hello world',
        '1234 asdf',
        '\\end{document}',
      }
      test_edit(original_lines, { 'jf_vejjbhhdu<C-R>' }, expected_text_changes, 'utf-16', '\n')
    end)
  end)

  describe('multi-operation edits', function()
    it('mult-line substitution', function()
      local expected_text_changes = {
        {
          range = {
            ['end'] = {
              character = 11,
              line = 2,
            },
            ['start'] = {
              character = 10,
              line = 2,
            },
          },
          rangeLength = 1,
          text = '',
        },
        {
          range = {
            ['end'] = {
              character = 10,
              line = 2,
            },
            start = {
              character = 10,
              line = 2,
            },
          },
          rangeLength = 0,
          text = '2',
        },
        {
          range = {
            ['end'] = {
              character = 11,
              line = 3,
            },
            ['start'] = {
              character = 10,
              line = 3,
            },
          },
          rangeLength = 1,
          text = '',
        },
        {
          range = {
            ['end'] = {
              character = 10,
              line = 3,
            },
            ['start'] = {
              character = 10,
              line = 3,
            },
          },
          rangeLength = 0,
          text = '3',
        },
        {
          range = {
            ['end'] = {
              character = 0,
              line = 3,
            },
            ['start'] = {
              character = 12,
              line = 2,
            },
          },
          rangeLength = 1,
          text = '\n',
        },
      }
      local original_lines = {
        '\\begin{document}',
        '\\section*{1}',
        '\\section*{1}',
        '\\section*{1}',
        '\\end{document}',
      }
      test_edit(original_lines, { '3gg$h<C-V>jg<C-A>' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('join and undo', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 11,
              line = 0,
            },
            ['end'] = {
              character = 11,
              line = 0,
            },
          },
          rangeLength = 0,
          text = ' test3',
        },
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 0,
              line = 2,
            },
          },
          rangeLength = 6,
          text = '',
        },
        {
          range = {
            ['start'] = {
              character = 11,
              line = 0,
            },
            ['end'] = {
              character = 17,
              line = 0,
            },
          },
          rangeLength = 6,
          text = '\ntest3',
        },
      }
      test_edit({ 'test1 test2', 'test3' }, { 'J', 'u' }, expected_text_changes, 'utf-16', '\n')
    end)
  end)

  describe('multi-byte edits', function()
    it('deleting a multibyte character', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 0,
            },
            ['end'] = {
              character = 2,
              line = 0,
            },
          },
          rangeLength = 2,
          text = '',
        },
      }
      test_edit({ '🔥' }, { 'x' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('replacing a multibyte character with matching prefix', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 1,
              line = 1,
            },
          },
          rangeLength = 1,
          text = '⟩',
        },
      }
      -- ⟨ is e29fa8, ⟩ is e29fa9
      local original_lines = {
        '\\begin{document}',
        '⟨',
        '\\end{document}',
      }
      test_edit(original_lines, { 'jr⟩' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('replacing a multibyte character with matching suffix', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 1,
              line = 1,
            },
          },
          rangeLength = 1,
          text = 'ḟ',
        },
      }
      -- ฟ is e0b89f, ḟ is e1b89f
      local original_lines = {
        '\\begin{document}',
        'ฟ',
        '\\end{document}',
      }
      test_edit(original_lines, { 'jrḟ' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('inserting before a multibyte character', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 0,
              line = 1,
            },
          },
          rangeLength = 0,
          text = ' ',
        },
      }
      local original_lines = {
        '\\begin{document}',
        '→',
        '\\end{document}',
      }
      test_edit(original_lines, { 'ji ' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting a multibyte character from a long line', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 85,
              line = 1,
            },
            ['end'] = {
              character = 86,
              line = 1,
            },
          },
          rangeLength = 1,
          text = '',
        },
      }
      local original_lines = {
        '\\begin{document}',
        '→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→→',
        '\\end{document}',
      }
      test_edit(original_lines, { 'jx' }, expected_text_changes, 'utf-16', '\n')
    end)
    it('deleting multiple lines containing multibyte characters', function()
      local expected_text_changes = {
        {
          range = {
            ['start'] = {
              character = 0,
              line = 1,
            },
            ['end'] = {
              character = 0,
              line = 3,
            },
          },
          --utf 16 len of 🔥 is 2
          rangeLength = 8,
          text = '',
        },
      }
      test_edit(
        { 'a🔥', 'b🔥', 'c🔥', 'd🔥' },
        { 'j2dd' },
        expected_text_changes,
        'utf-16',
        '\n'
      )
    end)
  end)
end)

-- TODO(mjlbach): Add additional tests
-- deleting single lone line
-- 2 lines -> 2 line delete -> undo -> redo
-- describe('future tests', function()
--   -- This test is currently wrong, ask bjorn why dd on an empty line triggers on_lines
--   it('deleting an empty line', function()
--     local expected_text_changes = {{ }}
--     test_edit({""}, {"ggdd"}, expected_text_changes, 'utf-16', '\n')
--   end)
-- end)
