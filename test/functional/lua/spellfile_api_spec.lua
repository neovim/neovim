local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('vim.spellfile – API (exists, setup, parse)', function()
  before_each(function()
    n:clear()
  end)

  it('exists(): true when file present, false otherwise', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end

      local files = { ['/rtp/spell/en.utf-8.spl'] = { type='file', size=10 } }
      if vim.uv then
        vim.uv.fs_stat = function(p) return files[p] end
      else
        vim.loop.fs_stat = function(p) return files[p] end
        vim.uv = vim.loop
      end

      return {
        has  = spellfile.exists('en.utf-8.spl'),
        miss = spellfile.exists('en.utf-8.sug'),
      }
    ]])
    assert.is_true(out.has)
    assert.is_false(out.miss)
  end)

  it('setup(): applies overrides and resets done', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.done.sample = true

      spellfile.setup({
        url = 'https://example.test/spell',
        encoding = 'iso-8859-1',
      })

      return {
        url = spellfile.config.url,
        enc = spellfile.config.encoding,
        done_empty = (next(spellfile.done) == nil),
      }
    ]])
    assert.are.same('https://example.test/spell', out.url)
    assert.are.same('iso-8859-1', out.enc)
    assert.is_true(out.done_empty)
  end)

  it(
    'parse(): normalizes lang, maps iso-8859-* to latin1, and targets stdpath(data)/site/spell when no writable rtp dirs',
    function()
      local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      -- No writable dirs in rtp
      spellfile.config.rtp = { '/rtp1', '/rtp2' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end
      vim.fn.stdpath = function(k) assert(k=='data'); return '/tmp' end
      vim.fn.mkdir = function(_) return 1 end

      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
        vim.uv.fs_stat = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.loop.fs_stat = function(_) return nil end
        vim.uv = vim.loop
      end

      -- Force iso-8859-* to validate mapping to latin1
      spellfile.setup({ encoding = 'iso-8859-15' })

      local info = spellfile.parse('EN-GB,en_us') -- first token should be used
      return { lang = info.lang, enc = info.encoding, dir = info.dir }
    ]])
      assert.are.same('en_gb', out.lang)
      assert.are.same('latin1', out.enc)
      assert.are.same('/tmp/site/spell', out.dir)
    end
  )
end)
