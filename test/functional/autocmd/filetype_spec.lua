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
    assert.same(1, eval('g:foo'))
  end)
end)
