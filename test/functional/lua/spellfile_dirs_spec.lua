local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('vim.spellfile – directory selection', function()
  before_each(function()
    n:clear()
  end)

  it('no writable rtp dirs -> creates and uses stdpath(data)/site/spell', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp1', '/rtp2' }

      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end
      vim.fn.stdpath = function(k) assert(k=='data'); return '/tmp' end

      local created
      vim.fn.mkdir = function(p, _) created = p; return 1 end

      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.uv = vim.loop
      end

      local dir = spellfile.choose_directory()
      return { dir = dir, created = created }
      ]])

    assert.same('/tmp/site/spell', out.dir)
    assert.same('/tmp/site/spell', out.created)
  end)
end)
