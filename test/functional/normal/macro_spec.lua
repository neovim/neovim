local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local expect = helpers.expect
local command = helpers.command

describe('macros', function()
  before_each(clear)
  it('can be recorded and replayed', function()
    feed('qiahello<esc>q')
    expect('hello')
    eq(eval('@i'), 'ahello')
    feed('@i')
    expect('hellohello')
    eq(eval('@i'), 'ahello')
  end)
  it('applies maps', function()
    command('imap x l')
    command('nmap l a')
    feed('qilxxx<esc>q')
    expect('lll')
    eq(eval('@i'), 'lxxx')
    feed('@i')
    expect('llllll')
    eq(eval('@i'), 'lxxx')
  end)
end)
