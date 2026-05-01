-- Tests for vim.ui.select(), including integration with builtins (:tselect, z=).

local t = require('test.testutil')
local retry = t.retry
local n = require('test.functional.testnvim')()
local clear = n.clear
local exec_lua = n.exec_lua
local api = n.api
local eq = t.eq
local neq = t.neq
local write_file = t.write_file

before_each(clear)

--- Mock async vim.ui.select impl. Imitates fzf-lua/telescope/snacks: opens a transient floating
--- window, then schedules on_choice to fire on the next event-loop tick.
---
--- Sets `_G._captured` so tests can assert the user choice.
--- @param pick integer|nil 1-based index to "pick" (nil cancels).
local function setup_async_picker(pick)
  exec_lua(function()
    _G._captured = nil
    --- @diagnostic disable-next-line: duplicate-set-field
    vim.ui.select = function(items, opts, on_choice)
      _G._captured = { items = items, opts = opts }
      -- Open a floating window like a real picker would.
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, false, {
        relative = 'editor',
        row = 1,
        col = 1,
        width = 30,
        height = math.min(#items, 5),
      })
      _G._captured.win = win
      -- Defer the choice so the wait actually has to pump events.
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if pick then
          on_choice(items[pick], pick)
        else
          on_choice(nil, nil)
        end
      end, 30)
    end
  end, pick)
end

--- Mock fzf-lua-style picker: opens a floating window with a *terminal* buffer running a small
--- shell command. When the command exits we treat the user as having "picked" `pick`.
local function setup_term_picker(pick)
  exec_lua(function(pick_, prog)
    _G._captured = nil
    --- @diagnostic disable-next-line: duplicate-set-field
    vim.ui.select = function(items, opts, on_choice)
      _G._captured = { items = items, opts = opts }
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        row = 1,
        col = 1,
        width = 30,
        height = math.min(#items, 5),
      })
      vim.fn.jobstart({ prog }, {
        term = true,
        on_exit = function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
          if pick_ then
            on_choice(items[pick_], pick_)
          else
            on_choice(nil, nil)
          end
        end,
      })
    end
  end, pick, n.testprg('shell-test'))
end

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
    local function prepare_test()
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
      api.nvim_set_option_value('tags', 'XselTags', {})
    end

    it('passes items, gets user choice', function()
      prepare_test()

      local got = exec_lua(function()
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.ui.select = function(items, opts, on_choice)
          _G._captured = { items = items, kind = opts.kind }
          -- Pick the second match.
          on_choice(items[2], 2)
        end
        vim.cmd('tselect foo')
      end)
      -- on_choice queues `:[idx]tag` via feedkeys; let typeahead drain.
      retry(nil, 1000, function()
        eq('XselTagB.c', api.nvim_eval('expand("%:t")'))
      end)
      got = exec_lua(function()
        return _G._captured
      end)

      eq('tag', got.kind)
      eq(2, #got.items)
      eq('foo', got.items[1].tag)
      eq('XselTagB.c', got.items[2].file)
    end)

    it('does nothing when the user cancels', function()
      prepare_test()

      local before = api.nvim_buf_get_name(0)
      exec_lua(function()
        vim.ui.select = function(_, _, on_choice)
          on_choice(nil, nil)
        end
        vim.cmd('tselect foo')
      end)

      eq(before, api.nvim_buf_get_name(0))
    end)

    it('+ async picker', function()
      prepare_test()

      setup_async_picker(2)
      exec_lua([[vim.cmd('tselect foo')]])
      retry(nil, 1000, function()
        eq('XselTagB.c', api.nvim_eval('expand("%:t")'))
      end)
      eq('tag', exec_lua([[return _G._captured and _G._captured.opts.kind]]))
    end)

    it('+ async terminal-based picker', function()
      prepare_test()

      setup_term_picker(2)
      exec_lua([[vim.cmd('tselect foo')]])
      retry(nil, 1000, function()
        eq('XselTagB.c', api.nvim_eval('expand("%:t")'))
      end)
    end)
  end)

  describe('via z=', function()
    local function prepare_test()
      api.nvim_set_option_value('spell', true, {})
      api.nvim_set_option_value('spelllang', 'en_us', {})
      api.nvim_buf_set_lines(0, 0, -1, false, { 'helo' })
    end

    it('passes items, gets user choice', function()
      prepare_test()

      exec_lua(function()
        vim.cmd('normal! gg0')
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.ui.select = function(items, opts, on_choice)
          _G._captured = { items = items, kind = opts.kind, prompt = opts.prompt }
          -- Pick the first suggestion.
          on_choice(items[1], 1)
        end
        vim.cmd('normal! z=')
      end)
      -- z= delegates to vim.ui.select, see `_core/spell:select_suggest`. on_choice queues
      -- `:normal! [idx]z=` via feedkeys; let typeahead drain.
      retry(nil, 1000, function()
        t.neq('helo', api.nvim_buf_get_lines(0, 0, -1, false)[1])
      end)
      local got = exec_lua([[return _G._captured]])

      eq('spell', got.kind)
      t.matches('helo', got.prompt)
      eq(got.items[1].word, api.nvim_buf_get_lines(0, 0, -1, false)[1])
    end)

    it('does nothing when the user cancels', function()
      prepare_test()

      exec_lua(function()
        vim.cmd('normal! gg0')
        vim.ui.select = function(_, _, on_choice)
          on_choice(nil, nil)
        end
        vim.cmd('normal! z=')
      end)

      eq('helo', api.nvim_buf_get_lines(0, 0, -1, false)[1])
    end)

    it('+ async picker', function()
      prepare_test()

      setup_async_picker(1)
      exec_lua([[vim.cmd('normal! gg0z=')]])
      retry(nil, 1000, function()
        neq('helo', api.nvim_buf_get_lines(0, 0, -1, false)[1])
      end)
      eq('spell', exec_lua([[return _G._captured and _G._captured.opts.kind]]))
    end)

    it('+ async terminal-based picker', function()
      prepare_test()

      setup_term_picker(1)
      exec_lua([[vim.cmd('normal! gg0z=')]])
      retry(nil, 1000, function()
        neq('helo', api.nvim_buf_get_lines(0, 0, -1, false)[1])
      end)
    end)
  end)

  describe('via ":browse oldfiles"', function()
    it('+ async picker', function()
      finally(function()
        os.remove('XselOldA')
        os.remove('XselOldB')
      end)
      write_file('XselOldA', 'a\n')
      write_file('XselOldB', 'b\n')
      local cwd = exec_lua([[return vim.uv.cwd()]])

      setup_async_picker(2)
      exec_lua(function(cwd_)
        -- v:oldfiles is normally populated via shada; inject directly for the test.
        vim.v.oldfiles = { cwd_ .. '/XselOldA', cwd_ .. '/XselOldB' }
        vim.cmd('browse oldfiles')
      end, cwd)
      retry(nil, 1000, function()
        eq('XselOldB', api.nvim_eval('expand("%:t")'))
      end)
      eq('oldfiles', exec_lua([[return _G._captured and _G._captured.opts.kind]]))
    end)
  end)
end)
