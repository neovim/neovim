local t = require('test.functional.testutil')(after_each)
local clear, eval, eq = t.clear, t.eval, t.eq
local exc_exec, source = t.exc_exec, t.source

describe('vimscript', function()
  before_each(clear)

  it('parses `<SID>` with turkish locale', function()
    if exc_exec('lang ctype tr_TR.UTF-8') ~= 0 then
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
    if exc_exec('lang ctype sv_SE.UTF-8') ~= 0 then
      pending('Locale sv_SE.UTF-8 not supported')
      return
    end
    clear { env = { LANG = '', LC_NUMERIC = 'sv_SE.UTF-8' } }
    eq(2.2, eval('str2float("2.2")'))
  end)
end)
