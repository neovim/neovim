local helpers = require('test.functional.helpers')(after_each)
local exc_exec = helpers.exc_exec
local command = helpers.command
local funcs = helpers.funcs
local clear = helpers.clear
local eval = helpers.eval
local eq = helpers.eq
local meths = helpers.meths
local NIL = helpers.NIL

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
    eq(0, funcs.empty(true))
    eq(1, funcs.empty(false))
    eq(1, funcs.empty(NIL))
  end)

  it('can be stringified and eval’ed back', function()
    eq(true, funcs.eval(funcs.string(true)))
    eq(false, funcs.eval(funcs.string(false)))
    eq(NIL, funcs.eval(funcs.string(NIL)))
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
    eq( 0, eval('0 - v:null'))
    eq( 0, eval('0 - v:false'))

    eq(1, eval('1 * v:true'))
    eq(0, eval('1 * v:null'))
    eq(0, eval('1 * v:false'))
  end)

  it('does not work with +=/-=/.=', function()
    meths.set_var('true', true)
    meths.set_var('false', false)
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
    eq("true", eval('"" . v:true'))
    eq("null", eval('"" . v:null'))
    eq("false", eval('"" . v:false'))
  end)

  it('work with type()', function()
    eq(6, funcs.type(true))
    eq(6, funcs.type(false))
    eq(7, funcs.type(NIL))
  end)

  it('work with copy() and deepcopy()', function()
    eq(true, funcs.deepcopy(true))
    eq(false, funcs.deepcopy(false))
    eq(NIL, funcs.deepcopy(NIL))

    eq(true, funcs.copy(true))
    eq(false, funcs.copy(false))
    eq(NIL, funcs.copy(NIL))
  end)

  it('fails in index', function()
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:true[0]'))
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:false[0]'))
    eq('Vim(echo):E909: Cannot index a special variable', exc_exec('echo v:null[0]'))
  end)

  it('is accepted by assert_true and assert_false', function()
    funcs.assert_false(false)
    funcs.assert_false(true)
    funcs.assert_false(NIL)

    funcs.assert_true(false)
    funcs.assert_true(true)
    funcs.assert_true(NIL)

    eq({
      'Expected False but got v:true',
      'Expected False but got v:null',
      'Expected True but got v:false',
      'Expected True but got v:null',
    }, meths.get_vvar('errors'))
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
