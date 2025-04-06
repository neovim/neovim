local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local ffi = t.ffi
local eq = t.eq
local neq = t.neq

local prof = cimport('./src/nvim/profile.h')

local function split(inputstr, sep)
  if sep == nil then
    sep = '%s'
  end

  local q, i = {}, 1
  for str in string.gmatch(inputstr, '([^' .. sep .. ']+)') do
    q[i] = str
    i = i + 1
  end

  return q
end

local function trim(s)
  local from = s:match '^%s*()'
  return from > #s and '' or s:match('.*%S', from)
end

local function starts(str, start)
  return string.sub(str, 1, string.len(start)) == start
end

local function cmp_assert(v1, v2, op, opstr)
  local res = op(v1, v2)
  if res == false then
    print(string.format('expected: %f %s %f', v1, opstr, v2))
  end
  assert.is_true(res)
end

local function lt(a, b) -- luacheck: ignore
  cmp_assert(a, b, function(x, y)
    return x < y
  end, '<')
end

local function lte(a, b) -- luacheck: ignore
  cmp_assert(a, b, function(x, y)
    return x <= y
  end, '<=')
end

local function gt(a, b) -- luacheck: ignore
  cmp_assert(a, b, function(x, y)
    return x > y
  end, '>')
end

local function gte(a, b)
  cmp_assert(a, b, function(x, y)
    return x >= y
  end, '>=')
end

