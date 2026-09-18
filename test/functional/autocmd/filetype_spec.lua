local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local eval = n.eval
local clear = n.clear
local command = n.command

describe('autocmd FileType', function()
  before_each(clear)

  it('is triggered by :help only once', function()
    n.add_builddir_to_rtp()
    command('let g:foo = 0')
    command('autocmd FileType help let g:foo = g:foo + 1')
    command('help help')
    t.eq(1, eval('g:foo'))
  end)

  it("empty 'filetype' does not prevent FileType event #41711", function()
    local file = t.tmpname(false) .. '.md'
    t.write_file(file, '# hi\n')
    command('filetype on')
    -- Like vim.lsp.enable() lazy-loaded while the buffer is being read.
    command('autocmd FileType * :')
    command('autocmd BufReadPre * ++once doautoall FileType')
    -- Run :edit in a nested event (mimics :restart session-restore).
    command(('autocmd User X ++nested edit %s'):format(vim.fn.fnameescape(file)))
    command('doautocmd User X')
    t.eq('markdown', eval('&filetype'))
  end)

  it('detected when a nested=false BufAdd autocmd loads the buffer #41663', function()
    local file = t.tmpname(false) .. '.md'
    t.write_file(file, '# hi\n')
    command('filetype on')
    -- ":badd" lists the buffer, which fires BufAdd. bufload() from that (nested=false) autocmd
    -- does NOT trigger BufReadPost, thus skips 'filetype' detection.
    t.eq(
      'markdown',
      n.exec_lua(function(f)
        vim.api.nvim_create_autocmd('BufAdd', {
          nested = false,
          callback = function(ev)
            vim.fn.bufload(ev.buf)
          end,
        })
        vim.cmd('badd ' .. vim.fn.fnameescape(f))
        return vim.bo[vim.fn.bufnr(f)].filetype
      end, file)
    )
  end)
end)
