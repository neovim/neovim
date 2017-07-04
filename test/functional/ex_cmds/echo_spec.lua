local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local NIL = helpers.NIL
local eval = helpers.eval
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local source = helpers.source
local dedent = helpers.dedent
local command = helpers.command
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec

describe(':echo', function()
  before_each(function()
    clear()
    source([[
      function String(s)
        return execute('echo a:s')[1:]
      endfunction
    ]])
  end)

  describe('used to represent floating-point values', function()
    it('dumps NaN values', function()
      eq('str2float(\'nan\')', eval('String(str2float(\'nan\'))'))
    end)

    it('dumps infinite values', function()
      eq('str2float(\'inf\')', eval('String(str2float(\'inf\'))'))
      eq('-str2float(\'inf\')', eval('String(str2float(\'-inf\'))'))
    end)

    it('dumps regular values', function()
      eq('1.5', funcs.String(1.5))
      eq('1.56e-20', funcs.String(1.56000e-020))
      eq('0.0', eval('String(0.0)'))
    end)

    it('dumps special v: values', function()
      eq('v:true', eval('String(v:true)'))
      eq('v:false', eval('String(v:false)'))
      eq('v:null', eval('String(v:null)'))
      eq('v:true', funcs.String(true))
      eq('v:false', funcs.String(false))
      eq('v:null', funcs.String(NIL))
    end)

    it('dumps values with at most six digits after the decimal point',
    function()
      eq('1.234568e-20', funcs.String(1.23456789123456789123456789e-020))
      eq('1.234568', funcs.String(1.23456789123456789123456789))
    end)

    it('dumps values with at most seven digits before the decimal point',
    function()
      eq('1234567.891235', funcs.String(1234567.89123456789123456789))
      eq('1.234568e7', funcs.String(12345678.9123456789123456789))
    end)

    it('dumps negative values', function()
      eq('-1.5', funcs.String(-1.5))
      eq('-1.56e-20', funcs.String(-1.56000e-020))
      eq('-1.234568e-20', funcs.String(-1.23456789123456789123456789e-020))
      eq('-1.234568', funcs.String(-1.23456789123456789123456789))
      eq('-1234567.891235', funcs.String(-1234567.89123456789123456789))
      eq('-1.234568e7', funcs.String(-12345678.9123456789123456789))
    end)
  end)

  describe('used to represent numbers', function()
    it('dumps regular values', function()
      eq('0', funcs.String(0))
      eq('-1', funcs.String(-1))
      eq('1', funcs.String(1))
    end)

    it('dumps large values', function()
      eq('2147483647', funcs.String(2^31-1))
      eq('-2147483648', funcs.String(-2^31))
    end)
  end)

  describe('used to represent strings', function()
    it('dumps regular strings', function()
      eq('test', funcs.String('test'))
    end)

    it('dumps empty strings', function()
      eq('', funcs.String(''))
    end)

    it('dumps strings with \' inside', function()
      eq('\'\'\'', funcs.String('\'\'\''))
      eq('a\'b\'\'', funcs.String('a\'b\'\''))
      eq('\'b\'\'d', funcs.String('\'b\'\'d'))
      eq('a\'b\'c\'d', funcs.String('a\'b\'c\'d'))
    end)

    it('dumps NULL strings', function()
      eq('', eval('String($XXX_UNEXISTENT_VAR_XXX)'))
    end)

    it('dumps NULL lists', function()
      eq('[]', eval('String(v:_null_list)'))
    end)

    it('dumps NULL dictionaries', function()
      eq('{}', eval('String(v:_null_dict)'))
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
      eq('function', eval('String(function("function"))'))
    end)

    it('dumps references to user functions', function()
      eq('Test1', eval('String(function("Test1"))'))
      eq('g:Test3', eval('String(function("g:Test3"))'))
    end)

    it('dumps references to script functions', function()
      eq('<SNR>2_Test2', eval('String(Test2_f)'))
    end)

    it('dumps partials with self referencing a partial', function()
      source([[
        function TestDict() dict
        endfunction
        let d = {}
        let TestDictRef = function('TestDict', d)
        let d.tdr = TestDictRef
      ]])
      eq(dedent([[

          function('TestDict', {'tdr': function('TestDict', {...@1})})
          function('TestDict', {'tdr': function('TestDict', {...@1})})]]),
         redir_exec('echo String(d.tdr)'))
    end)

    it('dumps automatically created partials', function()
      eq('function(\'<SNR>2_Test2\', {\'f\': function(\'<SNR>2_Test2\')})',
         eval('String({"f": Test2_f}.f)'))
      eq('function(\'<SNR>2_Test2\', [1], {\'f\': function(\'<SNR>2_Test2\', [1])})',
         eval('String({"f": function(Test2_f, [1])}.f)'))
    end)

    it('dumps manually created partials', function()
      eq('function(\'Test3\', [1, 2], {})',
         eval('String(function("Test3", [1, 2], {}))'))
      eq('function(\'Test3\', {})',
         eval('String(function("Test3", {}))'))
      eq('function(\'Test3\', [1, 2])',
         eval('String(function("Test3", [1, 2]))'))
    end)

    it('does not crash or halt when dumping partials with reference cycles in self',
    function()
      meths.set_var('d', {v=true})
      eq(dedent([[

          {'p': function('<SNR>2_Test2', {...@0}), 'f': function('<SNR>2_Test2'), 'v': v:true}
          {'p': function('<SNR>2_Test2', {...@0}), 'f': function('<SNR>2_Test2'), 'v': v:true}]]),
        redir_exec('echo String(extend(extend(g:d, {"f": g:Test2_f}), {"p": g:d.f}))'))
    end)

    it('does not show errors when dumping partials referencing the same dictionary',
    function()
      command('let d = {}')
      -- Regression for “eval/typval_encode: Dump empty dictionary before
      -- checking for refcycle”, results in error.
      eq('[function(\'tr\', {}), function(\'tr\', {})]', eval('String([function("tr", d), function("tr", d)])'))
      -- Regression for “eval: Work with reference cycles in partials (self)
      -- properly”, results in crash.
      eval('extend(d, {"a": 1})')
      eq('[function(\'tr\', {\'a\': 1}), function(\'tr\', {\'a\': 1})]', eval('String([function("tr", d), function("tr", d)])'))
    end)

    it('does not crash or halt when dumping partials with reference cycles in arguments',
    function()
      meths.set_var('l', {})
      eval('add(l, l)')
      -- Regression: the below line used to crash (add returns original list and
      -- there was error in dumping partials). Tested explicitly in
      -- test/unit/api/private_helpers_spec.lua.
      eval('add(l, function("Test1", l))')
      eq(dedent([=[

          function('Test1', [[[...@2], function('Test1', [[...@2]])], function('Test1', [[[...@4], function('Test1', [[...@4]])]])])
          function('Test1', [[[...@2], function('Test1', [[...@2]])], function('Test1', [[[...@4], function('Test1', [[...@4]])]])])]=]),
        redir_exec('echo String(function("Test1", l))'))
    end)

    it('does not crash or halt when dumping partials with reference cycles in self and arguments',
    function()
      meths.set_var('d', {v=true})
      meths.set_var('l', {})
      eval('add(l, l)')
      eval('add(l, function("Test1", l))')
      eval('add(l, function("Test1", d))')
      eq(dedent([=[

          {'p': function('<SNR>2_Test2', [[[...@3], function('Test1', [[...@3]]), function('Test1', {...@0})], function('Test1', [[[...@5], function('Test1', [[...@5]]), function('Test1', {...@0})]]), function('Test1', {...@0})], {...@0}), 'f': function('<SNR>2_Test2'), 'v': v:true}
          {'p': function('<SNR>2_Test2', [[[...@3], function('Test1', [[...@3]]), function('Test1', {...@0})], function('Test1', [[[...@5], function('Test1', [[...@5]]), function('Test1', {...@0})]]), function('Test1', {...@0})], {...@0}), 'f': function('<SNR>2_Test2'), 'v': v:true}]=]),
        redir_exec('echo String(extend(extend(g:d, {"f": g:Test2_f}), {"p": function(g:d.f, l)}))'))
    end)
  end)

  describe('used to represent lists', function()
    it('dumps empty list', function()
      eq('[]', funcs.String({}))
    end)

    it('dumps nested lists', function()
      eq('[[[[[]]]]]', funcs.String({{{{{}}}}}))
    end)

    it('dumps nested non-empty lists', function()
      eq('[1, [[3, [[5], 4]], 2]]', funcs.String({1, {{3, {{5}, 4}}, 2}}))
    end)

    it('does not error when dumping recursive lists', function()
      meths.set_var('l', {})
      eval('add(l, l)')
      eq(0, exc_exec('echo String(l)'))
    end)

    it('dumps recursive lists without error', function()
      meths.set_var('l', {})
      eval('add(l, l)')
      eq('\n[[...@0]]\n[[...@0]]', redir_exec('echo String(l)'))
      eq('\n[[[...@1]]]\n[[[...@1]]]', redir_exec('echo String([l])'))
    end)
  end)

  describe('used to represent dictionaries', function()
    it('dumps empty dictionary', function()
      eq('{}', eval('String({})'))
    end)

    it('dumps list with two same empty dictionaries, also in partials', function()
      command('let d = {}')
      eq('[{}, {}]', eval('String([d, d])'))
      eq('[function(\'tr\', {}), {}]', eval('String([function("tr", d), d])'))
      eq('[{}, function(\'tr\', {})]', eval('String([d, function("tr", d)])'))
    end)

    it('dumps non-empty dictionary', function()
      eq('{\'t\'\'est\': 1}', funcs.String({['t\'est']=1}))
    end)

    it('does not error when dumping recursive dictionaries', function()
      meths.set_var('d', {d=1})
      eval('extend(d, {"d": d})')
      eq(0, exc_exec('echo String(d)'))
    end)

    it('dumps recursive dictionaries without the error', function()
      meths.set_var('d', {d=1})
      eval('extend(d, {"d": d})')
      eq('\n{\'d\': {...@0}}\n{\'d\': {...@0}}',
         redir_exec('echo String(d)'))
      eq('\n{\'out\': {\'d\': {...@1}}}\n{\'out\': {\'d\': {...@1}}}',
         redir_exec('echo String({"out": d})'))
    end)
  end)

  describe('used to represent special values', function()
    local function chr(n)
      return ('%c'):format(n)
    end
    local function ctrl(c)
      return ('%c'):format(c:upper():byte() - 0x40)
    end
    it('displays hex as hex', function()
      -- Regression: due to missing (uint8_t) cast \x80 was represented as
      -- ~@<80>.
      eq('<80>', funcs.String(chr(0x80)))
      eq('<81>', funcs.String(chr(0x81)))
      eq('<8e>', funcs.String(chr(0x8e)))
      eq('<c2>', funcs.String(('«'):sub(1, 1)))
      eq('«', funcs.String(('«'):sub(1, 2)))
    end)
    it('displays ASCII control characters using ^X notation', function()
      eq('^C', funcs.String(ctrl('c')))
      eq('^A', funcs.String(ctrl('a')))
      eq('^F', funcs.String(ctrl('f')))
    end)
    it('prints CR, NL and tab as-is', function()
      eq('\n', funcs.String('\n'))
      eq('\r', funcs.String('\r'))
      eq('\t', funcs.String('\t'))
    end)
    it('prints non-printable UTF-8 in <> notation', function()
      -- SINGLE SHIFT TWO, unicode control
      eq('<8e>', funcs.String(funcs.nr2char(0x8E)))
      -- Surrogate pair: U+1F0A0 PLAYING CARD BACK is represented in UTF-16 as
      -- 0xD83C 0xDCA0. This is not valid in UTF-8.
      eq('<d83c>', funcs.String(funcs.nr2char(0xD83C)))
      eq('<dca0>', funcs.String(funcs.nr2char(0xDCA0)))
      eq('<d83c><dca0>', funcs.String(funcs.nr2char(0xD83C) .. funcs.nr2char(0xDCA0)))
    end)
  end)
end)
