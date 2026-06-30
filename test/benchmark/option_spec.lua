local n = require('test.functional.testnvim')()

local clear = n.clear
local bench = n.bench

describe('option set perf', function()
  before_each(clear)

  local trials = 20000

  it('vim.o scalar (number)', function()
    bench([[vim.o.scrolloff = i % 10]], { n = trials, label = 'vim.o.scrolloff = i % 10' })
  end)

  it('vim.o scalar (boolean)', function()
    bench([[vim.o.wrap = (i % 2 == 0)]], { n = trials, label = 'vim.o.wrap = (i % 2 == 0)' })
  end)

  it('vim.o scalar (string)', function()
    -- makeprg has a trivial did_set handler, so this isolates the set path itself.
    bench([[vim.o.makeprg = 'make']], { n = trials, label = "vim.o.makeprg = 'make'" })
  end)

  it('vim.opt array via table', function()
    bench([[vim.opt.wildignore = { '*.o', '*.a', '*.so' }]], {
      n = trials,
      label = "vim.opt.wildignore = {'*.o','*.a','*.so'}",
    })
  end)

  it('vim.opt map via table', function()
    bench([[vim.opt.listchars = { eol = '~', space = '.', tab = '> ' }]], {
      n = trials,
      label = "vim.opt.listchars = { eol='~', space='.', tab='> ' }",
    })
  end)

  it('vim.opt:append (operation)', function()
    bench(
      [[
      vim.o.wildignore = ''
      vim.opt.wildignore:append({ '*.tmp', '*.bak' })
    ]],
      { n = trials, label = 'vim.opt.wildignore:append(...)' }
    )
  end)

  it('nvim_set_option_value with table (direct API)', function()
    bench([[vim.api.nvim_set_option_value('listchars', { eol = '~', space = '.' }, {})]], {
      n = trials,
      label = 'nvim_set_option_value(listchars, {..})',
    })
  end)
end)
