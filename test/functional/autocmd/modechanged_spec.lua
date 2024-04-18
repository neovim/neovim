local t = require('test.functional.testutil')()
local clear, eval, eq = t.clear, t.eval, t.eq
local feed, command = t.feed, t.command
local exec_lua = t.exec_lua

describe('ModeChanged', function()
  before_each(function()
    clear()
  end)

  it('picks up terminal mode changes', function()
    command('let g:count = 0')
    command('au ModeChanged * let g:event = copy(v:event)')
    command('au ModeChanged * let g:count += 1')

    command('term')
    feed('i')
    eq({
      old_mode = 'nt',
      new_mode = 't',
    }, eval('g:event'))
    feed('<c-\\><c-n>')
    eq({
      old_mode = 't',
      new_mode = 'nt',
    }, eval('g:event'))
    eq(3, eval('g:count'))
    command('bd!')

    -- v:event is cleared after the autocommand is done
    eq({}, eval('v:event'))
  end)

  it('does not repeatedly trigger for scheduled callback', function()
    exec_lua([[
      vim.g.s_count = 0
      vim.g.s_mode = ""
      vim.g.t_count = 0
      vim.g.t_mode = ""
      vim.api.nvim_create_autocmd("ModeChanged", {
        callback = function()
          vim.g.s_count = vim.g.s_count + 1
          vim.g.s_mode = vim.api.nvim_get_mode().mode
          vim.schedule(function()
            vim.g.t_count = vim.g.t_count + 1
            vim.g.t_mode = vim.api.nvim_get_mode().mode
          end)
        end,
      })
    ]])

    feed('d')
    eq(1, eval('g:s_count'))
    eq('no', eval('g:s_mode'))
    eq(1, eval('g:t_count'))
    eq('no', eval('g:t_mode'))

    feed('<Esc>')
    eq(2, eval('g:s_count'))
    eq('n', eval('g:s_mode'))
    eq(2, eval('g:t_count'))
    eq('n', eval('g:t_mode'))
  end)
end)
