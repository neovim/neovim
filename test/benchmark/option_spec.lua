local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua

describe('option set perf', function()
  before_each(clear)

  --- Runs `fn` (a string of Lua) `iters` times, prints min/median/max, and returns nothing.
  --- @param name string
  --- @param iters integer
  --- @param body string  Lua statement(s) executed each iteration; may use the loop var `i`.
  local function bench(name, iters, body)
    local stats = exec_lua(
      [[
      local iters, body = ...
      local fn = assert(loadstring('local i = ...\n' .. body))
      -- Warmup (JIT, option metadata cache, etc.).
      for i = 1, 100 do
        fn(i)
      end
      local samples = {}
      for i = 1, iters do
        local t0 = vim.uv.hrtime()
        fn(i)
        samples[i] = vim.uv.hrtime() - t0
      end
      table.sort(samples)
      return samples
    ]],
      iters,
      body
    )

    local ms = 1 / 1000000
    print(
      ('\n%-44s min %0.4fms  median %0.4fms  max %0.4fms'):format(
        name,
        stats[1] * ms,
        stats[1 + math.floor(#stats * 0.5)] * ms,
        stats[#stats] * ms
      )
    )
  end

  local ITERS = 20000

  it('vim.o scalar (number)', function()
    bench('vim.o.scrolloff = i % 10', ITERS, [[vim.o.scrolloff = i % 10]])
  end)

  it('vim.o scalar (boolean)', function()
    bench('vim.o.wrap = (i % 2 == 0)', ITERS, [[vim.o.wrap = (i % 2 == 0)]])
  end)

  it('vim.o scalar (string)', function()
    -- makeprg has a trivial did_set handler, so this isolates the set path itself.
    bench("vim.o.makeprg = 'make'", ITERS, [[vim.o.makeprg = 'make']])
  end)

  it('vim.opt array via table', function()
    bench(
      "vim.opt.wildignore = {'*.o','*.a','*.so'}",
      ITERS,
      [[
      vim.opt.wildignore = { '*.o', '*.a', '*.so' }
    ]]
    )
  end)

  it('vim.opt map via table', function()
    bench(
      "vim.opt.listchars = { eol='~', space='.', tab='> ' }",
      ITERS,
      [[
      vim.opt.listchars = { eol = '~', space = '.', tab = '> ' }
    ]]
    )
  end)

  it('vim.opt:append (operation)', function()
    bench(
      'vim.opt.wildignore:append(...)',
      ITERS,
      [[
      vim.o.wildignore = ''
      vim.opt.wildignore:append({ '*.tmp', '*.bak' })
    ]]
    )
  end)

  it('nvim_set_option_value with table (direct API)', function()
    bench(
      'nvim_set_option_value(listchars, {..})',
      ITERS,
      [[
      vim.api.nvim_set_option_value('listchars', { eol = '~', space = '.' }, {})
    ]]
    )
  end)
end)
