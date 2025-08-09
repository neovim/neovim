local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('vim.spellfile – load_file behavior', function()
  before_each(function()
    n:clear()
  end)

  it('does nothing (no prompt, no download) when .spl and .sug already exist', function()
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

      local FS = {
        ['/rtp/spell/en_gb.utf-8.spl'] = true,
        ['/rtp/spell/en_gb.utf-8.sug'] = true,
      }
      if vim.uv then
        vim.uv.fs_stat = function(p) return FS[p] and { type='file', size=42 } or nil end
      else
        vim.loop.fs_stat = function(p) return FS[p] and { type='file', size=42 } or nil end
        vim.uv = vim.loop
      end

      local prompted = false
      vim.fn.input = function() prompted = true; return 'n' end

      local requests = 0
      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(...) requests = requests + 1 end

      vim.bo.spelllang = 'en_gb'
      spellfile.load_file('en_gb')

      vim.net = orig_net

      return { prompted = prompted, requests = requests }
    ]])
    assert.is_false(out.prompted)
    assert.are.same(0, out.requests)
  end)

  it('respects user cancel (input "n"): no download occurs', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
        vim.uv.fs_stat   = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.loop.fs_stat   = function(_) return nil end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'n' end

      local requests = 0
      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(...) requests = requests + 1 end

      spellfile.load_file('en_gb')

      vim.net = orig_net
      return requests
    ]])
    assert.are.same(0, out)
  end)

  it('marks done[key] after success and skips subsequent attempts', function()
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
        vim.uv.fs_stat = function(p) return FS[p] and { type='file', size=FS[p] } or nil end
      else
        vim.loop.fs_stat = function(p) return FS[p] and { type='file', size=FS[p] } or nil end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local requests = 0
      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        requests = requests + 1
        local name = url:match('/([^/]+)$')
        if name:find('%.spl$') then
          FS[opts.outpath] = 100
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      vim.bo.spelllang = 'it'
      spellfile.load_file('it')      -- first time: downloads .spl
      local key = spellfile.parse('it').key
      local done_after_first = spellfile.done[key] == true

      spellfile.load_file('it')      -- second time: should skip

      vim.net = orig_net
      return { requests = requests, done = done_after_first }
    ]])
    assert.is_true(out.done)
    assert.are.same(2, out.requests)
  end)

  it('downloads .sug successfully when available and reloads once', function()
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
        vim.uv.fs_stat = function(p) return FS[p] and { type='file', size=FS[p] } or nil end
      else
        vim.loop.fs_stat = function(p) return FS[p] and { type='file', size=FS[p] } or nil end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local cmds = {}
      local orig_cmd = vim.cmd
      vim.cmd = function(c) table.insert(cmds, c) end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name:find('%.spl$') then
          FS[opts.outpath] = 111
          cb(nil, { status = 200 })
        else
          FS[opts.outpath] = 222
          cb(nil, { status = 200 })
        end
      end

      vim.bo.spelllang = 'ro'
      spellfile.load_file('ro')

      vim.net = orig_net
      vim.cmd = orig_cmd

      return {
        spl = FS['/rtp/spell/ro.utf-8.spl'] ~= nil,
        sug = FS['/rtp/spell/ro.utf-8.sug'] ~= nil,
        reload_calls = #cmds,
      }
    ]])
    assert.is_true(out.spl)
    assert.is_true(out.sug)
    assert.is_true(out.reload_calls >= 2)
  end)

  it('when both utf-8 and ascii .spl fail, warns and sets done without reloading', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/rtp' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/rtp/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
        vim.uv.fs_stat   = function(_) return nil end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.loop.fs_stat   = function(_) return nil end
        vim.uv = vim.loop
      end

      vim.fn.input = function() return 'y' end

      local notes = {}
      local orig_notify = vim.notify
      vim.notify = function(msg, lvl) table.insert(notes, {msg=msg, lvl=lvl}) end

      local cmds = {}
      local orig_cmd = vim.cmd
      vim.cmd = function(c) table.insert(cmds, c) end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        cb(nil, { status = 404 })
      end

      local key = require('vim.spellfile').parse('ny').key
      require('vim.spellfile').load_file('ny')

      local sf = require('vim.spellfile')
      local is_done = sf.done[key] == true

      vim.net = orig_net
      vim.notify = orig_notify
      vim.cmd = orig_cmd

      return { warned = (#notes > 0), done = is_done, reload_calls = #cmds }
    ]])
    assert.is_true(out.warned)
    assert.is_true(out.done)
    assert.are.same(0, out.reload_calls)
  end)
end)
