local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, pending = t.describe, t.it, t.before_each, t.pending
local clear, eval, eq = n.clear, n.eval, t.eq
local source = n.source

describe('vimscript', function()
  before_each(clear)

  it('parses `<SID>` with turkish locale', function()
    if not pcall(n.command, 'lang ctype tr_TR.UTF-8') then
      pending('Locale tr_TR.UTF-8 not supported')
      return
    end
    source([[
      let s:foo = 1
      func! <sid>_dummy_function()
        echo 1
      endfunc
      au VimEnter * call <sid>_dummy_function()
    ]])
    eq(nil, string.find(eval('v:errmsg'), '^E129'))
  end)

  it('str2float is not affected by locale', function()
    if not pcall(n.command, 'lang ctype sv_SE.UTF-8') then
      pending('Locale sv_SE.UTF-8 not supported')
      return
    end
    clear { env = { LANG = '', LC_NUMERIC = 'sv_SE.UTF-8' } }
    eq(2.2, eval('str2float("2.2")'))
  end)

  it('uses a UTF-8 locale when $LANG has no encoding #11432', function()
    t.skip(t.is_os('win'))
    clear { env = { LANG = 'en_GB' } }
    local locales = n.fn.system('locale -a')
    -- Only C.UTF-8 or en_US.UTF-8 are candidates the fix can actually pick.
    if
      not (
        string.find(locales, 'C%.[uU][tT][fF]%-?8')
        or string.find(locales, 'en_US%.[uU][tT][fF]%-?8')
      )
    then
      pending('no UTF-8 locale available')
      return
    end
    t.matches('[uU][tT][fF]%-?8', n.eval('v:ctype'))
    t.matches('[uU][tT][fF]%-?8', n.eval('$LC_CTYPE'))
  end)

  it('does not override a locale that already uses UTF-8', function()
    if not pcall(n.command, 'lang ctype en_US.UTF-8') then
      pending('Locale en_US.UTF-8 not supported')
      return
    end
    clear { env = { LANG = 'en_US.UTF-8' } }
    t.matches('en_US', n.eval('v:ctype'))
    -- $LC_CTYPE is only exported when the fix actually forces a locale.
    eq('', n.eval('$LC_CTYPE'))
  end)
end)
