local helpers = require('test.functional.helpers')(after_each)
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local feed, command, curbufmeths = helpers.feed, helpers.command, helpers.curbufmeths

describe('SearchPost', function()
  before_each(function()
    clear()

    command('let g:count = 0')
    command('autocmd SearchPost * let g:event = copy(v:event)')
    command('autocmd SearchPost * let g:count += 1')

    curbufmeths.set_lines(0, -1, true, {
      'foo\0bar',
      'baz text',
    })
  end)

  it('is executed after search and should provide positions', function()
    feed('/foo<CR>')
    eq({
      startpos = { 1, 0 },
      endpos = { 1, 2 }
    }, eval('g:event'))
    eq(1, eval('g:count'))

    feed('/foo/e+5<CR>')
    eq({
      startpos = { 1, 0 },
      endpos = { 1, 2 }
    }, eval('g:event'))
    eq(2, eval('g:count'))

    feed('/foo/s+2<CR>')
    eq({
      startpos = { 1, 0 },
      endpos = { 1, 2 }
    }, eval('g:event'))
    eq(3, eval('g:count'))

    feed('G<CR>?foo.bar<CR>')
    eq({
      startpos = { 1, 0 },
      endpos = { 1, 6 }
    }, eval('g:event'))
    eq(4, eval('g:count'))

    feed('G<CR>?.bar\\nbaz<CR>/e-2')
    eq({
      startpos = { 1, 3 },
      endpos = { 2, 2 }
    }, eval('g:event'))
    eq(5, eval('g:count'))
  end)
end)
