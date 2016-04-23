local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local command = helpers.command
local meths = helpers.meths
local eval = helpers.eval
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec
local funcs = helpers.funcs
local write_file = helpers.write_file
local NIL = helpers.NIL

describe('string() function', function()
  before_each(clear)

  describe('used to represent floating-point values', function()
    it('dumps NaN values', function()
      eq('str2float(\'nan\')', eval('string(str2float(\'nan\'))'))
    end)

    it('dumps infinite values', function()
      eq('str2float(\'inf\')', eval('string(str2float(\'inf\'))'))
      eq('-str2float(\'inf\')', eval('string(str2float(\'-inf\'))'))
    end)

    it('dumps regular values', function()
      eq('1.5', funcs.string(1.5))
      eq('1.56e-20', funcs.string(1.56000e-020))
      eq('0.0', eval('string(0.0)'))
    end)

    it('dumps special v: values', function()
      eq('v:true', eval('string(v:true)'))
      eq('v:false', eval('string(v:false)'))
      eq('v:null', eval('string(v:null)'))
      eq('v:true', funcs.string(true))
      eq('v:false', funcs.string(false))
      eq('v:null', funcs.string(NIL))
    end)

    it('dumps values with at most six digits after the decimal point',
    function()
      eq('1.234568e-20', funcs.string(1.23456789123456789123456789e-020))
      eq('1.234568', funcs.string(1.23456789123456789123456789))
    end)

    it('dumps values with at most seven digits before the decimal point',
    function()
      eq('1234567.891235', funcs.string(1234567.89123456789123456789))
      eq('1.234568e7', funcs.string(12345678.9123456789123456789))
    end)

    it('dumps negative values', function()
      eq('-1.5', funcs.string(-1.5))
      eq('-1.56e-20', funcs.string(-1.56000e-020))
      eq('-1.234568e-20', funcs.string(-1.23456789123456789123456789e-020))
      eq('-1.234568', funcs.string(-1.23456789123456789123456789))
      eq('-1234567.891235', funcs.string(-1234567.89123456789123456789))
      eq('-1.234568e7', funcs.string(-12345678.9123456789123456789))
    end)
  end)

  describe('used to represent numbers', function()
    it('dumps regular values', function()
      eq('0', funcs.string(0))
      eq('-1', funcs.string(-1))
      eq('1', funcs.string(1))
    end)

    it('dumps large values', function()
      eq('2147483647', funcs.string(2^31-1))
      eq('-2147483648', funcs.string(-2^31))
    end)
  end)

  describe('used to represent strings', function()
    it('dumps regular strings', function()
      eq('\'test\'', funcs.string('test'))
    end)

    it('dumps empty strings', function()
      eq('\'\'', funcs.string(''))
    end)

    it('dumps strings with \' inside', function()
      eq('\'\'\'\'\'\'\'\'', funcs.string('\'\'\''))
      eq('\'a\'\'b\'\'\'\'\'', funcs.string('a\'b\'\''))
      eq('\'\'\'b\'\'\'\'d\'', funcs.string('\'b\'\'d'))
      eq('\'a\'\'b\'\'c\'\'d\'', funcs.string('a\'b\'c\'d'))
    end)

    it('dumps NULL strings', function()
      eq('\'\'', eval('string($XXX_UNEXISTENT_VAR_XXX)'))
    end)

    it('dumps NULL lists', function()
      eq('[]', eval('string(v:_null_list)'))
    end)

    it('dumps NULL dictionaries', function()
      eq('{}', eval('string(v:_null_dict)'))
    end)
  end)

  describe('used to represent funcrefs', function()
    local fname = 'Xtest-functional-eval-string_spec-fref-script.vim'

    before_each(function()
      write_file(fname, [[
        function Test1()
        endfunction

        function s:Test2()
        endfunction

        function g:Test3()
        endfunction

        let g:Test2_f = function('s:Test2')
      ]])
      command('source ' .. fname)
    end)

    after_each(function()
      os.remove(fname)
    end)

    it('dumps references to built-in functions', function()
      eq('function(\'function\')', eval('string(function("function"))'))
    end)

    it('dumps references to user functions', function()
      eq('function(\'Test1\')', eval('string(function("Test1"))'))
      eq('function(\'g:Test3\')', eval('string(function("g:Test3"))'))
    end)

    it('dumps references to script functions', function()
      eq('function(\'<SNR>1_Test2\')', eval('string(Test2_f)'))
    end)
  end)

  describe('used to represent lists', function()
    it('dumps empty list', function()
      eq('[]', funcs.string({}))
    end)

    it('dumps nested lists', function()
      eq('[[[[[]]]]]', funcs.string({{{{{}}}}}))
    end)

    it('dumps nested non-empty lists', function()
      eq('[1, [[3, [[5], 4]], 2]]', funcs.string({1, {{3, {{5}, 4}}, 2}}))
    end)

    it('errors when dumping recursive lists', function()
      meths.set_var('l', {})
      eval('add(l, l)')
      eq('Vim(echo):E724: unable to correctly dump variable with self-referencing container',
         exc_exec('echo string(l)'))
    end)

    it('dumps recursive lists despite the error', function()
      meths.set_var('l', {})
      eval('add(l, l)')
      eq('\nE724: unable to correctly dump variable with self-referencing container\n[{E724@0}]',
         redir_exec('echo string(l)'))
      eq('\nE724: unable to correctly dump variable with self-referencing container\n[[{E724@1}]]',
         redir_exec('echo string([l])'))
    end)
  end)

  describe('used to represent dictionaries', function()
    it('dumps empty dictionary', function()
      eq('{}', eval('string({})'))
    end)

    it('dumps non-empty dictionary', function()
      eq('{\'t\'\'est\': 1}', funcs.string({['t\'est']=1}))
    end)

    it('errors when dumping recursive dictionaries', function()
      meths.set_var('d', {d=1})
      eval('extend(d, {"d": d})')
      eq('Vim(echo):E724: unable to correctly dump variable with self-referencing container',
         exc_exec('echo string(d)'))
    end)

    it('dumps recursive dictionaries despite the error', function()
      meths.set_var('d', {d=1})
      eval('extend(d, {"d": d})')
      eq('\nE724: unable to correctly dump variable with self-referencing container\n{\'d\': {E724@0}}',
         redir_exec('echo string(d)'))
      eq('\nE724: unable to correctly dump variable with self-referencing container\n{\'out\': {\'d\': {E724@1}}}',
         redir_exec('echo string({"out": d})'))
    end)
  end)
end)
