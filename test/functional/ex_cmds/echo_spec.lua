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
local matches = helpers.matches

describe(':echo :echon :echomsg :echoerr', function()
  local fn_tbl = {'String', 'StringN', 'StringMsg', 'StringErr'}
  local function assert_same_echo_dump(expected, input, use_eval)
    for _,v in pairs(fn_tbl) do
      eq(expected, use_eval and eval(v..'('..input..')') or funcs[v](input))
    end
  end
  local function assert_matches_echo_dump(expected, input, use_eval)
    for _,v in pairs(fn_tbl) do
      matches(expected, use_eval and eval(v..'('..input..')') or funcs[v](input))
    end
  end

  before_each(function()
    clear()
    source([[
      function String(s)
        return execute('echo a:s')[1:]
      endfunction
      function StringMsg(s)
        return execute('echomsg a:s')[1:]
      endfunction
      function StringN(s)
        return execute('echon a:s')
      endfunction
      function StringErr(s)
        try
          execute 'echoerr a:s'
        catch
          return substitute(v:exception, '^Vim(echoerr):', '', '')
        endtry
      endfunction
    ]])
  end)

  describe('used to represent floating-point values', function()
    it('dumps NaN values', function()
      assert_same_echo_dump("str2float('nan')", "str2float('nan')", true)
    end)

    it('dumps infinite values', function()
      assert_same_echo_dump("str2float('inf')", "str2float('inf')", true)
      assert_same_echo_dump("-str2float('inf')", "str2float('-inf')", true)
    end)

    it('dumps regular values', function()
      assert_same_echo_dump('1.5', 1.5)
      assert_same_echo_dump('1.56e-20', 1.56000e-020)
      assert_same_echo_dump('0.0', '0.0', true)
    end)

    it('dumps special v: values', function()
      eq('v:true', eval('String(v:true)'))
      eq('v:false', eval('String(v:false)'))
      eq('v:null', eval('String(v:null)'))
      eq('v:true', funcs.String(true))
      eq('v:false', funcs.String(false))
      eq('v:null', funcs.String(NIL))
      eq('true', eval('StringMsg(v:true)'))
      eq('false', eval('StringMsg(v:false)'))
      eq('null', eval('StringMsg(v:null)'))
      eq('true', funcs.StringMsg(true))
      eq('false', funcs.StringMsg(false))
      eq('null', funcs.StringMsg(NIL))
      eq('true', eval('StringErr(v:true)'))
      eq('false', eval('StringErr(v:false)'))
      eq('null', eval('StringErr(v:null)'))
      eq('true', funcs.StringErr(true))
      eq('false', funcs.StringErr(false))
      eq('null', funcs.StringErr(NIL))
    end)

    it('dumps values with at most six digits after the decimal point',
    function()
      assert_same_echo_dump('1.234568e-20', 1.23456789123456789123456789e-020)
      assert_same_echo_dump('1.234568', 1.23456789123456789123456789)
    end)

    it('dumps values with at most seven digits before the decimal point',
    function()
      assert_same_echo_dump('1234567.891235', 1234567.89123456789123456789)
      assert_same_echo_dump('1.234568e7', 12345678.9123456789123456789)
    end)

    it('dumps negative values', function()
      assert_same_echo_dump('-1.5', -1.5)
      assert_same_echo_dump('-1.56e-20', -1.56000e-020)
      assert_same_echo_dump('-1.234568e-20', -1.23456789123456789123456789e-020)
      assert_same_echo_dump('-1.234568', -1.23456789123456789123456789)
      assert_same_echo_dump('-1234567.891235', -1234567.89123456789123456789)
      assert_same_echo_dump('-1.234568e7', -12345678.9123456789123456789)
    end)
  end)

  describe('used to represent numbers', function()
    it('dumps regular values', function()
      assert_same_echo_dump('0', 0)
      assert_same_echo_dump('-1', -1)
      assert_same_echo_dump('1', 1)
    end)

    it('dumps large values', function()
      assert_same_echo_dump('2147483647', 2^31-1)
      assert_same_echo_dump('-2147483648', -2^31)
    end)
  end)

  describe('used to represent strings', function()
    it('dumps regular strings', function()
      assert_same_echo_dump('test', 'test')
    end)

    it('dumps empty strings', function()
      assert_same_echo_dump('', '')
    end)

    it("dumps strings with ' inside", function()
      assert_same_echo_dump("'''", "'''")
      assert_same_echo_dump("a'b''", "a'b''")
      assert_same_echo_dump("'b''d", "'b''d")
      assert_same_echo_dump("a'b'c'd", "a'b'c'd")
    end)

    it('dumps NULL strings', function()
      assert_same_echo_dump('', '$XXX_UNEXISTENT_VAR_XXX', true)
    end)

    it('dumps NULL lists', function()
      assert_same_echo_dump('[]', 'v:_null_list', true)
    end)

    it('dumps NULL dictionaries', function()
      assert_same_echo_dump('{}', 'v:_null_dict', true)
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
      eq("function('function')", eval('StringMsg(function("function"))'))
      eq("function('function')", eval('StringErr(function("function"))'))
    end)

    it('dumps references to user functions', function()
      eq('Test1', eval('String(function("Test1"))'))
      eq('g:Test3', eval('String(function("g:Test3"))'))
      eq("function('Test1')", eval("StringMsg(function('Test1'))"))
      eq("function('g:Test3')", eval("StringMsg(function('g:Test3'))"))
      eq("function('Test1')", eval("StringErr(function('Test1'))"))
      eq("function('g:Test3')", eval("StringErr(function('g:Test3'))"))
    end)

    it('dumps references to script functions', function()
      eq('<SNR>2_Test2', eval('String(Test2_f)'))
      eq("function('<SNR>2_Test2')", eval('StringMsg(Test2_f)'))
      eq("function('<SNR>2_Test2')", eval('StringErr(Test2_f)'))
    end)

    it('dump references to lambdas', function()
      assert_matches_echo_dump("function%('<lambda>%d+'%)", '{-> 1234}', true)
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
      assert_same_echo_dump(
        "function('<SNR>2_Test2', {'f': function('<SNR>2_Test2')})",
        '{"f": Test2_f}.f',
        true)
      assert_same_echo_dump(
        "function('<SNR>2_Test2', [1], {'f': function('<SNR>2_Test2', [1])})",
        '{"f": function(Test2_f, [1])}.f',
        true)
    end)

    it('dumps manually created partials', function()
      assert_same_echo_dump("function('Test3', [1, 2], {})",
                            "function('Test3', [1, 2], {})", true)
      assert_same_echo_dump("function('Test3', [1, 2])",
                            "function('Test3', [1, 2])", true)
      assert_same_echo_dump("function('Test3', {})",
                            "function('Test3', {})", true)
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
      assert_same_echo_dump('[]', {})
    end)

    it('dumps non-empty list', function()
      assert_same_echo_dump('[1, 2]', {1,2})
    end)

    it('dumps nested lists', function()
      assert_same_echo_dump('[[[[[]]]]]', {{{{{}}}}})
    end)

    it('dumps nested non-empty lists', function()
      assert_same_echo_dump('[1, [[3, [[5], 4]], 2]]', {1, {{3, {{5}, 4}}, 2}})
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
      assert_same_echo_dump('{}', '{}', true)
    end)

    it('dumps list with two same empty dictionaries, also in partials', function()
      command('let d = {}')
      assert_same_echo_dump('[{}, {}]', '[d, d]', true)
      eq('[function(\'tr\', {}), {}]', eval('String([function("tr", d), d])'))
      eq('[{}, function(\'tr\', {})]', eval('String([d, function("tr", d)])'))
    end)

    it('dumps non-empty dictionary', function()
      assert_same_echo_dump("{'t''est': 1}", {["t'est"]=1})
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

      eq('<80>', funcs.StringMsg(chr(0x80)))
      eq('<81>', funcs.StringMsg(chr(0x81)))
      eq('<8e>', funcs.StringMsg(chr(0x8e)))
      eq('<c2>', funcs.StringMsg(('«'):sub(1, 1)))
      eq('«', funcs.StringMsg(('«'):sub(1, 2)))
    end)
    it('displays ASCII control characters using ^X notation', function()
      eq('^C', funcs.String(ctrl('c')))
      eq('^A', funcs.String(ctrl('a')))
      eq('^F', funcs.String(ctrl('f')))
      eq('^C', funcs.StringMsg(ctrl('c')))
      eq('^A', funcs.StringMsg(ctrl('a')))
      eq('^F', funcs.StringMsg(ctrl('f')))
    end)
    it('prints CR, NL and tab as-is', function()
      eq('\n', funcs.String('\n'))
      eq('\r', funcs.String('\r'))
      eq('\t', funcs.String('\t'))
    end)
    it('prints non-printable UTF-8 in <> notation', function()
      -- SINGLE SHIFT TWO, unicode control
      eq('<8e>', funcs.String(funcs.nr2char(0x8E)))
      eq('<8e>', funcs.StringMsg(funcs.nr2char(0x8E)))
      -- Surrogate pair: U+1F0A0 PLAYING CARD BACK is represented in UTF-16 as
      -- 0xD83C 0xDCA0. This is not valid in UTF-8.
      eq('<d83c>', funcs.String(funcs.nr2char(0xD83C)))
      eq('<dca0>', funcs.String(funcs.nr2char(0xDCA0)))
      eq('<d83c><dca0>', funcs.String(funcs.nr2char(0xD83C) .. funcs.nr2char(0xDCA0)))
      eq('<d83c>', funcs.StringMsg(funcs.nr2char(0xD83C)))
      eq('<dca0>', funcs.StringMsg(funcs.nr2char(0xDCA0)))
      eq('<d83c><dca0>', funcs.StringMsg(funcs.nr2char(0xD83C) .. funcs.nr2char(0xDCA0)))
    end)
  end)
end)
