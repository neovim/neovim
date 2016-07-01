local helpers = require('test.functional.helpers')(after_each)
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local execute, source = helpers.execute, helpers.source

describe('turkish', function()
  before_each(clear)

  it('applies locale to \'i\' in `<SID>` comparison', function()
    execute('lang ctype tr_TR.UTF-8')
    if string.find(eval('v:errmsg'), '^E197: ') then
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
end)
