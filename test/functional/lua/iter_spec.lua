local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local matches = helpers.matches
local pcall_err = helpers.pcall_err

describe('vim.iter', function()
  it('new() on iterable class instance', function()
    local rb = vim.ringbuf(3)
    rb:push("a")
    rb:push("b")

    local it = vim.iter(rb)
    eq({"a", "b"}, it:totable())
  end)

  it('filter()', function()
    local function odd(v)
      return v % 2 ~= 0
    end

    local t = { 1, 2, 3, 4, 5 }
    eq({ 1, 3, 5 }, vim.iter(t):filter(odd):totable())
    eq({ 2, 4 }, vim.iter(t):filter(function(v) return not odd(v) end):totable())
    eq({}, vim.iter(t):filter(function(v) return v > 5 end):totable())

    do
      local it = vim.iter(ipairs(t))
      it:filter(function(i, v) return i > 1 and v < 5 end)
      it:map(function(_, v) return v * 2 end)
      eq({ 4, 6, 8 }, it:totable())
    end

    local it = vim.iter(string.gmatch('the quick brown fox', '%w+'))
    eq({'the', 'fox'}, it:filter(function(s) return #s <= 3 end):totable())
  end)

  it('map()', function()
    local t = { 1, 2, 3, 4, 5 }
    eq(
      { 2, 4, 6, 8, 10 },
      vim
      .iter(t)
      :map(function(v)
        return 2 * v
      end)
      :totable()
    )

    local it = vim.gsplit(
      [[
      Line 1
      Line 2
      Line 3
      Line 4
    ]],
      '\n'
    )

    eq(
      { 'Lion 2', 'Lion 4' },
      vim
      .iter(it)
      :map(function(s)
        local lnum = s:match('(%d+)')
        if lnum and tonumber(lnum) % 2 == 0 then
          return vim.trim(s:gsub('Line', 'Lion'))
        end
      end)
      :totable()
    )
  end)

  it('for loops', function()
    local t = {1, 2, 3, 4, 5}
    local acc = 0
    for v in vim.iter(t):map(function(v) return v * 3 end) do
      acc = acc + v
    end
    eq(45, acc)
  end)

  it('totable()', function()
    do
      local it = vim.iter({1, 2, 3}):map(function(v) return v, v*v end)
      eq({{1, 1}, {2, 4}, {3, 9}}, it:totable())
    end

    do
      local it = vim.iter(string.gmatch('1,4,lol,17,blah,2,9,3', '%d+')):map(tonumber)
      eq({1, 4, 17, 2, 9, 3}, it:totable())
    end
  end)

  it('next()', function()
    local it = vim.iter({1, 2, 3}):map(function(v) return 2 * v end)
    eq(2, it:next())
    eq(4, it:next())
    eq(6, it:next())
    eq(nil, it:next())
  end)

  it('rev()', function()
    eq({3, 2, 1}, vim.iter({1, 2, 3}):rev():totable())

    local it = vim.iter(string.gmatch("abc", "%w"))
    matches('rev%(%) requires a list%-like table', pcall_err(it.rev, it))
  end)

  it('skip()', function()
    do
      local t = {4, 3, 2, 1}
      eq(t, vim.iter(t):skip(0):totable())
      eq({3, 2, 1}, vim.iter(t):skip(1):totable())
      eq({2, 1}, vim.iter(t):skip(2):totable())
      eq({1}, vim.iter(t):skip(#t - 1):totable())
      eq({}, vim.iter(t):skip(#t):totable())
      eq({}, vim.iter(t):skip(#t + 1):totable())
    end

    do
      local function skip(n)
        return vim.iter(vim.gsplit('a|b|c|d', '|')):skip(n):totable()
      end
      eq({'a', 'b', 'c', 'd'}, skip(0))
      eq({'b', 'c', 'd'}, skip(1))
      eq({'c', 'd'}, skip(2))
      eq({'d'}, skip(3))
      eq({}, skip(4))
      eq({}, skip(5))
    end
  end)

  it('skipback()', function()
    do
      local t = {4, 3, 2, 1}
      eq(t, vim.iter(t):skipback(0):totable())
      eq({4, 3, 2}, vim.iter(t):skipback(1):totable())
      eq({4, 3}, vim.iter(t):skipback(2):totable())
      eq({4}, vim.iter(t):skipback(#t - 1):totable())
      eq({}, vim.iter(t):skipback(#t):totable())
      eq({}, vim.iter(t):skipback(#t + 1):totable())
    end

    local it = vim.iter(vim.gsplit('a|b|c|d', '|'))
    matches('skipback%(%) requires a list%-like table', pcall_err(it.skipback, it, 0))
  end)

  it('slice()', function()
    local t = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    eq({3, 4, 5, 6, 7}, vim.iter(t):slice(3, 7):totable())
    eq({}, vim.iter(t):slice(6, 5):totable())
    eq({}, vim.iter(t):slice(0, 0):totable())
    eq({1}, vim.iter(t):slice(1, 1):totable())
    eq({1, 2}, vim.iter(t):slice(1, 2):totable())
    eq({10}, vim.iter(t):slice(10, 10):totable())
    eq({8, 9, 10}, vim.iter(t):slice(8, 11):totable())
  end)

  it('nth()', function()
    do
      local t = {4, 3, 2, 1}
      eq(nil, vim.iter(t):nth(0))
      eq(4, vim.iter(t):nth(1))
      eq(3, vim.iter(t):nth(2))
      eq(2, vim.iter(t):nth(3))
      eq(1, vim.iter(t):nth(4))
      eq(nil, vim.iter(t):nth(5))
    end

    do
      local function nth(n)
        return vim.iter(vim.gsplit('a|b|c|d', '|')):nth(n)
      end
      eq(nil, nth(0))
      eq('a', nth(1))
      eq('b', nth(2))
      eq('c', nth(3))
      eq('d', nth(4))
      eq(nil, nth(5))
    end
  end)

  it('nthback()', function()
    do
      local t = {4, 3, 2, 1}
      eq(nil, vim.iter(t):nthback(0))
      eq(1, vim.iter(t):nthback(1))
      eq(2, vim.iter(t):nthback(2))
      eq(3, vim.iter(t):nthback(3))
      eq(4, vim.iter(t):nthback(4))
      eq(nil, vim.iter(t):nthback(5))
    end

    local it = vim.iter(vim.gsplit('a|b|c|d', '|'))
    matches('skipback%(%) requires a list%-like table', pcall_err(it.nthback, it, 1))
  end)

  it('any()', function()
    local function odd(v)
      return v % 2 ~= 0
    end

    do
      local t = { 4, 8, 9, 10 }
      eq(true, vim.iter(t):any(odd))
    end

    do
      local t = { 4, 8, 10 }
      eq(false, vim.iter(t):any(odd))
    end

    do
      eq(true, vim.iter(vim.gsplit('a|b|c|d', '|')):any(function(s) return s == 'd' end))
      eq(false, vim.iter(vim.gsplit('a|b|c|d', '|')):any(function(s) return s == 'e' end))
    end
  end)

  it('all()', function()
    local function odd(v)
      return v % 2 ~= 0
    end

    do
      local t = { 3, 5, 7, 9 }
      eq(true, vim.iter(t):all(odd))
    end

    do
      local t = { 3, 5, 7, 10 }
      eq(false, vim.iter(t):all(odd))
    end

    do
      eq(true, vim.iter(vim.gsplit('a|a|a|a', '|')):all(function(s) return s == 'a' end))
      eq(false, vim.iter(vim.gsplit('a|a|a|b', '|')):all(function(s) return s == 'a' end))
    end
  end)

  it('last()', function()
    local s = 'abcdefghijklmnopqrstuvwxyz'
    eq('z', vim.iter(vim.split(s, '')):last())
    eq('z', vim.iter(vim.gsplit(s, '')):last())
  end)

  it('enumerate()', function()
    local it = vim.iter(vim.gsplit('abc', '')):enumerate()
    eq({1, 'a'}, {it:next()})
    eq({2, 'b'}, {it:next()})
    eq({3, 'c'}, {it:next()})
    eq({}, {it:next()})
  end)

  it('peek()', function()
    do
      local it = vim.iter({ 3, 6, 9, 12 })
      eq(3, it:peek())
      eq(3, it:peek())
      eq(3, it:next())
    end

    do
      local it = vim.iter(vim.gsplit('hi', ''))
      matches('peek%(%) requires a list%-like table', pcall_err(it.peek, it))
    end
  end)

  it('find()', function()
    local t = {3, 6, 9, 12}
    eq(12, vim.iter(t):find(12))
    eq(nil, vim.iter(t):find(15))
    eq(12, vim.iter(t):find(function(v) return v % 4 == 0 end))

    do
      local it = vim.iter(t)
      local pred = function(v) return v % 3 == 0 end
      eq(3, it:find(pred))
      eq(6, it:find(pred))
      eq(9, it:find(pred))
      eq(12, it:find(pred))
      eq(nil, it:find(pred))
    end

    do
      local it = vim.iter(vim.gsplit('AbCdE', ''))
      local pred = function(s) return s:match('[A-Z]') end
      eq('A', it:find(pred))
      eq('C', it:find(pred))
      eq('E', it:find(pred))
      eq(nil, it:find(pred))
    end
  end)

  it('rfind()', function()
    local t = {1, 2, 3, 2, 1}
    do
      local it = vim.iter(t)
      eq(1, it:rfind(1))
      eq(1, it:rfind(1))
      eq(nil, it:rfind(1))
    end

    do
      local it = vim.iter(t):enumerate()
      local pred = function(i) return i % 2 ~= 0 end
      eq({5, 1}, {it:rfind(pred)})
      eq({3, 3}, {it:rfind(pred)})
      eq({1, 1}, {it:rfind(pred)})
      eq(nil, it:rfind(pred))
    end

    do
      local it = vim.iter(vim.gsplit('AbCdE', ''))
      matches('rfind%(%) requires a list%-like table', pcall_err(it.rfind, it, 'E'))
    end
  end)

  it('nextback()', function()
    do
      local it = vim.iter({ 1, 2, 3, 4 })
      eq(4, it:nextback())
      eq(3, it:nextback())
      eq(2, it:nextback())
      eq(1, it:nextback())
      eq(nil, it:nextback())
      eq(nil, it:nextback())
    end

    do
      local it = vim.iter(vim.gsplit('hi', ''))
      matches('nextback%(%) requires a list%-like table', pcall_err(it.nextback, it))
    end
  end)

  it('peekback()', function()
    do
      local it = vim.iter({ 1, 2, 3, 4 })
      eq(4, it:peekback())
      eq(4, it:peekback())
      eq(4, it:nextback())
    end

    do
      local it = vim.iter(vim.gsplit('hi', ''))
      matches('peekback%(%) requires a list%-like table', pcall_err(it.peekback, it))
    end
  end)

  it('fold()', function()
    local t = {1, 2, 3, 4, 5}
    eq(115, vim.iter(t):fold(100, function(acc, v) return acc + v end))
    eq({5, 4, 3, 2, 1}, vim.iter(t):fold({}, function(acc, v)
      table.insert(acc, 1, v)
      return acc
    end))
  end)

  it('handles map-like tables', function()
    local it = vim.iter({ a = 1, b = 2, c = 3 }):map(function(k, v)
      if v % 2 ~= 0 then
        return k:upper(), v * 2
      end
    end)

    local t = it:fold({}, function(t, k, v)
      t[k] = v
      return t
    end)
    eq({ A = 2, C = 6 }, t)
  end)

  it('handles table values mid-pipeline', function()
    local map = {
      item = {
        file = 'test',
      },
      item_2 = {
        file = 'test',
      },
      item_3 = {
        file = 'test',
      },
    }

    local output = vim.iter(map):map(function(key, value)
      return { [key] = value.file }
    end):totable()

    table.sort(output, function(a, b)
      return next(a) < next(b)
    end)

    eq({
      { item = 'test' },
      { item_2 = 'test' },
      { item_3 = 'test' },
    }, output)
  end)

  it('handles nil values', function()
    local t = {1, 2, 3, 4, 5}
    do
      local it = vim.iter(t):enumerate():map(function(i, v)
        if i % 2 == 0 then
          return nil, v*v
        end
        return v, nil
      end)
      eq({
        { [1] = 1 },
        { [2] = 4 },
        { [1] = 3 },
        { [2] = 16 },
        { [1] = 5 },
      }, it:totable())
    end

    do
      local it = vim.iter(ipairs(t)):map(function(i, v)
        if i % 2 == 0 then
          return nil, v*v
        end
        return v, nil
      end)
      eq({
        { [1] = 1 },
        { [2] = 4 },
        { [1] = 3 },
        { [2] = 16 },
        { [1] = 5 },
      }, it:totable())
    end
  end)
end)
