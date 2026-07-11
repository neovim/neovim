local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')
local n = require('test.functional.testnvim')()

local eq = t.eq
local eval = n.eval
local feed = n.feed
local clear = n.clear
local expect = n.expect
local command = n.command
local fn = n.fn
local api = n.api
local insert = n.insert

describe('macro recording with requeued key', function()
  before_each(function()
    clear({ args_rm = { '--cmd' } })
  end)

  it('mapped key does not corrupt the recording', function()
    -- Typing over a Select-mode selection puts the key back for Insert mode (requeue_key()).
    -- A key produced by a mapping is not "typed", so ungetchars() must not touch the recording.
    command('snoremap Z Y')
    insert('abc')
    feed('qq0ghZ<Esc>q')
    -- "Y" replaced the selected "a".
    expect('Ybc')
    -- The recording holds the typed keys: the "Y" mapping must not have eaten the recorded "Z".
    eq('0ghZ\27', eval('@q'))
  end)

  it('at hit-enter prompt records the key ONCE', function()
    -- A non-prompt key typed at the hit-enter prompt is put back to execute
    -- as a normal command: it is consumed twice, but must be recorded once.
    local screen = Screen.new(40, 6)
    insert('abc')
    feed('qq0')
    feed(':echo "one\\ntwo"<CR>')
    -- The prompt must actually engage (needs an attached UI).
    screen:expect({ any = 'Press ENTER' })
    feed('x')
    feed('q')
    expect('bc')
    eq('0:echo "one\\ntwo"\rx', eval('@q'))
    -- Replaying executes "x" once, not twice.
    feed('@q')
    expect('c')
  end)
end)

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

  it('can be recorded and replayed in Visual mode when ignorecase', function()
    command('set ignorecase')
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
