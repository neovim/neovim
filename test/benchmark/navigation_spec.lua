local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')

local describe, it = t.describe, t.it

describe('navigation perf', function()
  for _, cost_us in ipairs({ 0, 200 }) do
    for _, case in ipairs({
      { 'Normal', '<ScrollWheelDown><145,30>' },
      { 'Insert', '<ScrollWheelDown><145,30>' },
      { 'Normal', '<C-E>' },
    }) do
      local mode, input = case[1], case[2]
      local label = ('%s %s, synthetic cursor callback: %d us'):format(mode, input, cost_us)
      it(label, function()
        n.clear()
        Screen.new(210, 98)
        n.exec_lua(function(cost, channel)
          vim.cmd('set mouse=a mousescroll=ver:1,hor:1 nowrap scrolloff=0 cursorline splitright')
          local lines = {}
          for i = 1, 1600 do
            lines[i] = ('line %04d %s'):format(i, ('word '):rep(12))
          end
          vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
          vim.cmd('vsplit')

          local cursor_events = 0
          if cost > 0 then
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              callback = function()
                cursor_events = cursor_events + 1
                local deadline = vim.uv.hrtime() + cost * 1000
                while vim.uv.hrtime() < deadline do
                end
              end,
            })
          end

          local started
          vim.keymap.set({ 'n', 'i' }, '<F3>', function()
            cursor_events = 0
            started = vim.uv.hrtime()
          end)
          vim.keymap.set({ 'n', 'i' }, '<F4>', function()
            vim.rpcnotify(channel, 'scroll_done', vim.uv.hrtime() - started, cursor_events)
          end)
        end, cost_us, n.api.nvim_get_api_info()[1])

        local samples, cursor_events = {}, {}
        for run = 0, 5 do
          n.feed('<Esc>')
          n.command('normal! 100Gzt')
          if mode == 'Insert' then
            n.feed('i')
          end

          -- Time the native input loop, without polling RPC between the markers.
          n.feed('<F3>' .. input:rep(450) .. '<F4>')
          local message
          repeat
            message = assert(n.next_msg(), 'scroll benchmark did not finish')
          until message[1] == 'notification' and message[2] == 'scroll_done'
          t.eq(550, n.fn.line('w0'))
          if run > 0 then
            samples[#samples + 1] = message[3][1]
            cursor_events[#cursor_events + 1] = message[3][2]
          end
        end
        t.bench_report(samples, { label = label, unit = 'ms' })
        if cost_us > 0 then
          print('  CursorMoved/CursorMovedI events: ' .. table.concat(cursor_events, ', '))
        end
      end)
    end
  end
end)
