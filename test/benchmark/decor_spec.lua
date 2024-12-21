local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local exec_lua = n.exec_lua

describe('decor perf', function()
  before_each(n.clear)

  it('can handle long lines', function()
    Screen.new(100, 101)

    local result = exec_lua [==[
      local ephemeral_pattern = {
        { 0, 4, 'Comment', 11 },
        { 0, 3, 'Keyword', 12 },
        { 1, 2, 'Label', 12 },
        { 0, 1, 'String', 21 },
        { 1, 3, 'Function', 21 },
        { 2, 10, 'Label', 8 },
      }

      local regular_pattern = {
        { 4, 5, 'String', 12 },
        { 1, 4, 'Function', 2 },
      }

      for _, list in ipairs({ ephemeral_pattern, regular_pattern }) do
        for _, p in ipairs(list) do
          p[3] = vim.api.nvim_get_hl_id_by_name(p[3])
        end
      end

      local text = ('abcdefghijklmnopqrstuvwxyz0123'):rep(333)
      local line_len = #text
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { text })

      local ns = vim.api.nvim_create_namespace('decor_spec.lua')
      vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local ps, pe
      local function add_pattern(pattern, ephemeral)
        ps = vim.uv.hrtime()
        local i = 0
        while i < line_len - 10 do
          for _, p in ipairs(pattern) do
            vim.api.nvim_buf_set_extmark(0, ns, 0, i + p[1], {
              end_row = 0,
              end_col = i + p[2],
              hl_group = p[3],
              priority = p[4],
              ephemeral = ephemeral,
            })
          end
          i = i + 5
        end
        pe = vim.uv.hrtime()
      end

      vim.api.nvim_set_decoration_provider(ns, {
        on_win = function()
          return true
        end,
        on_line = function()
            add_pattern(ephemeral_pattern, true)
        end,
      })

      add_pattern(regular_pattern, false)

      local total = {}
      local provider = {}
      for i = 1, 100 do
        local tic = vim.uv.hrtime()
        vim.cmd'redraw!'
        local toc = vim.uv.hrtime()
        table.insert(total, toc - tic)
        table.insert(provider, pe - ps)
      end

      return { total, provider }
    ]==]

    local total, provider = unpack(result)
    table.sort(total)
    table.sort(provider)

    local ms = 1 / 1000000
    local function fmt(stats)
      return string.format(
        'min, 25%%, median, 75%%, max:\n\t%0.1fms,\t%0.1fms,\t%0.1fms,\t%0.1fms,\t%0.1fms',
        stats[1] * ms,
        stats[1 + math.floor(#stats * 0.25)] * ms,
        stats[1 + math.floor(#stats * 0.5)] * ms,
        stats[1 + math.floor(#stats * 0.75)] * ms,
        stats[#stats] * ms
      )
    end

    print('\nTotal ' .. fmt(total) .. '\nDecoration provider: ' .. fmt(provider))
  end)

  it('can handle full screen of highlighting', function()
    Screen.new(100, 51)

    local result = exec_lua(function()
      local long_line = 'local a={' .. ('a=5,'):rep(22) .. '}'
      local lines = {}
      for _ = 1, 50 do
        table.insert(lines, long_line)
      end
      vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.treesitter.start(0, 'lua')

      local total = {}
      for _ = 1, 100 do
        local tic = vim.uv.hrtime()
        vim.cmd 'redraw!'
        local toc = vim.uv.hrtime()
        table.insert(total, toc - tic)
      end

      return { total }
    end)

    local total = unpack(result)
    table.sort(total)

    local ms = 1 / 1000000
    local res = string.format(
      'min, 25%%, median, 75%%, max:\n\t%0.1fms,\t%0.1fms,\t%0.1fms,\t%0.1fms,\t%0.1fms',
      total[1] * ms,
      total[1 + math.floor(#total * 0.25)] * ms,
      total[1 + math.floor(#total * 0.5)] * ms,
      total[1 + math.floor(#total * 0.75)] * ms,
      total[#total] * ms
    )
    print('\nTotal ' .. res)
  end)
end)
