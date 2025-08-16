local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local exec_lua = n.exec_lua
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

describe('vim.spellfile – integration (real network, gated by NVIM_TEST_INTEG)', function()
  before_each(function()
    n:clear()
  end)

  it('happy path: downloads UTF-8 .spl and writes a non-empty file', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      local tmp = '/tmp/nvim-spell-integ-' .. tostring((vim.uv or vim.loop).getpid())
      vim.fn.stdpath = function(k) assert(k == 'data'); return tmp end
      vim.fn.mkdir(tmp .. '/site/spell', 'p')

      spellfile.config.rtp = { '/rtp1', '/rtp2' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.uv = vim.loop
      end

      spellfile.setup({
        url = 'https://httpbingo.org/anything',
        encoding = 'utf-8',
        timeout_ms = 4000,
      })

      vim.fn.input = function() return 'y' end

      spellfile.load_file('en_gb')

      local path = tmp .. '/site/spell/en_gb.utf-8.spl'
      local st = (vim.uv or vim.loop).fs_stat(path)
      return { path = path, ok = (st and st.type == 'file' and st.size and st.size > 0) or false }
    ]])

    assert.are.same(true, out.ok, 'expected non-empty .spl at' .. out.path)
  end)

  it('dual-fail path: utf-8 and ascii both 404 → warn once, mark done', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      local tmp = '/tmp/nvim-spell-integ-' .. tostring((vim.uv or vim.loop).getpid())
      vim.fn.stdpath = function(k) assert(k == 'data'); return tmp end
      vim.fn.mkdir(tmp .. '/site/spell', 'p')

      spellfile.config.rtp = { '/rtp1' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
        vim.uv.fs_stat = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.loop.fs_stat = function(_) return nil end
        vim.uv = vim.loop
      end

      spellfile.setup({
        url = 'https://httpbingo.org/status/404',
        encoding = 'utf-8',
        timeout_ms = 3000,
      })

      vim.fn.input = function() return 'y' end

      local warns = 0
      local orig_notify = vim.notify
      vim.notify = function(_, lvl)
        if lvl and lvl >= vim.log.levels.WARN then warns = warns + 1 end
      end

      local key = spellfile.parse('zz').key
      spellfile.load_file('zz')

      local done = spellfile.done[key] == true
      vim.notify = orig_notify
      return { warns = warns, done = done }
    ]])

    assert.are.same(1, out.warns, 'expected exactly one warning')
    assert.are.same(true, out.done, 'expected done[key] to be set after failure')
  end)
end)
