local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local exec = n.exec
local exec_lua = n.exec_lua
local mkdir_p = n.mkdir_p
local write_file = t.write_file
local eq = t.eq

describe('nvim.spellfile', function()
  before_each(function()
    n.clear()
  end)

  it('no-op when .spl and .sug already exist on rtp', function()
    mkdir_p('Xplug/spell')
    write_file('Xplug/spell/en_gb.utf-8.spl', 'dummy')
    write_file('Xplug/spell/en_gb.utf-8.sug', 'dummy')
    exec('set rtp+=' .. 'Xplug')

    local out = exec_lua([[
    local s = require('nvim.spellfile')

    local my_spell = vim.fs.joinpath(vim.fn.fnamemodify('Xplug', ':p'), 'spell')
    local old_access = vim.uv.fs_access
    vim.uv.fs_access = function(p, mode)
      return p == my_spell
    end

    local prompted = false
    vim.fn.input = function() prompted = true; return 'n' end

    local requests = 0
    local orig_req = vim.net.request
    vim.net.request = function(...) requests = requests + 1 end

    s.load_file('en_gb')

    vim.uv.fs_access = old_access
    vim.net.request = orig_req

    return { prompted = prompted, requests = requests }
    ]])

    eq(false, out.prompted)
    eq(0, out.requests)
  end)

  it(
    'downloads UTF-8 .spl to stdpath(data)/site/spell when no rtp spelldir; .sug 404 is non-fatal; reloads',
    function()
      mkdir_p('Xempty')
      exec('set rtp+=' .. 'Xempty')

      local out = exec_lua([[
      local s = require('nvim.spellfile')

      local data_root = 'Xdata'
      vim.fn.stdpath = function(k)
        assert(k == 'data')
        return data_root
      end

      local old_access = vim.uv.fs_access
      vim.uv.fs_access = function(_, _) return false end

      vim.fn.input = function() return 'y' end

      local reloaded = false
      local orig_cmd = vim.cmd
      vim.cmd = function(c)
        if c:match('setlocal%s+spell!') then reloaded = true end
        return orig_cmd(c)
      end

      local orig_req = vim.net.request
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name and name:find('%.spl$') then
          vim.fn.mkdir(vim.fs.dirname(opts.outpath), 'p')
          vim.fn.writefile({'ok'}, opts.outpath)
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      s.load_file('en_gb')

      local spl = vim.fs.joinpath(data_root, 'site', 'spell', 'en_gb.utf-8.spl')
      local sug = vim.fs.joinpath(data_root, 'site', 'spell', 'en_gb.utf-8.sug')
      local has_spl = vim.uv.fs_stat(spl) ~= nil
      local has_sug = vim.uv.fs_stat(sug) ~= nil

      vim.net.request = orig_req
      vim.cmd = orig_cmd
      vim.uv.fs_access = old_access

      return { spl = has_spl, sug = has_sug, reloaded = reloaded }
      ]])

      eq(true, out.spl)
      eq(false, out.sug)
      eq(true, out.reloaded)
    end
  )

  it('dual-fail: UTF-8 and ASCII 404 -> warn once, mark done, no reload', function()
    mkdir_p('Xempty2')
    exec('set rtp+=' .. 'Xempty2')

    local out = exec_lua([[
      local s = require('nvim.spellfile')

      local data_root = 'Xdata2'
      vim.fn.stdpath = function(k)
        assert(k == 'data')
        return data_root
      end

      local old_access = vim.uv.fs_access
      vim.uv.fs_access = function(_, _) return false end
      local old_stat = vim.uv.fs_stat
      vim.uv.fs_stat = function(p) return old_stat and old_stat(p) or nil end

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
        return orig_cmd(c)
      end

      local orig_req = vim.net.request
      vim.net.request = function(_, _, cb) cb(nil, { status = 404 }) end

      local key = s.parse('zz').key
      s.load_file('zz')
      local done = (s.isDone(key)) == true

      vim.net.request = orig_req
      vim.notify = orig_notify
      vim.cmd = orig_cmd
      vim.uv.fs_access = old_access

      return { warns = warns, done = done, reloaded = reloaded }
    ]])

    eq(1, out.warns)
    eq(true, out.done)
    eq(false, out.reloaded)
  end)
end)
