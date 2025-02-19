local N = 20

local function tcall(f, ...)
  local ts = vim.uv.hrtime()
  for _ = 1, N do
    f(...)
  end
  return ((vim.uv.hrtime() - ts) / 1000000) / N
end

local function build_shared(n)
  local t = {}
  local a = {}
  local b = {}
  local c = {}
  for _ = 1, n do
    t[#t + 1] = {}
    local tl = t[#t]
    for _ = 1, n do
      tl[#tl + 1] = a
      tl[#tl + 1] = b
      tl[#tl + 1] = c
    end
  end
  return t
end

local function build_unique(n)
  local t = {}
  for _ = 1, n do
    t[#t + 1] = {}
    local tl = t[#t]
    for _ = 1, n do
      tl[#tl + 1] = {}
    end
  end
  return t
end

describe('vim.deepcopy()', function()
  local function run(name, n, noref)
    it(string.format('%s entries=%d noref=%s', name, n, noref), function()
      local t = name == 'shared' and build_shared(n) or build_unique(n)
      local d = tcall(vim.deepcopy, t, noref)
      print(string.format('%.2f ms', d))
    end)
  end

  run('unique', 50, false)
  run('unique', 50, true)
  run('unique', 2000, false)
  run('unique', 2000, true)

  run('shared', 50, false)
  run('shared', 50, true)
  run('shared', 2000, false)
  run('shared', 2000, true)
end)
