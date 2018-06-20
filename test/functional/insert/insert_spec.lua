local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command = helpers.command
local eq = helpers.eq
local expect = helpers.expect
local funcs = helpers.funcs

describe('insert-mode', function()
  before_each(function()
    clear()
  end)

  it('CTRL-@', function()
    -- Inserts last-inserted text, leaves insert-mode.
    insert('hello')
    feed('i<C-@>x')
    expect('hellhello')

    -- C-Space is the same as C-@.
    -- CTRL-SPC inserts last-inserted text, leaves insert-mode.
    feed('i<C-Space>x')
    expect('hellhellhello')

    -- CTRL-A inserts last inserted text
    feed('i<C-A>x')
    expect('hellhellhellhelloxo')
  end)

  it('ALT/META #8213', function()
    -- Mapped ALT-chord behaves as mapped.
    command('inoremap <M-l> meta-l')
    command('inoremap <A-j> alt-j')
    feed('i<M-l> xxx <A-j><M-h>a<A-h>')
    expect('meta-l xxx alt-j')
    eq({ 0, 1, 14, 0, }, funcs.getpos('.'))
    -- Unmapped ALT-chord behaves as ESC+c.
    command('iunmap <M-l>')
    feed('0i<M-l>')
    eq({ 0, 1, 2, 0, }, funcs.getpos('.'))
  end)
end)
