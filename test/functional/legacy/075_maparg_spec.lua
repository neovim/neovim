-- Tests for maparg().
-- Also test utf8 map with a 0x80 byte.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local command, expect = helpers.command, helpers.expect
local wait = helpers.wait

describe('maparg()', function()
  setup(clear)

  it('is working', function()
    command('set cpo-=<')

    -- Test maparg() with a string result
    command('map foo<C-V> is<F4>foo')
    command('vnoremap <script> <buffer> <expr> <silent> bar isbar')
    command([[call append('$', maparg('foo<C-V>'))]])
    command([[call append('$', string(maparg('foo<C-V>', '', 0, 1)))]])
    command([[call append('$', string(maparg('bar', '', 0, 1)))]])
    command('map <buffer> <nowait> foo bar')
    command([[call append('$', string(maparg('foo', '', 0, 1)))]])
    command('map abc x<char-114>x')
    command([[call append('$', maparg('abc'))]])
    command('map abc y<S-char-114>y')
    command([[call append('$', maparg('abc'))]])
    feed('Go<esc>:<cr>')
    wait()

    -- Outside of the range, minimum
    command('inoremap <Char-0x1040> a')
    command([[execute "normal a\u1040\<Esc>"]])

    -- Inside of the range, minimum
    command('inoremap <Char-0x103f> b')
    command([[execute "normal a\u103f\<Esc>"]])

    -- Inside of the range, maximum
    command('inoremap <Char-0xf03f> c')
    command([[execute "normal a\uf03f\<Esc>"]])

    -- Outside of the range, maximum
    command('inoremap <Char-0xf040> d')
    command([[execute "normal a\uf040\<Esc>"]])

    -- Remove empty line
    command('1d')

    -- Assert buffer contents.
    expect([[
      is<F4>foo
      {'lnum': 0, 'silent': 0, 'noremap': 0, 'lhs': 'foo<C-V>', 'mode': ' ', 'nowait': 0, 'expr': 0, 'sid': 0, 'rhs': 'is<F4>foo', 'buffer': 0}
      {'lnum': 0, 'silent': 1, 'noremap': 1, 'lhs': 'bar', 'mode': 'v', 'nowait': 0, 'expr': 1, 'sid': 0, 'rhs': 'isbar', 'buffer': 1}
      {'lnum': 0, 'silent': 0, 'noremap': 0, 'lhs': 'foo', 'mode': ' ', 'nowait': 1, 'expr': 0, 'sid': 0, 'rhs': 'bar', 'buffer': 1}
      xrx
      yRy
      abcd]])
  end)
end)
