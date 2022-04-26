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
    eq('ahello', eval('@i'))
    feed('@i')
    expect('hellohello')
    eq('ahello', eval('@i'))
  end)
  it('applies maps', function()
    command('imap x l')
    command('nmap l a')
    feed('qilxxx<esc>q')
    expect('lll')
    eq('lxxx', eval('@i'))
    feed('@i')
    expect('llllll')
    eq('lxxx', eval('@i'))
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

  describe('reg_executing() from RPC returns an empty string', function()
    it('if the macro does not end with a <Nop> mapping', function()
      feed('@a')
      eq('', funcs.reg_executing())
    end)

    it('if the macro ends with a <Nop> mapping', function()
      command('nnoremap 0 <Nop>')
      feed('@a')
      eq('', funcs.reg_executing())
    end)
  end)

  describe('characters from a mapping are not treated as a part of the macro #18015', function()
    before_each(function()
      command('nnoremap s qa')
    end)

    it('if the macro does not end with a <Nop> mapping', function()
      feed('@asq')  -- "q" from "s" mapping should start recording a macro instead of being no-op
      eq({mode = 'n', blocking = false}, meths.get_mode())
      expect('')
      eq('', eval('@a'))
    end)

    it('if the macro ends with a <Nop> mapping', function()
      command('nnoremap 0 <Nop>')
      feed('@asq')  -- "q" from "s" mapping should start recording a macro instead of being no-op
      eq({mode = 'n', blocking = false}, meths.get_mode())
      expect('')
      eq('', eval('@a'))
    end)
  end)
end)

describe('reg_recorded()', function()
  it('returns the correct value', function()
    feed [[qqyyq]]
    eq('q', eval('reg_recorded()'))
  end)
end)
