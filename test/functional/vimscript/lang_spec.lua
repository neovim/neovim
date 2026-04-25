local t = require('test.testutil')
local n = require('test.functional.testnvim')()

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
end)
