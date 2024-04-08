local t = require('test.functional.testutil')(after_each)

local eq = t.eq
local eval = t.eval
local feed = t.feed
local clear = t.clear
local expect = t.expect
local command = t.command
local fn = t.fn
local api = t.api
local insert = t.insert

describe('macros', function()
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
    insert [[hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>q]]
    eq({ 'helloFOO', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[Q]]
    eq({ 'helloFOOFOO', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[G3Q]]
    eq({ 'helloFOOFOO', 'hello', 'helloFOOFOOFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[ggV3jQ]]
    eq(
      { 'helloFOOFOOFOO', 'helloFOO', 'helloFOOFOOFOOFOO' },
      api.nvim_buf_get_lines(0, 0, -1, false)
    )
  end)

  it('can be replayed with @', function()
    insert [[hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>q]]
    eq({ 'helloFOO', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[Q]]
    eq({ 'helloFOOFOO', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[G3@@]]
    eq({ 'helloFOOFOO', 'hello', 'helloFOOFOOFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[ggV2j@@]]
    eq(
      { 'helloFOOFOOFOO', 'helloFOO', 'helloFOOFOOFOOFOO' },
      api.nvim_buf_get_lines(0, 0, -1, false)
    )
  end)

  it('can be replayed with @q and @w', function()
    insert [[hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>qu]]
    eq({ 'hello', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[qwA123<esc>qu]]
    eq({ 'hello', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[V3j@q]]
    eq({ 'helloFOO', 'helloFOO', 'helloFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[gg]]
    feed [[Vj@w]]
    eq({ 'helloFOO123', 'helloFOO123', 'helloFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('can be replayed with @q and @w visual-block', function()
    insert [[hello
hello
hello]]
    feed [[gg]]

    feed [[qqAFOO<esc>qu]]
    eq({ 'hello', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[qwA123<esc>qu]]
    eq({ 'hello', 'hello', 'hello' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[<C-v>3j@q]]
    eq({ 'helloFOO', 'helloFOO', 'helloFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))

    feed [[gg]]
    feed [[<C-v>j@w]]
    eq({ 'helloFOO123', 'helloFOO123', 'helloFOO' }, api.nvim_buf_get_lines(0, 0, -1, false))
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
