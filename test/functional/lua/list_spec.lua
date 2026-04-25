-- Test suite for vim.list
local t = require('test.testutil')
local eq = t.eq

describe('vim.list', function()
  it('vim.list.unique()', function()
    eq({ 1, 2, 3, 4, 5 }, vim.list.unique({ 1, 2, 2, 3, 4, 4, 5 }))
    eq({ 1, 2, 3, 4, 5 }, vim.list.unique({ 1, 2, 3, 4, 4, 5, 1, 2, 3, 2, 1, 2, 3, 4, 5 }))
    eq({ 1, 2, 3, 4, 5, field = 1 }, vim.list.unique({ 1, 2, 2, 3, 4, 4, 5, field = 1 }))

    -- Not properly defined, but test anyway
    -- luajit evaluates #t as 7, whereas Lua 5.1 evaluates it as 12
    local r = vim.list.unique({ 1, 2, 2, 3, 4, 4, 5, nil, 6, 6, 7, 7 })
    if jit then
      eq({ 1, 2, 3, 4, 5, nil, nil, nil, 6, 6, 7, 7 }, r)
    else
      eq({ 1, 2, 3, 4, 5, nil, 6, 7 }, r)
    end

    eq(
      { { 1 }, { 2 }, { 3 } },
      vim.list.unique({ { 1 }, { 1 }, { 2 }, { 2 }, { 3 }, { 3 } }, function(x)
        return x[1]
      end)
    )
  end)

  --- Generate a list like { 1, 2, 2, 3, 3, 3, 4, 4, 4, 4, ...}.
  ---@param num integer
  local function gen_list(num)
    ---@type integer[]
    local list = {}
    for i = 1, num do
      for _ = 1, i do
        list[#list + 1] = i
      end
    end
    return list
  end

  --- Index of the last {num}.
  --- Mathematically, a triangular number.
  ---@param num integer
  local function index(num)
    return math.floor((math.pow(num, 2) + num) / 2)
  end

  it("vim.list.bisect(..., { bound = 'lower' })", function()
    local num = math.random(100)
    local list = gen_list(num)

    local target = math.random(num)
    eq(vim.list.bisect(list, target, { bound = 'lower' }), index(target - 1) + 1)
    eq(vim.list.bisect(list, num + 1, { bound = 'lower' }), index(num) + 1)
  end)

  it("vim.list.bisect(..., bound = { 'upper' })", function()
    local num = math.random(100)
    local list = gen_list(num)

    local target = math.random(num)
    eq(vim.list.bisect(list, target, { bound = 'upper' }), index(target) + 1)
    eq(vim.list.bisect(list, num + 1, { bound = 'upper' }), index(num) + 1)
  end)
end)
