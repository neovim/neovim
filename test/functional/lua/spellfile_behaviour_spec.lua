local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('vim.spellfile – core behavior', function()
  before_each(function()
    n:clear()
  end)

  it('no-op when .spl and .sug already exist (no prompt, no network)', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      -- Writable rtp spelldir
      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end

      -- Files already present
      local FS = {
        ['/rtp/spell/en_gb.utf-8.spl'] = { type='file', size=111 },
        ['/rtp/spell/en_gb.utf-8.sug'] = { type='file', size=222 },
      }
      if vim.uv then
        vim.uv.fs_stat = function(p) return FS[p] end
      else
        vim.loop.fs_stat = function(p) return FS[p] end
        vim.uv = vim.loop
      end

      local prompted = false
      vim.fn.input = function() prompted = true; return 'n' end

      local requests = 0
      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(...) requests = requests + 1 end

      spellfile.load_file('en_gb')

      vim.net = orig_net
      return { prompted = prompted, requests = requests }
    ]])
    assert.is_false(out.prompted)
    assert.are.same(0, out.requests)
  end)

  it('downloads UTF-8 .spl successfully and reloads spell', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end

      local FS = {}
      if vim.uv then
        vim.uv.fs_stat = function(p) return FS[p] end
      else
        vim.loop.fs_stat = function(p) return FS[p] end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local reloaded = false
      local orig_cmd = vim.cmd
      vim.cmd = function(c)
        if c:match('setlocal%s+spell!') then reloaded = true end
      end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name:find('%.spl$') then
          FS[opts.outpath] = { type='file', size=100 }
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      spellfile.load_file('en_gb')

      vim.net = orig_net
      vim.cmd = orig_cmd

      return {
        spl_present = FS['/rtp/spell/en_gb.utf-8.spl'] ~= nil,
        reloaded = reloaded,
      }
    ]])
    assert.is_true(out.spl_present)
    assert.is_true(out.reloaded)
  end)

  it('falls back to ASCII when UTF-8 .spl 404s and reloads', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end

      local FS = {}
      if vim.uv then
        vim.uv.fs_stat = function(p) return FS[p] end
      else
        vim.loop.fs_stat = function(p) return FS[p] end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local reloaded = false
      local orig_cmd = vim.cmd
      vim.cmd = function(c)
        if c:match('setlocal%s+spell!') then reloaded = true end
      end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name:find('%.utf%-8%.spl$') then
          cb(nil, { status = 404 })
        elseif name:find('%.ascii%.spl$') then
          FS[opts.outpath] = { type='file', size=123 }
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      spellfile.load_file('pt_br')

      vim.net = orig_net
      vim.cmd = orig_cmd

      return {
        ascii_present = FS['/rtp/spell/pt_br.ascii.spl'] ~= nil,
        reloaded = reloaded,
      }
    ]])
    assert.is_true(out.ascii_present)
    assert.is_true(out.reloaded)
  end)

  it('`.sug` is optional: UTF-8 .spl ok, .sug 404 → no warn', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end

      local FS = {}
      if vim.uv then
        vim.uv.fs_stat = function(p) return FS[p] end
      else
        vim.loop.fs_stat = function(p) return FS[p] end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local warns = 0
      local orig_notify = vim.notify
      vim.notify = function(_, lvl)
        if lvl and lvl >= vim.log.levels.WARN then warns = warns + 1 end
      end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name:find('%.spl$') then
          FS[opts.outpath] = { type='file', size=111 }
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      spellfile.load_file('ro')

      vim.net = orig_net
      vim.notify = orig_notify

      return {
        spl_present = FS['/rtp/spell/ro.utf-8.spl'] ~= nil,
        sug_present = FS['/rtp/spell/ro.utf-8.sug'] ~= nil,
        warns = warns,
      }
    ]])
    assert.is_true(out.spl_present)
    assert.is_false(out.sug_present)
    assert.are.same(0, out.warns)
  end)

  it('both UTF-8 and ASCII fail → warn once, mark done, no reload', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')

      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
        vim.uv.fs_stat = function(_) return nil end
      else
     vim.loop.fs_access = function(_,_) return true end
        vim.loop.fs_stat = function(_) return nil end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local warns = 0
      local orig_notify = vim.notify
      vim.notify = function(_, lvl)
        if lvl and lvl >= vim.log.levels.WARN then warns = warns + 1 end
      end

      local reloaded = false
      local orig_cmd = vim.cmd
      vim.cmd = function(c)
        if c:match('setlocal%s+spell!') then reloaded = true end
      end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(_, _, cb) cb(nil, { status = 404 }) end

      local key = spellfile.parse('xx').key
      spellfile.load_file('xx')

      local done = spellfile.done[key] == true

      vim.net = orig_net
      vim.notify = orig_notify
      vim.cmd = orig_cmd

      return { warns = warns, done = done, reloaded = reloaded }
    ]])
    assert.are.same(1, out.warns)
    assert.is_true(out.done)
    assert.is_false(out.reloaded)
  end)
end)
