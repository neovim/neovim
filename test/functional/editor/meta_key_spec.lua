local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command = helpers.command
local expect = helpers.expect

describe('meta-keys-in-normal-mode', function()
  before_each(function()
    clear()
  end)

  it('ALT/META', function()
    -- Unmapped ALT-chords behave as Esc+c
    insert('hello')
    feed('0<A-x><M-x>')
    expect('llo')
    -- Mapped ALT-chord behaves as mapped.
    command('nnoremap <M-l> Ameta-l<Esc>')
    command('nnoremap <A-j> Aalt-j<Esc>')
    feed('<A-j><M-l>')
    expect('lloalt-jmeta-l')
  end)
end)
