-- Tests for misc Vimscript |vimscript-functions|.
--
-- If a function is non-trivial, consider moving its spec to:
--    test/functional/vimscript/<funcname>_spec.lua
--
-- Core "eval" tests live in eval_spec.lua.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local eval = n.eval
local matches = t.matches
local is_os = t.is_os

before_each(clear)

it('windowsversion()', function()
  matches(is_os('win') and '^%d+%.%d+$' or '^$', eval('windowsversion()'))
end)

describe('visible-line queries', function()
  for _, query in ipairs({ 'line', 'line with winid', 'getpos' }) do
    for _, bottom_first in ipairs({ false, true }) do
      local desc = query
        .. ' reflects a pending cursor position, bottom first: '
        .. tostring(bottom_first)
      it(desc, function()
        local screen = Screen.new(40, 8)
        local lines = {}
        for i = 1, 20 do
          lines[i] = 'line ' .. i
        end
        n.api.nvim_buf_set_lines(0, 0, -1, false, lines)

        t.eq(
          { 14, 20, 14 },
          n.exec_lua(function(kind, query_bottom_first)
            -- Move the cursor without drawing its new position yet.
            vim.fn.cursor(20, 1)
            -- Saving the view computes the preferred cursor column. Updating
            -- the cursor cache must not lose the pending view update.
            vim.fn.winsaveview()
            local function visible_line(which)
              if kind == 'line' then
                return vim.fn.line(which)
              elseif kind == 'line with winid' then
                return vim.fn.line(which, vim.api.nvim_get_current_win())
              end
              return vim.fn.getpos(which)[2]
            end
            local top, bottom
            if query_bottom_first then
              bottom, top = visible_line('w$'), visible_line('w0')
            else
              top, bottom = visible_line('w0'), visible_line('w$')
            end
            return { top, bottom, vim.fn.winsaveview().topline }
          end, query, bottom_first)
        )

        -- The screen shows the same view reported by the query.
        screen:expect([[
          line 14                                 |
          line 15                                 |
          line 16                                 |
          line 17                                 |
          line 18                                 |
          line 19                                 |
          ^line 20                                 |
                                                  |
        ]])
      end)
    end
  end
end)
