local n = require('test.functional.testnvim')()

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
    assert.eq(1, eval('g:foo'))
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
