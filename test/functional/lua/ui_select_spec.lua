-- Tests for vim.ui.select(), including integration with builtins (:tselect, z=).

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local clear = n.clear
local exec_lua = n.exec_lua
local api = n.api
local eq = t.eq
local write_file = t.write_file

before_each(clear)

describe('vim.ui.select()', function()
  it('can select an item', function()
    local result = exec_lua [[
      local items = {
        { name = 'Item 1' },
        { name = 'Item 2' },
      }
      local opts = {
        format_item = function(entry)
          return entry.name
        end
      }
      local selected
      local cb = function(item)
        selected = item
      end
      -- inputlist would require input and block the test;
      local choices
      vim.fn.inputlist = function(x)
        choices = x
        return 1
      end
      vim.ui.select(items, opts, cb)
      vim.wait(100, function() return selected ~= nil end)
      return {selected, choices}
    ]]
    eq({ name = 'Item 1' }, result[1])
    eq({
      'Select one of:',
      '1: Item 1',
      '2: Item 2',
    }, result[2])
  end)

  describe('via :tselect', function()
    it('passes items and applies the chosen index', function()
      -- Create dummy source files so the jump succeeds.
      write_file('XselTagA.c', 'int foo;\n')
      write_file('XselTagB.c', 'int foo = 1;\n')
      finally(function()
        os.remove('XselTagA.c')
        os.remove('XselTagB.c')
        os.remove('XselTags')
      end)
      write_file(
        'XselTags',
        '!_TAG_FILE_FORMAT\t2\t/extended format/\n'
          .. 'foo\tXselTagA.c\t/^int foo;$/;"\tv\n'
          .. 'foo\tXselTagB.c\t/^int foo = 1;$/;"\tv\n'
      )

      local got = exec_lua(function()
        vim.opt.tags = 'XselTags'
        local captured ---@type table?
        vim.ui.select = function(items, opts, on_choice)
          captured = { items = items, kind = opts.kind }
          -- Pick the second match.
          on_choice(items[2], 2)
        end
        vim.cmd('tselect foo')
        return {
          kind = captured and captured.kind,
          nitems = captured and #captured.items,
          item1_tag = captured and captured.items[1].tag,
          item2_file = captured and captured.items[2].file,
          bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'),
        }
      end)

      eq('tag', got.kind)
      eq(2, got.nitems)
      eq('foo', got.item1_tag)
      eq('XselTagB.c', got.item2_file)
      -- Picking item 2 should land us in XselTagB.c.
      eq('XselTagB.c', got.bufname)
    end)

    it('keeps the buffer unchanged when the user cancels', function()
      write_file('XselTagA.c', 'int foo;\n')
      write_file('XselTagB.c', 'int foo = 1;\n')
      finally(function()
        os.remove('XselTagA.c')
        os.remove('XselTagB.c')
        os.remove('XselTags')
      end)
      write_file(
        'XselTags',
        '!_TAG_FILE_FORMAT\t2\t/extended format/\n'
          .. 'foo\tXselTagA.c\t/^int foo;$/;"\tv\n'
          .. 'foo\tXselTagB.c\t/^int foo = 1;$/;"\tv\n'
      )

      api.nvim_set_option_value('tags', 'XselTags', {})

      local before = api.nvim_buf_get_name(0)
      exec_lua(function()
        vim.ui.select = function(_, _, on_choice)
          on_choice(nil, nil)
        end
        vim.cmd('tselect foo')
      end)

      eq(before, api.nvim_buf_get_name(0))
    end)
  end)

  describe('via z=', function()
    it('passes items and applies the chosen suggestion', function()
      api.nvim_set_option_value('spell', true, {})
      api.nvim_set_option_value('spelllang', 'en_us', {})

      api.nvim_buf_set_lines(0, 0, -1, false, { 'helo' })

      local got = exec_lua(function()
        vim.cmd('normal! gg0')
        local captured ---@type table?
        vim.ui.select = function(items, opts, on_choice)
          captured = { items = items, kind = opts.kind, prompt = opts.prompt }
          -- Pick the first suggestion.
          on_choice(items[1], 1)
        end
        vim.cmd('normal! z=')
        return {
          kind = captured and captured.kind,
          prompt = captured and captured.prompt,
          item1_word = captured and captured.items[1].word,
          line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1],
        }
      end)

      eq('spell', got.kind)
      -- prompt should contain the misspelled word
      t.matches('helo', got.prompt)
      -- The first suggestion replaced the bad word.
      t.neq('helo', got.line)
      eq(got.item1_word, got.line)
    end)

    it('keeps the word unchanged when the user cancels', function()
      api.nvim_set_option_value('spell', true, {})
      api.nvim_set_option_value('spelllang', 'en_us', {})

      api.nvim_buf_set_lines(0, 0, -1, false, { 'helo' })

      exec_lua(function()
        vim.cmd('normal! gg0')
        vim.ui.select = function(_, _, on_choice)
          on_choice(nil, nil)
        end
        vim.cmd('normal! z=')
      end)

      eq('helo', api.nvim_buf_get_lines(0, 0, -1, false)[1])
    end)
  end)
end)
