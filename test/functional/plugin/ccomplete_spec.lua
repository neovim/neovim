local t = require('test.functional.testutil')()
local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval
local feed = t.feed
local write_file = t.write_file

describe('ccomplete#Complete', function()
  setup(function()
    -- Realistic tags generated from neovim source tree using `ctags -R *`
    write_file(
      'Xtags',
      [[
augroup_del	src/nvim/autocmd.c	/^void augroup_del(char *name, bool stupid_legacy_mode)$/;"	f	typeref:typename:void
augroup_exists	src/nvim/autocmd.c	/^bool augroup_exists(const char *name)$/;"	f	typeref:typename:bool
augroup_find	src/nvim/autocmd.c	/^int augroup_find(const char *name)$/;"	f	typeref:typename:int
aupat_get_buflocal_nr	src/nvim/autocmd.c	/^int aupat_get_buflocal_nr(char *pat, int patlen)$/;"	f	typeref:typename:int
aupat_is_buflocal	src/nvim/autocmd.c	/^bool aupat_is_buflocal(char *pat, int patlen)$/;"	f	typeref:typename:bool
expand_get_augroup_name	src/nvim/autocmd.c	/^char *expand_get_augroup_name(expand_T *xp, int idx)$/;"	f	typeref:typename:char *
expand_get_event_name	src/nvim/autocmd.c	/^char *expand_get_event_name(expand_T *xp, int idx)$/;"	f	typeref:typename:char *
]]
    )
  end)

  before_each(function()
    clear()
    command('set tags=Xtags')
  end)

  teardown(function()
    os.remove('Xtags')
  end)

  it('can complete from Xtags', function()
    local completed = eval('ccomplete#Complete(0, "a")')
    eq(5, #completed)
    eq('augroup_del(', completed[1].word)
    eq('f', completed[1].kind)

    local aupat = eval('ccomplete#Complete(0, "aupat")')
    eq(2, #aupat)
    eq('aupat_get_buflocal_nr(', aupat[1].word)
    eq('f', aupat[1].kind)
  end)

  it('does not error when returning no matches', function()
    local completed = eval('ccomplete#Complete(0, "doesnotmatch")')
    eq({}, completed)
  end)

  it('can find the beginning of a word for C', function()
    command('set filetype=c')
    feed('i  int something = augroup')
    local result = eval('ccomplete#Complete(1, "")')
    eq(#'  int something = ', result)

    local completed = eval('ccomplete#Complete(0, "augroup")')
    eq(3, #completed)
  end)
end)
