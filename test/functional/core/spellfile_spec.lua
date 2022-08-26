local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')

local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local exc_exec = helpers.exc_exec
local rmdir = helpers.rmdir
local write_file = helpers.write_file

local testdir = 'Xtest-functional-spell-spellfile.d'

describe('spellfile', function()
  before_each(function()
    clear()
    rmdir(testdir)
    lfs.mkdir(testdir)
    lfs.mkdir(testdir .. '/spell')
  end)
  after_each(function()
    rmdir(testdir)
  end)
  --                   ┌ Magic string (#VIMSPELLMAGIC)
  --                   │       ┌ Spell file version (#VIMSPELLVERSION)
  local spellheader = 'VIMspell\050'
  it('errors out when prefcond section is truncated', function()
    meths.set_option('runtimepath', testdir)
    write_file(testdir .. '/spell/en.ascii.spl',
    --                         ┌ Section identifier (#SN_PREFCOND)
    --                         │   ┌ Section flags (#SNF_REQUIRED or zero)
    --                         │   │   ┌ Section length (4 bytes, MSB first)
               spellheader .. '\003\001\000\000\000\003'
    --             ┌ Number of regexes in section (2 bytes, MSB first)
    --             │       ┌ Condition length (1 byte)
    --             │       │   ┌ Condition regex (missing!)
               .. '\000\001\001')
    meths.set_option('spelllang', 'en')
    eq('Vim(set):E758: Truncated spell file',
       exc_exec('set spell'))
  end)
  it('errors out when prefcond regexp contains NUL byte', function()
    meths.set_option('runtimepath', testdir)
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
    meths.set_option('spelllang', 'en')
    eq('Vim(set):E759: Format error in spell file',
       exc_exec('set spell'))
  end)
  it('errors out when region contains NUL byte', function()
    meths.set_option('runtimepath', testdir)
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
    meths.set_option('spelllang', 'en')
    eq('Vim(set):E759: Format error in spell file',
       exc_exec('set spell'))
  end)
  it('errors out when SAL section contains NUL byte', function()
    meths.set_option('runtimepath', testdir)
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
    meths.set_option('spelllang', 'en')
    eq('Vim(set):E759: Format error in spell file',
       exc_exec('set spell'))
  end)
  it('errors out when spell header contains NUL bytes', function()
    meths.set_option('runtimepath', testdir)
    write_file(testdir .. '/spell/en.ascii.spl',
               spellheader:sub(1, -3) .. '\000\000')
    meths.set_option('spelllang', 'en')
    eq('Vim(set):E757: This does not look like a spell file',
       exc_exec('set spell'))
  end)
end)