-- missing functions:
--  profile_self
--  profile_get_wait
--  profile_set_wait
--  profile_sub_wait
describe('profiling related functions', function()
  local function profile_start()
    return prof.profile_start()
  end
  local function profile_end(q)
    return prof.profile_end(q)
  end
  local function profile_zero()
    return prof.profile_zero()
  end
  local function profile_setlimit(ms)
    return prof.profile_setlimit(ms)
  end
  local function profile_passed_limit(q)
    return prof.profile_passed_limit(q)
  end
  local function profile_add(t1, t2)
    return prof.profile_add(t1, t2)
  end
  local function profile_sub(t1, t2)
    return prof.profile_sub(t1, t2)
  end
  local function profile_divide(q, cnt)
    return prof.profile_divide(q, cnt)
  end
  local function profile_cmp(t1, t2)
    return prof.profile_cmp(t1, t2)
  end
  local function profile_equal(t1, t2)
    return prof.profile_equal(t1, t2)
  end
  local function profile_msg(q)
    return ffi.string(prof.profile_msg(q))
  end

  local function toseconds(q) -- luacheck: ignore
    local str = trim(profile_msg(q))
    local spl = split(str, '.')
    local s, us = spl[1], spl[2]
    return tonumber(s) + tonumber(us) / 1000000
  end

  describe('profile_equal', function()
    itp('times are equal to themselves', function()
      local start = profile_start()
      assert.is_true(profile_equal(start, start))

      local e = profile_end(start)
      assert.is_true(profile_equal(e, e))
    end)

    itp('times are unequal to others', function()
      assert.is_false(profile_equal(profile_start(), profile_start()))
    end)
  end)

  -- this is quite difficult to test, as it would rely on other functions in
  -- the profiling package. Those functions in turn will probably be tested
  -- using profile_cmp... circular reasoning.
  describe('profile_cmp', function()
    itp('can compare subsequent starts', function()
      local s1, s2 = profile_start(), profile_start()
      assert.is_true(profile_cmp(s1, s2) > 0)
      assert.is_true(profile_cmp(s2, s1) < 0)
    end)

    itp('can compare the zero element', function()
      assert.is_true(profile_cmp(profile_zero(), profile_zero()) == 0)
    end)

    itp('correctly orders divisions', function()
      local start = profile_start()
      assert.is_true(profile_cmp(start, profile_divide(start, 10)) <= 0)
    end)
  end)

  describe('profile_divide', function()
    itp('actually performs division', function()
      -- note: the routine actually performs floating-point division to get
      -- better rounding behaviour, we have to take that into account when
      -- checking. (check range, not exact number).
      local divisor = 10

      local start = profile_start()
      local divided = profile_divide(start, divisor)

      local res = divided
      for _ = 1, divisor - 1 do
        res = profile_add(res, divided)
      end

      -- res should be in the range [start - divisor, start + divisor]
      local start_min, start_max = profile_sub(start, divisor), profile_add(start, divisor)
      assert.is_true(profile_cmp(start_min, res) >= 0)
      assert.is_true(profile_cmp(start_max, res) <= 0)
    end)
  end)

  describe('profile_zero', function()
    itp('returns the same value on each call', function()
      eq(0, profile_zero())
      assert.is_true(profile_equal(profile_zero(), profile_zero()))
    end)
  end)

  describe('profile_start', function()
    itp('increases', function()
      local last = profile_start()
      for _ = 1, 100 do
        local curr = profile_start()
        gte(curr, last)
        last = curr
      end
    end)
  end)

  describe('profile_end', function()
    itp('the elapsed time cannot be zero', function()
      neq(profile_zero(), profile_end(profile_start()))
    end)

    itp('outer elapsed >= inner elapsed', function()
      for _ = 1, 100 do
        local start_outer = profile_start()
        local start_inner = profile_start()
        local elapsed_inner = profile_end(start_inner)
        local elapsed_outer = profile_end(start_outer)

        gte(elapsed_outer, elapsed_inner)
      end
    end)
  end)

  describe('profile_setlimit', function()
    itp('sets no limit when 0 is passed', function()
      eq(true, profile_equal(profile_setlimit(0), profile_zero()))
    end)

    itp('sets a limit in the future otherwise', function()
      local future = profile_setlimit(1000)
      local now = profile_start()
      assert.is_true(profile_cmp(future, now) < 0)
    end)
  end)

  describe('profile_passed_limit', function()
    itp('start is in the past', function()
      local start = profile_start()
      eq(true, profile_passed_limit(start))
    end)

    itp('start + start is in the future', function()
      local start = profile_start()
      local future = profile_add(start, start)
      eq(false, profile_passed_limit(future))
    end)
  end)

  describe('profile_msg', function()
    itp('prints the zero time as 0.00000', function()
      local str = trim(profile_msg(profile_zero()))
      eq('0.000000', str)
    end)

    itp('prints the time passed, in seconds.microsends', function()
      local start = profile_start()
      local endt = profile_end(start)
      local str = trim(profile_msg(endt))
      local spl = split(str, '.')

      -- string has two parts (before dot and after dot)
      eq(2, #spl)

      local s, us = spl[1], spl[2]

      -- zero seconds have passed (if this is not true, either LuaJIT is too
      -- slow or the profiling functions are too slow and need to be fixed)
      eq('0', s)

      -- more or less the same goes for the microsecond part, if it doesn't
      -- start with 0, it's too slow.
      assert.is_true(starts(us, '0'))
    end)
  end)

  describe('profile_add', function()
    itp('adds profiling times', function()
      local start = profile_start()
      assert.equals(start, profile_add(profile_zero(), start))
    end)
  end)

  describe('profile_sub', function()
    itp('subtracts profiling times', function()
      -- subtracting zero does nothing
      local start = profile_start()
      assert.equals(start, profile_sub(start, profile_zero()))

      local start1, start2, start3 = profile_start(), profile_start(), profile_start()
      local cmp = profile_cmp(profile_sub(start2, start1), profile_sub(start3, start1))
      -- t2 >= t1 => profile_cmp(t1, t2) >= 0
      assert.is_true(cmp >= 0)

      cmp = profile_cmp(profile_sub(start3, start1), profile_sub(start2, start1))
      -- t2 <= t1 => profile_cmp(t1, t2) <= 0
      assert.is_true(cmp <= 0)
    end)
  end)
end)
