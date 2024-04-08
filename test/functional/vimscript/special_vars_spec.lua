local t = require('test.functional.testutil')(after_each)
local exc_exec = t.exc_exec
local command = t.command
local fn = t.fn
local clear = t.clear
local eval = t.eval
local eq = t.eq
local api = t.api
local NIL = vim.NIL

describe('Special values', function()
  before_each(clear)

  it('do not cause error when freed', function()
    command([[
      function Test()
        try
          return v:true
        finally
          return 'something else'
        endtry
      endfunction
    ]])
    eq(0, exc_exec('call Test()'))
  end)

  it('work with empty()', function()
    eq(0, fn.empty(true))
    eq(1, fn.empty(false))
    eq(1, fn.empty(NIL))
  end)

  it('can be stringified and eval’ed back', function()
    eq(true, fn.eval(fn.string(true)))
    eq(false, fn.eval(fn.string(false)))
    eq(NIL, fn.eval(fn.string(NIL)))
  end)

  it('work with is/isnot properly', function()
    eq(1, eval('v:null is v:null'))
    eq(0, eval('v:null is v:true'))
    eq(0, eval('v:null is v:false'))
    eq(1, eval('v:true is v:true'))
    eq(0, eval('v:true is v:false'))
    eq(1, eval('v:false is v:false'))

    eq(0, eval('v:null  is 0'))
    eq(0, eval('v:true  is 0'))
    eq(0, eval('v:false is 0'))

    eq(0, eval('v:null  is 1'))
    eq(0, eval('v:true  is 1'))
    eq(0, eval('v:false is 1'))

    eq(0, eval('v:null  is ""'))
    eq(0, eval('v:true  is ""'))
    eq(0, eval('v:false is ""'))

    eq(0, eval('v:null  is "null"'))
    eq(0, eval('v:true  is "true"'))
    eq(0, eval('v:false is "false"'))

    eq(0, eval('v:null  is []'))
    eq(0, eval('v:true  is []'))
    eq(0, eval('v:false is []'))

    eq(0, eval('v:null isnot v:null'))
    eq(1, eval('v:null isnot v:true'))
    eq(1, eval('v:null isnot v:false'))
    eq(0, eval('v:true isnot v:true'))
    eq(1, eval('v:true isnot v:false'))
    eq(0, eval('v:false isnot v:false'))

    eq(1, eval('v:null  isnot 0'))
    eq(1, eval('v:true  isnot 0'))
    eq(1, eval('v:false isnot 0'))

    eq(1, eval('v:null  isnot 1'))
    eq(1, eval('v:true  isnot 1'))
    eq(1, eval('v:false isnot 1'))

    eq(1, eval('v:null  isnot ""'))
    eq(1, eval('v:true  isnot ""'))
    eq(1, eval('v:false isnot ""'))

    eq(1, eval('v:null  isnot "null"'))
    eq(1, eval('v:true  isnot "true"'))
    eq(1, eval('v:false isnot "false"'))

    eq(1, eval('v:null  isnot []'))
    eq(1, eval('v:true  isnot []'))
    eq(1, eval('v:false isnot []'))
  end)

  it('work with +/-/* properly', function()
    eq(1, eval('0 + v:true'))
    eq(0, eval('0 + v:null'))
    eq(0, eval('0 + v:false'))

    eq(-1, eval('0 - v:true'))
    eq(0, eval('0 - v:null'))
    eq(0, eval('0 - v:false'))

    eq(1, eval('1 * v:true'))
    eq(0, eval('1 * v:null'))
    eq(0, eval('1 * v:false'))
  end)

  it('does not work with +=/-=/.=', function()
    api.nvim_set_var('true', true)
    api.nvim_set_var('false', false)
    command('let null = v:null')

    eq('Vim(let):E734: Wrong variable type for +=', exc_exec('let true  += 1'))
    eq('Vim(let):E734: Wrong variable type for +=', exc_exec('let false += 1'))
    eq('Vim(let):E734: Wrong variable type for +=', exc_exec('let null  += 1'))

    eq('Vim(let):E734: Wrong variable type for -=', exc_exec('let true  -= 1'))
    eq('Vim(let):E734: Wrong variable type for -=', exc_exec('let false -= 1'))
    eq('Vim(let):E734: Wrong variable type for -=', exc_exec('let null  -= 1'))

    eq('Vim(let):E734: Wrong variable type for .=', exc_exec('let true  .= 1'))
    eq('Vim(let):E734: Wrong variable type for .=', exc_exec('let false .= 1'))
    eq('Vim(let):E734: Wrong variable type for .=', exc_exec('let null  .= 1'))
  end)

  it('work with . (concat) properly', function()
    eq('v:true', eval('"" . v:true'))
    eq('v:null', eval('"" . v:null'))
    eq('v:false', eval('"" . v:false'))
  end)

  it('work with ?? (falsy operator)', function()
    eq(true, eval('v:true ?? 42'))
    eq(42, eval('v:false ?? 42'))
    eq(42, eval('v:null ?? 42'))
  end)

  it('work with type()', function()
    eq(6, fn.type(true))
    eq(6, fn.type(false))
    eq(7, fn.type(NIL))
  end)

  it('work with copy() and deepcopy()', function()
    eq(true, fn.deepcopy(true))
    eq(false, fn.deepcopy(false))
    eq(NIL, fn.deepcopy(NIL))

    eq(true, fn.copy(true))
    eq(false, fn.copy(false))
    eq(NIL, fn.copy(NIL))
  end)

  it('fails in index', function()
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:true[0]'))
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:false[0]'))
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:null[0]'))
  end)

  it('is accepted by assert_true and assert_false', function()
    fn.assert_false(false)
    fn.assert_false(true)
    fn.assert_false(NIL)

    fn.assert_true(false)
    fn.assert_true(true)
    fn.assert_true(NIL)

    eq({
      'Expected False but got v:true',
      'Expected False but got v:null',
      'Expected True but got v:false',
      'Expected True but got v:null',
    }, api.nvim_get_vvar('errors'))
  end)

  describe('compat', function()
    it('v:count is distinct from count', function()
      command('let count = []') -- v:count is readonly
      eq(1, eval('count is# g:["count"]'))
    end)
    it('v:errmsg is distinct from errmsg', function()
      command('let errmsg = 1')
      eq(1, eval('errmsg is# g:["errmsg"]'))
    end)
    it('v:shell_error is distinct from shell_error', function()
      command('let shell_error = []') -- v:shell_error is readonly
      eq(1, eval('shell_error is# g:["shell_error"]'))
    end)
    it('v:this_session is distinct from this_session', function()
      command('let this_session = []')
      eq(1, eval('this_session is# g:["this_session"]'))
    end)
  end)
end)
