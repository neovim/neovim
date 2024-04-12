local t = require('test.functional.testutil')()

local eq = t.eq
local eval = t.eval
local feed = t.feed
local clear = t.clear
local expect = t.expect
local command = t.command
local fn = t.fn
local api = t.api
local insert = t.insert

describe('macros with default mappings', function()
  before_each(function()
    clear({ args_rm = { '--cmd' } })
  end)

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
    insert [[
hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>q]]
    expect [[
helloFOO
hello
hello]]

    feed [[Q]]
    expect [[
helloFOOFOO
hello
hello]]

    feed [[G3Q]]
    expect [[
helloFOOFOO
hello
helloFOOFOOFOO]]

    feed [[ggV3jQ]]
    expect [[
helloFOOFOOFOO
helloFOO
helloFOOFOOFOOFOO]]
  end)

  it('can be replayed with Q and @@', function()
    insert [[
hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>q]]
    expect [[
helloFOO
hello
hello]]

    feed [[Q]]
    expect [[
helloFOOFOO
hello
hello]]

    feed [[G3@@]]
    expect [[
helloFOOFOO
hello
helloFOOFOOFOO]]

    feed [[ggV2j@@]]
    expect [[
helloFOOFOOFOO
helloFOO
helloFOOFOOFOOFOO]]
  end)

  it('can be replayed with @ in linewise Visual mode', function()
    insert [[
hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[qwA123<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[V3j@q]]
    expect [[
helloFOO
helloFOO
helloFOO]]

    feed [[ggVj@w]]
    expect [[
helloFOO123
helloFOO123
helloFOO]]
  end)

  -- XXX: does this really make sense?
  it('can be replayed with @ in blockwise Visual mode', function()
    insert [[
hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[qwA123<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[<C-v>3j@q]]
    expect [[
helloFOO
helloFOO
helloFOO]]

    feed [[gg<C-v>j@w]]
    expect [[
helloFOO123
helloFOO123
helloFOO]]
  end)
end)

describe('macros without default mappings', function()
  before_each(clear)

  it('can be recorded and replayed in Visual mode', function()
    insert('foo BAR BAR foo BAR foo BAR BAR BAR foo BAR BAR')
    feed('0vqifofRq')
    eq({ 0, 1, 7, 0 }, fn.getpos('.'))
    eq({ 0, 1, 1, 0 }, fn.getpos('v'))
    feed('Q')
    eq({ 0, 1, 19, 0 }, fn.getpos('.'))
    eq({ 0, 1, 1, 0 }, fn.getpos('v'))
    feed('Q')
    eq({ 0, 1, 27, 0 }, fn.getpos('.'))
    eq({ 0, 1, 1, 0 }, fn.getpos('v'))
    feed('@i')
    eq({ 0, 1, 43, 0 }, fn.getpos('.'))
    eq({ 0, 1, 1, 0 }, fn.getpos('v'))
  end)

  it('can be replayed with @ in blockwise Visual mode', function()
    insert [[
hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[qwA123<esc>qu]]
    expect [[
hello
hello
hello]]

    feed [[0<C-v>3jl@q]]
    expect [[
heFOOllo
heFOOllo
heFOOllo]]

    feed [[gg0<C-v>j@w]]
    expect [[
h123eFOOllo
h123eFOOllo
heFOOllo]]
  end)
end)

describe('immediately after a macro has finished executing,', function()
  before_each(function()
    clear()
    command([[let @a = 'gg0']])
  end)

  describe('reg_executing() from RPC returns an empty string', function()
    it('if the macro does not end with a <Nop> mapping', function()
      feed('@a')
      eq('', fn.reg_executing())
    end)

    it('if the macro ends with a <Nop> mapping', function()
      command('nnoremap 0 <Nop>')
      feed('@a')
      eq('', fn.reg_executing())
    end)
  end)

  describe('characters from a mapping are not treated as a part of the macro #18015', function()
    before_each(function()
      command('nnoremap s qa')
    end)

    it('if the macro does not end with a <Nop> mapping', function()
      feed('@asq') -- "q" from "s" mapping should start recording a macro instead of being no-op
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      expect('')
      eq('', eval('@a'))
    end)

    it('if the macro ends with a <Nop> mapping', function()
      command('nnoremap 0 <Nop>')
      feed('@asq') -- "q" from "s" mapping should start recording a macro instead of being no-op
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      expect('')
      eq('', eval('@a'))
    end)
  end)
end)

describe('reg_recorded()', function()
  before_each(clear)
  it('returns the correct value', function()
    feed [[qqyyq]]
    eq('q', eval('reg_recorded()'))
  end)
end)
