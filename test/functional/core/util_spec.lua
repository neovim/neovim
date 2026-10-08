local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err

describe('vim._core.util', function()
  before_each(n.clear)

  describe('do_or_select()', function()
    it('rejects an empty list', function()
      t.matches(
        'Empty items!',
        pcall_err(exec_lua, function()
          require('vim._core.util').do_or_select({}, {}, function()
            error('callback should not run')
          end)
        end)
      )
    end)

    it('calls back synchronously with the only item and its index without a picker', function()
      exec_lua(function()
        vim.ui.select = function()
          error('picker should not run')
        end
        local item = { value = 'only item' }
        local calls = 0
        require('vim._core.util').do_or_select({ item }, {}, function(choice, idx)
          assert(choice == item and idx == 1)
          calls = calls + 1
        end)
        assert(calls == 1)
      end)
    end)

    for _, cancelled in ipairs({ false, true }) do
      it('delegates to the picker on ' .. (cancelled and 'cancellation' or 'selection'), function()
        exec_lua(function()
          local items = { { value = 'first' }, { value = 'second' } }
          local opts = { prompt = 'Choose:', kind = 'test' }
          local calls = 0
          local callback = function(choice, idx)
            assert(choice == (not cancelled and items[2] or nil))
            assert(idx == (not cancelled and 2 or nil))
            calls = calls + 1
          end
          local pending
          vim.ui.select = function(got_items, got_opts, on_choice)
            assert(got_items == items and got_opts == opts and on_choice == callback)
            pending = on_choice
          end
          require('vim._core.util').do_or_select(items, opts, callback)
          assert(calls == 0)
          pending(not cancelled and items[2] or nil, not cancelled and 2 or nil)
          assert(calls == 1)
        end)
      end)
    end
  end)

  describe('shorten_path()', function()
    it('shortens paths for display', function()
      exec_lua(function()
        local shorten_path = require('vim._core.util').shorten_path
        local home, cwd = vim.fn.expand('~'), vim.fn.getcwd()
        local base = vim.fs.joinpath(home, 'project')
        local root = cwd
        while vim.fs.dirname(root) ~= root do
          root = vim.fs.dirname(root)
        end
        local relative = 'Xcore-util-path/main.c'
        local outside = vim.fs.joinpath(root, relative)
        local cases = {
          { vim.fs.joinpath(base, 'src/main.c'), base, 'src/main.c' },
          { vim.fs.joinpath(home, 'other/main.c'), nil, '~/other/main.c' },
          { vim.fs.joinpath(home, 'other/main.c'), base, '~/other/main.c' },
          { vim.fs.joinpath(home, 'project-other/main.c'), base, '~/project-other/main.c' },
          { outside, nil, outside },
          -- Existing directories must not gain a trailing slash.
          { cwd, nil, vim.fn.fnamemodify(cwd, ':~') },
          { relative, nil, shorten_path(vim.fs.joinpath(cwd, relative)) },
        }
        for _, case in ipairs(cases) do
          local actual = shorten_path(case[1], case[2])
          assert(actual == case[3], ('expected %q, got %q'):format(case[3], actual))
        end
      end)
    end)
  end)
end)
