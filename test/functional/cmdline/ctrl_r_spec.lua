local helpers = require('test.functional.helpers')(after_each)
local clear, insert, funcs, eq, feed =
  helpers.clear, helpers.insert, helpers.funcs, helpers.eq, helpers.feed

describe('cmdline CTRL-R', function()
  before_each(clear)

  it('pasting non-special register inserts <CR> *between* lines', function()
    insert([[
    line1abc
    line2somemoretext
    ]])
    -- Yank 2 lines linewise, then paste to cmdline.
    feed([[<C-\><C-N>gg0yj:<C-R>0]])
    -- <CR> inserted between lines, NOT after the final line.
    eq('line1abc\rline2somemoretext', funcs.getcmdline())

    -- Yank 2 lines characterwise, then paste to cmdline.
    feed([[<C-\><C-N>gg05lyvj:<C-R>0]])
    -- <CR> inserted between lines, NOT after the final line.
    eq('abc\rline2', funcs.getcmdline())

    -- Yank 1 line linewise, then paste to cmdline.
    feed([[<C-\><C-N>ggyy:<C-R>0]])
    -- No <CR> inserted.
    eq('line1abc', funcs.getcmdline())
  end)

  it('pasting special register inserts <CR>, <NL>', function()
    feed([[:<C-R>="foo\nbar\rbaz"<CR>]])
    eq('foo\nbar\rbaz', funcs.getcmdline())
  end)
end)

