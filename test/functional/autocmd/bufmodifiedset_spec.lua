local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local source = helpers.source
local request = helpers.request

describe('BufModified', function()
  before_each(clear)

  it('is triggered when modified and un-modified', function()
    source([[
    let g:modified = 0
    autocmd BufModifiedSet * let g:modified += 1
    ]])
    request("nvim_command", [[normal! aa\<Esc>]])
    eq(1, eval('g:modified'))
    request("nvim_command", [[normal! u]])
    eq(2, eval('g:modified'))
  end)

  it('is triggered through nvim_buf_call', function()
    source([[
    let g:buf = bufnr()
    let g:modified = 0
    autocmd BufModifiedSet * let g:modified += 1
    e foo
    ]])
    eq(0, eval('g:modified'))
    source([[
    lua <<END
    vim.api.nvim_buf_call(vim.g.buf, function()
      vim.fn.feedkeys('aa', 'n')
    end)
    END
    ]])
    eq(1, eval('g:modified'))
  end)
end)
