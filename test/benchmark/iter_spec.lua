local N = 500
local test_table_size = 100000

describe('vim.iter perf', function()
  local function mean(t)
    assert(#t > 0)
    local sum = 0
    for _, v in ipairs(t) do
      sum = sum + v
    end
    return sum / #t
  end

  local function median(t)
    local len = #t
    if len % 2 == 0 then
      return t[len / 2]
    end
    return t[(len + 1) / 2]
  end

  -- Assert that results are equal between each benchmark
  local last = nil

  local function reset()
    last = nil
  end

  local input = {}
  for i = 1, test_table_size do
    input[#input + 1] = i
  end

  local function measure(f)
    local stats = {}
    local result
    for _ = 1, N do
      local tic = vim.uv.hrtime()
      result = f(input)
      local toc = vim.uv.hrtime()
      stats[#stats + 1] = (toc - tic) / 1000000
    end
    table.sort(stats)
    print(
      string.format(
        '\nMin: %0.6f ms, Max: %0.6f ms, Median: %0.6f ms, Mean: %0.6f ms',
        math.min(unpack(stats)),
        math.max(unpack(stats)),
        median(stats),
        mean(stats)
      )
    )

    if last ~= nil then
      assert(#result == #last)
      for i, v in ipairs(result) do
        if type(v) == 'string' or type(v) == 'number' then
          assert(last[i] == v)
        elseif type(v) == 'table' then
          for k, vv in pairs(v) do
            assert(last[i][k] == vv)
          end
        end
      end
    end

    last = result
  end

  describe('list like table', function()
    describe('simple map', function()
      reset()

      it('vim.iter', function()
        local function f(t)
          return vim
            .iter(t)
            :map(function(v)
              return v * 2
            end)
            :totable()
        end
        measure(f)
      end)

      it('for loop', function()
        local function f(t)
          local res = {}
          for i = 1, #t do
            res[#res + 1] = t[i] * 2
          end
          return res
        end
        measure(f)
      end)
    end)

    describe('filter, map, skip, reverse', function()
      reset()

      it('vim.iter', function()
        local function f(t)
          local i = 0
          return vim
            .iter(t)
            :map(function(v)
              i = i + 1
              if i % 2 == 0 then
                return v * 2
              end
            end)
            :skip(1000)
            :rev()
            :totable()
        end
        measure(f)
      end)

      it('tables', function()
        local function f(t)
          local a = {}
          for i = 1, #t do
            if i % 2 == 0 then
              a[#a + 1] = t[i] * 2
            end
          end

          local b = {}
          for i = 1001, #a do
            b[#b + 1] = a[i]
          end

          local c = {}
          for i = 1, #b do
            c[#c + 1] = b[#b - i + 1]
          end
          return c
        end
        measure(f)
      end)
    end)
  end)

  describe('iterator', function()
    describe('simple map', function()
      reset()
      it('vim.iter', function()
        local function f(t)
          return vim
            .iter(ipairs(t))
            :map(function(i, v)
              return i + v
            end)
            :totable()
        end
        measure(f)
      end)

      it('ipairs', function()
        local function f(t)
          local res = {}
          for i, v in ipairs(t) do
            res[#res + 1] = i + v
          end
          return res
        end
        measure(f)
      end)
    end)

    describe('multiple stages', function()
      reset()
      it('vim.iter', function()
        local function f(t)
          return vim
            .iter(ipairs(t))
            :map(function(i, v)
              if i % 2 ~= 0 then
                return v
              end
            end)
            :map(function(v)
              return v * 3
            end)
            :skip(50)
            :totable()
        end
        measure(f)
      end)

      it('ipairs', function()
        local function f(t)
          local a = {}
          for i, v in ipairs(t) do
            if i % 2 ~= 0 then
              a[#a + 1] = v
            end
          end
          local b = {}
          for _, v in ipairs(a) do
            b[#b + 1] = v * 3
          end
          local c = {}
          for i, v in ipairs(b) do
            if i > 50 then
              c[#c + 1] = v
            end
          end
          return c
        end
        measure(f)
      end)
    end)
  end)
end)
