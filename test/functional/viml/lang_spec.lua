local helpers = require('test.functional.helpers')(after_each)
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local exc_exec, source = helpers.exc_exec, helpers.source

describe('viml', function()
  before_each(clear)

  it('parses `<SID>` with turkish locale', function()
    if exc_exec('lang ctype tr_TR.UTF-8') ~= 0 then
      pending("Locale tr_TR.UTF-8 not supported")
      return
    end
    source([[
      func! <sid>_dummy_function()
        echo 1
      endfunc
      au VimEnter * call <sid>_dummy_function()
    ]])
    eq(nil, string.find(eval('v:errmsg'), '^E129'))
  end)

  it('str2float is not affected by locale', function()
    if exc_exec('lang ctype sv_SE.UTF-8') ~= 0 then
      pending("Locale sv_SE.UTF-8 not supported")
      return
    end
    clear{env={LANG="", LC_NUMERIC="sv_SE.UTF-8"}}
    eq(2.2, eval('str2float("2.2")'))
  end)
end)
