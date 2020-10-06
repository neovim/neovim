local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command = helpers.command
local expect = helpers.expect

describe('meta-keys-in-visual-mode', function()
  before_each(function()
    clear()
  end)

  it('ALT/META', function()
    -- Unmapped ALT-chords behave as Esc+c
    insert('peaches')
    feed('viw<A-x>viw<M-x>')
    expect('peach')
    -- Mapped ALT-chord behaves as mapped.
    command('vnoremap <M-l> Ameta-l<Esc>')
    command('vnoremap <A-j> Aalt-j<Esc>')
    feed('viw<A-j>viw<M-l>')
    expect('peachalt-jmeta-l')
  end)
end)
