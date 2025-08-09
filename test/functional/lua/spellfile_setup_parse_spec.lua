local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('spellfile.lua – setup & parse', function()
  before_each(function()
    n:clear()
  end)

  it('loads with default config', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      return { url = spellfile.config.url, enc = spellfile.config.encoding }
    ]])
    assert.are.same('https://ftp.nluug.nl/pub/vim/runtime/spell', out.url)
    assert.are.same('utf-8', out.enc)
  end)

  it('setup() applies overrides and resets done', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.done.en = true
      spellfile.setup({ url = 'https://example.test/spell', encoding = 'iso-8859-1' })
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
    'parse() normalizes lang (keeps region), uses utf-8, targets stdpath(data)/site/spell when no writable rtp dirs',
    function()
      local res = exec_lua([[
      local orig_fn = vim.fn
      local uv = vim.uv or vim.loop

      vim.fn = setmetatable({
        isdirectory = function(_) return 0 end,   -- force no rtp spell dirs
        mkdir       = function(_) return 1 end,
        stdpath     = function(k) assert(k=='data'); return '/tmp' end,
        fnamemodify = function(p, _) return p end,
      }, { __index = orig_fn })

      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
        vim.uv.fs_stat   = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.loop.fs_stat   = function(_) return nil end
        vim.uv = vim.loop
      end

      local spellfile = require('vim.spellfile')
      local d1 = spellfile.parse('EN-GB')
      local d2 = spellfile.parse('en_gb,en_us')

      return {
        d1 = { lang = d1.lang, enc = d1.encoding, dir = d1.dir },
        d2 = { lang = d2.lang },
      }
    ]])
      assert.are.same('en_gb', res.d1.lang)
      assert.are.same('utf-8', res.d1.enc)
      assert.are.same('/tmp/site/spell', res.d1.dir)
      assert.are.same('en_gb', res.d2.lang)
    end
  )

  it('parse() maps iso-8859-* to latin1 (at use time)', function()
    local out = exec_lua([[
      vim.fn.stdpath    = function(k) assert(k=='data'); return '/tmp' end
      vim.fn.fnamemodify= function(p, _) return p end
      vim.fn.isdirectory= function(_) return 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
        vim.uv.fs_stat   = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.loop.fs_stat   = function(_) return nil end
        vim.uv = vim.loop
      end

      local spellfile = require('vim.spellfile')
      spellfile.setup({ encoding = 'iso-8859-15' })
      local d = spellfile.parse('pt_BR')
      return { lang = d.lang, enc = d.encoding }
    ]])
    assert.are.same('pt_br', out.lang)
    assert.are.same('latin1', out.enc)
  end)

  it('parse() lists only missing files (when .sug already exists)', function()
    local files = exec_lua([[
      vim.fn.stdpath     = function(k) assert(k=='data'); return '/tmp' end
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end

      local base = '/tmp/site/spell'
      local ok = { [base .. '/en_gb.utf-8.sug'] = true }
      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
        vim.uv.fs_stat   = function(p) return ok[p] and { type='file', size=123 } or nil end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.loop.fs_stat   = function(p) return ok[p] and { type='file', size=123 } or nil end
        vim.uv = vim.loop
      end

      local spellfile = require('vim.spellfile')
      local d = spellfile.parse('en_GB')
      return d.files
    ]])
    assert.are.same({ 'en_gb.utf-8.spl' }, files)
  end)
end)
