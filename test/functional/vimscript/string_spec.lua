local t = require('test.functional.testutil')()
local clear = t.clear
local eq = t.eq
local command = t.command
local api = t.api
local eval = t.eval
local exc_exec = t.exc_exec
local pcall_err = t.pcall_err
local fn = t.fn
local NIL = vim.NIL
local source = t.source

describe('string() function', function()
  before_each(clear)

  describe('used to represent floating-point values', function()
    it('dumps NaN values', function()
      eq("str2float('nan')", eval("string(str2float('nan'))"))
    end)

    it('dumps infinite values', function()
      eq("str2float('inf')", eval("string(str2float('inf'))"))
      eq("-str2float('inf')", eval("string(str2float('-inf'))"))
    end)

    it('dumps regular values', function()
      eq('1.5', fn.string(1.5))
      eq('1.56e-20', fn.string(1.56000e-020))
      eq('0.0', eval('string(0.0)'))
    end)

    it('dumps special v: values', function()
      eq('v:true', eval('string(v:true)'))
      eq('v:false', eval('string(v:false)'))
      eq('v:null', eval('string(v:null)'))
      eq('v:true', fn.string(true))
      eq('v:false', fn.string(false))
      eq('v:null', fn.string(NIL))
    end)

    it('dumps values with at most six digits after the decimal point', function()
      eq('1.234568e-20', fn.string(1.23456789123456789123456789e-020))
      eq('1.234568', fn.string(1.23456789123456789123456789))
    end)

    it('dumps values with at most seven digits before the decimal point', function()
      eq('1234567.891235', fn.string(1234567.89123456789123456789))
      eq('1.234568e7', fn.string(12345678.9123456789123456789))
    end)

    it('dumps negative values', function()
      eq('-1.5', fn.string(-1.5))
      eq('-1.56e-20', fn.string(-1.56000e-020))
      eq('-1.234568e-20', fn.string(-1.23456789123456789123456789e-020))
      eq('-1.234568', fn.string(-1.23456789123456789123456789))
      eq('-1234567.891235', fn.string(-1234567.89123456789123456789))
      eq('-1.234568e7', fn.string(-12345678.9123456789123456789))
    end)
  end)

  describe('used to represent numbers', function()
    it('dumps regular values', function()
      eq('0', fn.string(0))
      eq('-1', fn.string(-1))
      eq('1', fn.string(1))
    end)

    it('dumps large values', function()
      eq('2147483647', fn.string(2 ^ 31 - 1))
      eq('-2147483648', fn.string(-2 ^ 31))
    end)
  end)

  describe('used to represent strings', function()
    it('dumps regular strings', function()
      eq("'test'", fn.string('test'))
    end)

    it('dumps empty strings', function()
      eq("''", fn.string(''))
    end)

    it("dumps strings with ' inside", function()
      eq("''''''''", fn.string("'''"))
      eq("'a''b'''''", fn.string("a'b''"))
      eq("'''b''''d'", fn.string("'b''d"))
      eq("'a''b''c''d'", fn.string("a'b'c'd"))
    end)

    it('dumps NULL strings', function()
      eq("''", eval('string($XXX_UNEXISTENT_VAR_XXX)'))
    end)

    it('dumps NULL lists', function()
      eq('[]', eval('string(v:_null_list)'))
    end)

    it('dumps NULL dictionaries', function()
      eq('{}', eval('string(v:_null_dict)'))
    end)
  end)

  describe('used to represent funcrefs', function()
    before_each(function()
      source([[
        function Test1()
        endfunction

        function s:Test2() dict
        endfunction

        function g:Test3() dict
        endfunction

        let g:Test2_f = function('s:Test2')
      ]])
    end)

    it('dumps references to built-in functions', function()
      eq("function('function')", eval('string(function("function"))'))
    end)

    it('dumps references to user functions', function()
      eq("function('Test1')", eval('string(function("Test1"))'))
      eq("function('g:Test3')", eval('string(function("g:Test3"))'))
    end)

    it('dumps references to script functions', function()
      eq("function('<SNR>1_Test2')", eval('string(Test2_f)'))
    end)

    it('dumps partials with self referencing a partial', function()
      source([[
        function TestDict() dict
        endfunction
        let d = {}
        let TestDictRef = function('TestDict', d)
        let d.tdr = TestDictRef
      ]])
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        pcall_err(command, 'echo string(d.tdr)')
      )
    end)

    it('dumps automatically created partials', function()
      eq(
        "function('<SNR>1_Test2', {'f': function('<SNR>1_Test2')})",
        eval('string({"f": Test2_f}.f)')
      )
      eq(
        "function('<SNR>1_Test2', [1], {'f': function('<SNR>1_Test2', [1])})",
        eval('string({"f": function(Test2_f, [1])}.f)')
      )
    end)

    it('dumps manually created partials', function()
      eq("function('Test3', [1, 2], {})", eval('string(function("Test3", [1, 2], {}))'))
      eq("function('Test3', {})", eval('string(function("Test3", {}))'))
      eq("function('Test3', [1, 2])", eval('string(function("Test3", [1, 2]))'))
    end)

    it('does not crash or halt when dumping partials with reference cycles in self', function()
      api.nvim_set_var('d', { v = true })
      eq(
        [[Vim(echo):E724: unable to correctly dump variable with self-referencing container]],
        pcall_err(command, 'echo string(extend(extend(g:d, {"f": g:Test2_f}), {"p": g:d.f}))')
      )
    end)

    it('does not show errors when dumping partials referencing the same dictionary', function()
      command('let d = {}')
      -- Regression for “eval/typval_encode: Dump empty dictionary before
      -- checking for refcycle”, results in error.
      eq(
        "[function('tr', {}), function('tr', {})]",
        eval('string([function("tr", d), function("tr", d)])')
      )
      -- Regression for “eval: Work with reference cycles in partials (self)
      -- properly”, results in crash.
      eval('extend(d, {"a": 1})')
      eq(
        "[function('tr', {'a': 1}), function('tr', {'a': 1})]",
        eval('string([function("tr", d), function("tr", d)])')
      )
    end)

    it('does not crash or halt when dumping partials with reference cycles in arguments', function()
      api.nvim_set_var('l', {})
      eval('add(l, l)')
      -- Regression: the below line used to crash (add returns original list and
      -- there was error in dumping partials). Tested explicitly in
      -- test/unit/api/private_t_spec.lua.
      eval('add(l, function("Test1", l))')
      eq(
        [=[Vim(echo):E724: unable to correctly dump variable with self-referencing container]=],
        pcall_err(command, 'echo string(function("Test1", l))')
      )
    end)

    it(
      'does not crash or halt when dumping partials with reference cycles in self and arguments',
      function()
        api.nvim_set_var('d', { v = true })
        api.nvim_set_var('l', {})
        eval('add(l, l)')
        eval('add(l, function("Test1", l))')
        eval('add(l, function("Test1", d))')
        eq(
          [=[Vim(echo):E724: unable to correctly dump variable with self-referencing container]=],
          pcall_err(
            command,
            'echo string(extend(extend(g:d, {"f": g:Test2_f}), {"p": function(g:d.f, l)}))'
          )
        )
      end
    )
  end)

  describe('used to represent lists', function()
    it('dumps empty list', function()
      eq('[]', fn.string({}))
    end)

    it('dumps nested lists', function()
      eq('[[[[[]]]]]', fn.string({ { { { {} } } } }))
    end)

    it('dumps nested non-empty lists', function()
      eq('[1, [[3, [[5], 4]], 2]]', fn.string({ 1, { { 3, { { 5 }, 4 } }, 2 } }))
    end)

    it('errors when dumping recursive lists', function()
      api.nvim_set_var('l', {})
      eval('add(l, l)')
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        exc_exec('echo string(l)')
      )
    end)

    it('dumps recursive lists despite the error', function()
      api.nvim_set_var('l', {})
      eval('add(l, l)')
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        pcall_err(command, 'echo string(l)')
      )
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        pcall_err(command, 'echo string([l])')
      )
    end)
  end)

  describe('used to represent dictionaries', function()
    it('dumps empty dictionary', function()
      eq('{}', eval('string({})'))
    end)

    it('dumps list with two same empty dictionaries, also in partials', function()
      command('let d = {}')
      eq('[{}, {}]', eval('string([d, d])'))
      eq("[function('tr', {}), {}]", eval('string([function("tr", d), d])'))
      eq("[{}, function('tr', {})]", eval('string([d, function("tr", d)])'))
    end)

    it('dumps non-empty dictionary', function()
      eq("{'t''est': 1}", fn.string({ ["t'est"] = 1 }))
    end)

    it('errors when dumping recursive dictionaries', function()
      api.nvim_set_var('d', { d = 1 })
      eval('extend(d, {"d": d})')
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        exc_exec('echo string(d)')
      )
    end)

    it('dumps recursive dictionaries despite the error', function()
      api.nvim_set_var('d', { d = 1 })
      eval('extend(d, {"d": d})')
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        pcall_err(command, 'echo string(d)')
      )
      eq(
        'Vim(echo):E724: unable to correctly dump variable with self-referencing container',
        pcall_err(command, 'echo string({"out": d})')
      )
    end)
  end)
end)
