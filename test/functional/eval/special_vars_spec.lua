local helpers = require('test.functional.helpers')
local execute = helpers.execute
local funcs = helpers.funcs
local clear = helpers.clear
local eval = helpers.eval

describe('Special values', function()
  before_each(clear)

  it('do not cause error when freed', function()
    execute([[
      function Test()
        try
          return v:true
        finally
          return 'something else'
        endtry
      endfunction
    ]])
    eq(true, funcs.Test())
  end)

  it('work with empty()', function()
    eq(0, funcs.empty(true))
    eq(1, funcs.empty(false))
    eq(1, funcs.empty(nil))
    eq(1, eval('empty(v:none)'))
  end)

  it('can be stringified and eval’ed back', function()
    eq(true, funcs.eval(funcs.string(true)))
    eq(false, funcs.eval(funcs.string(false)))
    eq(nil, funcs.eval(funcs.string(nil)))
    eq(1, eval('eval(string(v:none)) is# v:none'))
  end)
end)
