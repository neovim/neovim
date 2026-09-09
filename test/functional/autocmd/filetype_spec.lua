local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local eval = n.eval
local clear = n.clear
local command = n.command
local exec_lua = n.exec_lua

describe('autocmd FileType', function()
  before_each(clear)

  it('is triggered by :help only once', function()
    n.add_builddir_to_rtp()
    command('let g:foo = 0')
    command('autocmd FileType help let g:foo = g:foo + 1')
    command('help help')
    eq(1, eval('g:foo'))
  end)

  -- Regression test for #41711: "doautoall FileType" on a buffer with empty
  -- filetype (e.g. during lazy LSP setup in :restart) should not set
  -- b_did_filetype, which would prevent subsequent :setf from working.
  it('doautoall FileType with empty ft does not block :setf detection', function()
    local fname = 'test_file_41711.lua'
    t.write_file(fname, 'print("hello")\n')
    n.add_builddir_to_rtp()
    command('filetype on')
    exec_lua(string.format(
      [[
      local fname = %q
      vim.api.nvim_create_autocmd('User', {
        pattern = 'DoEdit',
        nested = true,
        callback = function()
          vim.cmd.edit(fname)
        end,
      })
      vim.api.nvim_create_autocmd('BufReadPre', {
        nested = true,
        once = true,
        callback = function()
          -- This mirrors what vim.lsp.enable() does: "doautoall FileType"
          -- fires a FileType event on a buffer whose filetype is still empty.
          vim.cmd.doautoall('FileType')
        end,
      })
    ]],
      fname
    ))
    command('doautocmd User DoEdit')
    eq('lua', eval('&filetype'))
    os.remove(fname)
  end)

  it('vim.lsp.enable during BufReadPre does not prevent filetype detection #41711', function()
    local fname = 'test_file_41711_lsp.md'
    t.write_file(fname, '# Hello\n')
    n.add_builddir_to_rtp()
    command('filetype on')
    exec_lua(string.format(
      [[
      local fname = %q
      vim.lsp.config('dummy', { cmd = { 'false' }, filetypes = { 'markdown' } })
      vim.api.nvim_create_autocmd('User', {
        pattern = 'DoEdit',
        nested = true,
        callback = function()
          vim.cmd.edit(fname)
        end,
      })
      vim.api.nvim_create_autocmd('BufReadPre', {
        nested = true,
        once = true,
        callback = function()
          vim.lsp.enable('dummy')
        end,
      })
    ]],
      fname
    ))
    command('doautocmd User DoEdit')
    eq('markdown', eval('&filetype'))
    os.remove(fname)
  end)
end)
