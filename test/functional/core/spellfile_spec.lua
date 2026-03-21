local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local api = n.api
local exc_exec = n.exc_exec
local fn = n.fn
local rmdir = n.rmdir
local write_file = t.write_file
local mkdir = t.mkdir

local testdir = 'Xtest-functional-spell-spellfile.d'

describe('spellfile', function()
  before_each(function()
    clear({ env = { XDG_DATA_HOME = testdir .. '/xdg_data' } })
    rmdir(testdir)
    mkdir(testdir)
    mkdir(testdir .. '/spell')
  end)
  after_each(function()
    rmdir(testdir)
  end)
  --                   ┌ Magic string (#VIMSPELLMAGIC)
  --                   │       ┌ Spell file version (#VIMSPELLVERSION)
  local spellheader = 'VIMspell\050'
  it('errors out when prefcond section is truncated', function()
    api.nvim_set_option_value('runtimepath', testdir, {})
    -- stylua: ignore
    write_file(testdir .. '/spell/en.ascii.spl',
    --                         ┌ Section identifier (#SN_PREFCOND)
    --                         │   ┌ Section flags (#SNF_REQUIRED or zero)
    --                         │   │   ┌ Section length (4 bytes, MSB first)
               spellheader .. '\003\001\000\000\000\003'
    --             ┌ Number of regexes in section (2 bytes, MSB first)
    --             │       ┌ Condition length (1 byte)
    --             │       │   ┌ Condition regex (missing!)
               .. '\000\001\001')
    api.nvim_set_option_value('spelllang', 'en', {})
    eq('Vim(set):E758: Truncated spell file', exc_exec('set spell'))
  end)
  it('errors out when prefcond regexp contains NUL byte', function()
    api.nvim_set_option_value('runtimepath', testdir, {})
    -- stylua: ignore
    write_file(testdir .. '/spell/en.ascii.spl',
    --                         ┌ Section identifier (#SN_PREFCOND)
    --                         │   ┌ Section flags (#SNF_REQUIRED or zero)
    --                         │   │   ┌ Section length (4 bytes, MSB first)
               spellheader .. '\003\001\000\000\000\008'
    --             ┌ Number of regexes in section (2 bytes, MSB first)
    --             │       ┌ Condition length (1 byte)
    --             │       │   ┌ Condition regex
    --             │       │   │       ┌ End of sections marker
               .. '\000\001\005ab\000cd\255'
    --             ┌ LWORDTREE tree length (4 bytes)
    --             │               ┌ KWORDTREE tree length (4 bytes)
    --             │               │               ┌ PREFIXTREE tree length
               .. '\000\000\000\000\000\000\000\000\000\000\000\000')
    api.nvim_set_option_value('spelllang', 'en', {})
    eq('Vim(set):E759: Format error in spell file', exc_exec('set spell'))
  end)
  it('errors out when region contains NUL byte', function()
    api.nvim_set_option_value('runtimepath', testdir, {})
    -- stylua: ignore
    write_file(testdir .. '/spell/en.ascii.spl',
    --                         ┌ Section identifier (#SN_REGION)
    --                         │   ┌ Section flags (#SNF_REQUIRED or zero)
    --                         │   │   ┌ Section length (4 bytes, MSB first)
               spellheader .. '\000\001\000\000\000\008'
    --             ┌ Regions  ┌ End of sections marker
               .. '01234\00067\255'
    --             ┌ LWORDTREE tree length (4 bytes)
    --             │               ┌ KWORDTREE tree length (4 bytes)
    --             │               │               ┌ PREFIXTREE tree length
               .. '\000\000\000\000\000\000\000\000\000\000\000\000')
    api.nvim_set_option_value('spelllang', 'en', {})
    eq('Vim(set):E759: Format error in spell file', exc_exec('set spell'))
  end)
  it('errors out when SAL section contains NUL byte', function()
    api.nvim_set_option_value('runtimepath', testdir, {})
    -- stylua: ignore
    write_file(testdir .. '/spell/en.ascii.spl',
    --                         ┌ Section identifier (#SN_SAL)
    --                         │   ┌ Section flags (#SNF_REQUIRED or zero)
    --                         │   │   ┌ Section length (4 bytes, MSB first)
               spellheader .. '\005\001\000\000\000\008'
    --             ┌ salflags
    --             │   ┌ salcount (2 bytes, MSB first)
    --             │   │       ┌ salfromlen (1 byte)
    --             │   │       │   ┌ Special character
    --             │   │       │   │┌ salfrom (should not contain NUL)
    --             │   │       │   ││   ┌ saltolen
    --             │   │       │   ││   │   ┌ salto
    --             │   │       │   ││   │   │┌ End of sections marker
               .. '\000\000\001\0024\000\0017\255'
    --             ┌ LWORDTREE tree length (4 bytes)
    --             │               ┌ KWORDTREE tree length (4 bytes)
    --             │               │               ┌ PREFIXTREE tree length
               .. '\000\000\000\000\000\000\000\000\000\000\000\000')
    api.nvim_set_option_value('spelllang', 'en', {})
    eq('Vim(set):E759: Format error in spell file', exc_exec('set spell'))
  end)
  it('errors out when spell header contains NUL bytes', function()
    api.nvim_set_option_value('runtimepath', testdir, {})
    write_file(testdir .. '/spell/en.ascii.spl', spellheader:sub(1, -3) .. '\000\000')
    api.nvim_set_option_value('spelllang', 'en', {})
    eq('Vim(set):E757: This does not look like a spell file', exc_exec('set spell'))
  end)

  it('can be set to a relative path', function()
    local fname = testdir .. '/spell/spell.add'
    api.nvim_set_option_value('spellfile', fname, {})
  end)

  it('can be set to an absolute path', function()
    local fname = fn.fnamemodify(testdir .. '/spell/spell.add', ':p')
    api.nvim_set_option_value('spellfile', fname, {})
  end)

  describe('default location', function()
    it("is stdpath('data')/site/spell/en.utf-8.add", function()
      n.command('set spell')
      n.insert('abc')
      n.feed('zg')
      eq(
        t.fix_slashes(fn.stdpath('data') .. '/site/spell/en.utf-8.add'),
        t.fix_slashes(api.nvim_get_option_value('spellfile', {}))
      )
    end)

    it("is not set if stdpath('data') is not writable", function()
      n.command('set spell')
      fn.writefile({ '' }, testdir .. '/xdg_data')
      n.insert('abc')
      eq("Vim(normal):E764: Option 'spellfile' is not set", exc_exec('normal! zg'))
    end)

    it("is not set if 'spelllang' is not set", function()
      n.command('set spell spelllang=')
      n.insert('abc')
      eq("Vim(normal):E764: Option 'spellfile' is not set", exc_exec('normal! zg'))
    end)
  end)
end)
