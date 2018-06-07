local helpers = require('test.functional.helpers')(after_each)
local nvim, call = helpers.meths, helpers.call
local clear, eq = helpers.clear, helpers.eq
local source, command = helpers.source, helpers.command
local exc_exec = helpers.exc_exec

local function expected_errors(errors)
  eq(errors, nvim.get_vvar('errors'))
end

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('assert function:', function()

  before_each(function()
    clear()
  end)

  -- assert_equal({expected}, {actual}, [, {msg}])
  describe('assert_equal', function()
    it('should not change v:errors when expected is equal to actual', function()
      source([[
        let s = 'foo'
        call assert_equal('foo', s)
        let n = 4
        call assert_equal(4, n)
        let l = [1, 2, 3]
        call assert_equal([1, 2, 3], l)
        fu Func()
        endfu
        let F1 = function('Func')
        let F2 = function('Func')
        call assert_equal(F1, F2)
      ]])
      expected_empty()
    end)

    it('should not change v:errors when expected is equal to actual', function()
      call('assert_equal', '', '')
      call('assert_equal', 'string', 'string')
      expected_empty()
    end)

    it('should change v:errors when expected is not equal to actual', function()
      call('assert_equal', 0, {0})
      expected_errors({'Expected 0 but got [0]'})
    end)

    it('should change v:errors when expected is not equal to actual', function()
      call('assert_equal', 0, "0")
      expected_errors({"Expected 0 but got '0'"})
    end)

    it('should change v:errors when expected is not equal to actual', function()
      -- Lua does not tell integer from float.
      command('call assert_equal(1, 1.0)')
      expected_errors({'Expected 1 but got 1.0'})
    end)

    it('should change v:errors when expected is not equal to actual', function()
      call('assert_equal', 'true', 'false')
      expected_errors({"Expected 'true' but got 'false'"})
    end)

    it('should change v:errors when expected is not equal to actual', function()
      source([[
      function CheckAssert()
        let s:v = {}
        let s:x = {"a": s:v}
        let s:v["b"] = s:x
        let s:w = {"c": s:x, "d": ''}
        call assert_equal(s:w, '')
      endfunction
      ]])
      eq('Vim(call):E724: unable to correctly dump variable with self-referencing container',
         exc_exec('call CheckAssert()'))
    end)

    it('can specify a message and get a message about what failed', function()
      call('assert_equal', 'foo', 'bar', 'testing')
      expected_errors({"testing: Expected 'foo' but got 'bar'"})
    end)
  end)

  -- assert_notequal({expected}, {actual}[, {msg}])
  describe('assert_notequal', function()
    it('should not change v:errors when expected differs from actual', function()
      call('assert_notequal', 'foo', 4)
      call('assert_notequal', {1, 2, 3}, 'foo')
      expected_empty()
    end)

    it('should change v:errors when expected is equal to actual', function()
      call('assert_notequal', 'foo', 'foo')
      expected_errors({"Expected not equal to 'foo'"})
    end)
  end)

  -- assert_false({actual}, [, {msg}])
  describe('assert_false', function()
    it('should not change v:errors when actual is false', function()
      call('assert_false', 0)
      call('assert_false', false)
      expected_empty()
    end)

    it('should change v:errors when actual is not false', function()
      call('assert_false', 1)
      expected_errors({'Expected False but got 1'})
    end)

    it('should change v:errors when actual is not false', function()
      call('assert_false', {})
      expected_errors({'Expected False but got []'})
    end)
  end)

  -- assert_true({actual}, [, {msg}])
  describe('assert_true', function()
    it('should not change v:errors when actual is true', function()
      call('assert_true', 1)
      call('assert_true', -1) -- In Vim script, non-zero Numbers are TRUE.
      call('assert_true', true)
      expected_empty()
    end)

    it('should change v:errors when actual is not true', function()
      call('assert_true', 1.5)
      expected_errors({'Expected True but got 1.5'})
    end)
  end)

  describe('v:errors', function()
    it('should be initialized at startup', function()
      expected_empty()
    end)

    it('should have function names and relative line numbers', function()
      source([[
        fu Func_one()
          call assert_equal([0], {'0' : 0})
          call assert_false('False')
          call assert_true("True")
        endfu
        fu Func_two()
          " for shifting a line number
          call assert_true('line two')
        endfu
      ]])
      call('Func_one')
      call('Func_two')
      expected_errors({
        "function Func_one line 1: Expected [0] but got {'0': 0}",
        "function Func_one line 2: Expected False but got 'False'",
        "function Func_one line 3: Expected True but got 'True'",
        "function Func_two line 2: Expected True but got 'line two'",
      })
    end)

    it('should have file names and passed messages', function()
      local tmpname_one = source([[
        call assert_equal(1, 100, 'equal assertion failed')
        call assert_false('true', 'true  assertion failed')
        call assert_true('false', 'false assertion failed')
      ]])
      local tmpname_two = source([[
        call assert_true('', 'file two')
      ]])
      expected_errors({
        tmpname_one .. " line 1: equal assertion failed: Expected 1 but got 100",
        tmpname_one .. " line 2: true  assertion failed: Expected False but got 'true'",
        tmpname_one .. " line 3: false assertion failed: Expected True but got 'false'",
        tmpname_two .. " line 1: file two: Expected True but got ''",
      })
    end)

    it('is reset to a list by assert functions', function()
      source([[
        let save_verrors = v:errors
        let v:['errors'] = {'foo': 3}
        call assert_equal('yes', 'no')
        let verrors = v:errors
        let v:errors = save_verrors
        call assert_equal(type([]), type(verrors))
      ]])
      expected_empty()
    end)
  end)

  -- assert_match({pat}, {text}[, {msg}])
  describe('assert_match', function()
    it('should not change v:errors when pat matches text', function()
      call('assert_match', '^f.*b.*r$', 'foobar')
      expected_empty()
    end)

    it('should change v:errors when pat does not match text', function()
      call('assert_match', 'bar.*foo', 'foobar')
      expected_errors({"Pattern 'bar.*foo' does not match 'foobar'"})
    end)

    it('should set v:errors to msg when given and match fails', function()
      call('assert_match', 'bar.*foo', 'foobar', 'wrong')
      expected_errors({"wrong: Pattern 'bar.*foo' does not match 'foobar'"})
    end)
  end)

  -- assert_notmatch({pat}, {text}[, {msg}])
  describe('assert_notmatch', function()
    it('should not change v:errors when pat does not match text', function()
      call('assert_notmatch', 'foo', 'bar')
      call('assert_notmatch', '^foobar$', 'foobars')
      expected_empty()
    end)

    it('should change v:errors when pat matches text', function()
      call('assert_notmatch', 'foo', 'foobar')
      expected_errors({"Pattern 'foo' does match 'foobar'"})
    end)
  end)

  -- assert_fails({cmd}, [, {error}])
  describe('assert_fails', function()
    it('should change v:errors when error does not match v:errmsg', function()
      command([[call assert_fails('xxx', {})]])
      command([[call assert_match("Expected {} but got 'E731:", v:errors[0])]])
      expected_errors({"Expected {} but got 'E731: using Dictionary as a String'"})
    end)

    it('should not change v:errors when cmd errors', function()
      call('assert_fails', 'NonexistentCmd')
      expected_empty()
    end)

    it('should change v:errors when cmd succeeds', function()
      call('assert_fails', 'call empty("")')
      expected_errors({'command did not fail: call empty("")'})
    end)
  end)

  -- assert_inrange({lower}, {upper}, {actual}[, {msg}])
  describe('assert_inrange()', function()
    it('should not change v:errors when actual is in range', function()
      call('assert_inrange', 7, 7, 7)
      call('assert_inrange', 5, 7, 5)
      call('assert_inrange', 5, 7, 6)
      call('assert_inrange', 5, 7, 7)
      expected_empty()
    end)

    it('should change v:errors when actual is not in range', function()
      call('assert_inrange', 5, 7, 4)
      call('assert_inrange', 5, 7, 8)
      expected_errors({
        "Expected range 5 - 7, but got 4",
        "Expected range 5 - 7, but got 8",
      })
    end)

    it('assert_inrange(1, 1) returns E119', function()
      eq('Vim(call):E119: Not enough arguments for function: assert_inrange',
         exc_exec("call assert_inrange(1, 1)"))
    end)
  end)

  -- assert_report({msg})
  describe('assert_report()', function()
    it('should add a message to v:errors', function()
      command("call assert_report('something is wrong')")
      command("call assert_match('something is wrong', v:errors[0])")
      command('call remove(v:errors, 0)')
      expected_empty()
    end)
  end)

  -- assert_exception({cmd}, [, {error}])
  describe('assert_exception()', function()
    it('should assert thrown exceptions properly', function()
      source([[
        try
          nocommand
        catch
          call assert_exception('E492')
        endtry
      ]])
      expected_empty()
    end)

    it('should work properly when nested', function()
      source([[
        try
          nocommand
        catch
          try
            " illegal argument, get NULL for error
            call assert_exception([])
          catch
            call assert_exception('E730')
          endtry
        endtry
      ]])
      expected_empty()
    end)
  end)
end)
