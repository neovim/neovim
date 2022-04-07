local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local expect = helpers.expect
local command = helpers.command
local funcs = helpers.funcs
local meths = helpers.meths
local insert = helpers.insert
local curbufmeths = helpers.curbufmeths

before_each(clear)

describe('macros', function()
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

describe('immediately after a macro has finished executing,', function()
  before_each(function()
    command([[let @a = 'gg0']])
  end)

  it('reg_executing() from RPC returns an empty string', function()
    feed('@a')
    eq('', funcs.reg_executing())
  end)

  it('reg_executing() from RPC returns an empty string if macro ends with empty mapping', function()
    command('nnoremap gg0 <Nop>')
    feed('@a')
    eq('', funcs.reg_executing())
  end)

  it('characters from a mapping are not treated as a part of the macro #18015', function()
    command('nnoremap s qa')
    feed('@asq')  -- "q" from "s" mapping should start recording a macro instead of being no-op
    eq({mode = 'n', blocking = false}, meths.get_mode())
    expect('')
    eq('', eval('@a'))
  end)
end)

describe('reg_recorded()', function()
  it('returns the correct value', function()
    feed [[qqyyq]]
    eq('q', eval('reg_recorded()'))
  end)
end)
