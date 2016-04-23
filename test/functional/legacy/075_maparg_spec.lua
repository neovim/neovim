-- Tests for maparg().
-- Also test utf8 map with a 0x80 byte.

local helpers = require('test.functional.helpers')
local clear, feed = helpers.clear, helpers.feed
local execute, expect = helpers.execute, helpers.expect

describe('maparg()', function()
  setup(clear)

  it('is working', function()
    execute('set cpo-=<')

    -- Test maparg() with a string result
    execute('map foo<C-V> is<F4>foo')
    execute('vnoremap <script> <buffer> <expr> <silent> bar isbar')
    execute([[call append('$', maparg('foo<C-V>'))]])
    execute([[call append('$', string(maparg('foo<C-V>', '', 0, 1)))]])
    execute([[call append('$', string(maparg('bar', '', 0, 1)))]])
    execute('map <buffer> <nowait> foo bar')
    execute([[call append('$', string(maparg('foo', '', 0, 1)))]])
    execute('map abc x<char-114>x')
    execute([[call append('$', maparg('abc'))]])
    execute('map abc y<S-char-114>y')
    execute([[call append('$', maparg('abc'))]])
    feed('Go<esc>:<cr>')

    -- Outside of the range, minimum
    execute('inoremap <Char-0x1040> a')
    execute([[execute "normal a\u1040\<Esc>"]])

    -- Inside of the range, minimum
    execute('inoremap <Char-0x103f> b')
    execute([[execute "normal a\u103f\<Esc>"]])

    -- Inside of the range, maximum
    execute('inoremap <Char-0xf03f> c')
    execute([[execute "normal a\uf03f\<Esc>"]])

    -- Outside of the range, maximum
    execute('inoremap <Char-0xf040> d')
    execute([[execute "normal a\uf040\<Esc>"]])

    -- Remove empty line
    execute('1d')

    -- Assert buffer contents.
    expect([[
      is<F4>foo
      {'silent': 0, 'noremap': 0, 'lhs': 'foo<C-V>', 'mode': ' ', 'nowait': 0, 'expr': 0, 'sid': 0, 'rhs': 'is<F4>foo', 'buffer': 0}
      {'silent': 1, 'noremap': 1, 'lhs': 'bar', 'mode': 'v', 'nowait': 0, 'expr': 1, 'sid': 0, 'rhs': 'isbar', 'buffer': 1}
      {'silent': 0, 'noremap': 0, 'lhs': 'foo', 'mode': ' ', 'nowait': 1, 'expr': 0, 'sid': 0, 'rhs': 'bar', 'buffer': 1}
      xrx
      yRy
      abcd]])
  end)
end)
