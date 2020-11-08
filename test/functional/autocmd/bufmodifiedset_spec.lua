local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local source = helpers.source

describe('BufModified', function()
  before_each(clear)

  it('is triggered when modified and un-modified', function()
    source([[
    let g:modified = 0
    autocmd BufModifiedSet * let g:modified += 1
    execute "normal! aa\<Esc>"
    execute "normal! u"
    ]])
    eq(2, eval('g:modified'))
  end)
end)
