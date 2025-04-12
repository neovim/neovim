local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api, call = n.api, n.call
local clear, eq = n.clear, t.eq
local source, command = n.source, n.command
local exc_exec = n.exc_exec
local eval = n.eval

local function expected_errors(errors)
  eq(errors, api.nvim_get_vvar('errors'))
end

local function expected_empty()
  eq({}, api.nvim_get_vvar('errors'))
end

describe('assert function:', function()
  before_each(function()
    clear()
  end)

  -- assert_equal({expected}, {actual}, [, {msg}])
  describe('assert_equal', function()
    it('should not change v:errors when expected is equal to actual', function()
      source([[
        fu Func()
        endfu
        let F1 = function('Func')
        let F2 = function('Func')
        call assert_equal(F1, F2)
      ]])
      expected_empty()
    end)

    it('should not change v:errors when expected is equal to actual', function()
      eq(0, call('assert_equal', '', ''))
      eq(0, call('assert_equal', 'string', 'string'))
      expected_empty()
    end)

    it('should change v:errors when expected is not equal to actual', function()
      eq(1, call('assert_equal', 0, { 0 }))
      expected_errors({ 'Expected 0 but got [0]' })
    end)

    it('should change v:errors when expected is not equal to actual', function()
      eq(1, call('assert_equal', 0, '0'))
      expected_errors({ "Expected 0 but got '0'" })
    end)

    it('should change v:errors when expected is not equal to actual', function()
      -- Lua does not tell integer from float.
      command('call assert_equal(1, 1.0)')
      expected_errors({ 'Expected 1 but got 1.0' })
    end)

    it('should change v:errors when expected is not equal to actual', function()
      call('assert_equal', 'true', 'false')
      expected_errors({ "Expected 'true' but got 'false'" })
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
      eq(
        'Vim(call):E724: unable to correctly dump variable with self-referencing container',
        exc_exec('call CheckAssert()')
      )
    end)
  end)

  -- assert_false({actual}, [, {msg}])
  describe('assert_false', function()
    it('should not change v:errors when actual is false', function()
      eq(0, call('assert_false', 0))
      eq(0, call('assert_false', false))
      expected_empty()
    end)

    it('should change v:errors when actual is not false', function()
      eq(1, call('assert_false', 1))
      expected_errors({ 'Expected False but got 1' })
    end)

    it('should change v:errors when actual is not false', function()
      call('assert_false', {})
      expected_errors({ 'Expected False but got []' })
    end)
  end)

  -- assert_true({actual}, [, {msg}])
  describe('assert_true', function()
    it('should not change v:errors when actual is true', function()
      eq(0, call('assert_true', 1))
      eq(0, call('assert_true', -1)) -- In Vim script, non-zero Numbers are TRUE.
      eq(0, call('assert_true', true))
      expected_empty()
    end)

    it('should change v:errors when actual is not true', function()
      eq(1, call('assert_true', 1.5))
      expected_errors({ 'Expected True but got 1.5' })
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
      source([[
        call assert_equal(1, 100, 'equal assertion failed')
        call assert_false('true', 'true  assertion failed')
        call assert_true('false', 'false assertion failed')
      ]])
      source([[
        call assert_true('', 'file two')
      ]])
      expected_errors({
        'nvim_exec2() line 1: equal assertion failed: Expected 1 but got 100',
        "nvim_exec2() line 2: true  assertion failed: Expected False but got 'true'",
        "nvim_exec2() line 3: false assertion failed: Expected True but got 'false'",
        "nvim_exec2() line 1: file two: Expected True but got ''",
      })
    end)
  end)

  -- assert_fails({cmd}, [, {error}])
  describe('assert_fails', function()
    it('should not change v:errors when cmd errors', function()
      eq(0, eval([[assert_fails('NonexistentCmd')]]))
      expected_empty()
    end)

    it('should change v:errors when cmd succeeds', function()
      eq(1, eval([[assert_fails('call empty("")', '')]]))
      expected_errors({ 'command did not fail: call empty("")' })
    end)
  end)
end)
