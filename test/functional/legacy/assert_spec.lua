local helpers = require('test.functional.helpers')
local nvim, call = helpers.meths, helpers.call
local clear, eq = helpers.clear, helpers.eq
local source, execute = helpers.source, helpers.execute

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
      execute('call assert_equal(1, 1.0)')
      expected_errors({'Expected 1 but got 1.0'})
    end)

    it('should change v:errors when expected is not equal to actual', function()
      call('assert_equal', 'true', 'false')
      expected_errors({"Expected 'true' but got 'false'"})
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
        tmpname_one .. " line 1: 'equal assertion failed'",
        tmpname_one .. " line 2: 'true  assertion failed'",
        tmpname_one .. " line 3: 'false assertion failed'",
        tmpname_two .. " line 1: 'file two'",
      })
    end)
  end)
end)
