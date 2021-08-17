local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local expect = helpers.expect
local command = helpers.command
local insert = helpers.insert
local curbufmeths = helpers.curbufmeths

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

  it('can be replayed with Q', function()
    insert [[hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>q]]
    eq({'helloFOO', 'hello', 'hello'}, curbufmeths.get_lines(0, -1, false))

    feed[[Q]]
    eq({'helloFOOFOO', 'hello', 'hello'}, curbufmeths.get_lines(0, -1, false))

    feed[[G3Q]]
    eq({'helloFOOFOO', 'hello', 'helloFOOFOOFOO'}, curbufmeths.get_lines(0, -1, false))
  end)
end)

describe('reg_recorded()', function()
  before_each(clear)

  it('returns the correct value', function()
    feed [[qqyyq]]
    eq('q', eval('reg_recorded()'))
  end)
end)
