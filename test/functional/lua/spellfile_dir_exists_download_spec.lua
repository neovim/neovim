local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

describe('vim.spellfile – directories, exists, load/download', function()
  before_each(function()
    n:clear()
  end)

  it('directory_choices() lists spell dirs from rtp', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/a', '/b', '/c' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return (p == '/a/spell' or p == '/c/spell') and 1 or 0 end

      local dirs = spellfile.directory_choices()
      return dirs
    ]])
    assert.same({ '/a/spell', '/c/spell' }, out)
  end)

  it(
    'choose_directory(): returns created stdpath(data)/site/spell when none writable in rtp',
    function()
      local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/x' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(_) return 0 end
      vim.fn.stdpath = function(k) assert(k=='data'); return '/tmp' end
      local made
      vim.fn.mkdir = function(p, _) made = p; return 1 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return false end
      else
        vim.loop.fs_access = function(_,_) return false end
        vim.uv = vim.loop
      end

      local dir = spellfile.choose_directory()
      return { dir = dir, made = made }
    ]])
      assert.same('/tmp/site/spell', out.dir)
      assert.same('/tmp/site/spell', out.made)
    end
  )

  it('choose_directory(): returns single spell dir without prompting', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/only' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return p == '/only/spell' and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end
      return spellfile.choose_directory()
    ]])
    assert.same('/only/spell', out)
  end)

  it('choose_directory(): prompts when multiple, returns selected', function()
    local out = exec_lua([[
      local spellfile = require('vim.spellfile')
      spellfile.config.rtp = { '/d1', '/d2' }
      vim.fn.fnamemodify = function(p, _) return p end
      vim.fn.isdirectory = function(p) return (p == '/d1/spell' or p == '/d2/spell') and 1 or 0 end
      if vim.uv then
        vim.uv.fs_access = function(_,_) return true end
      else
        vim.loop.fs_access = function(_,_) return true end
        vim.uv = vim.loop
      end
      vim.fn.inputlist = function(_) return 2 end
      return spellfile.choose_directory()
    ]])
    assert.same('/d2/spell', out)
  end)

  it('exists() returns true only when fs_stat shows file', function()
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
        has = spellfile.exists('en.utf-8.spl'),
        miss = spellfile.exists('en.utf-8.sug'),
      }
    ]])
    assert.is_true(out.has)
    assert.is_false(out.miss)
  end)

  it('load_file(): downloads utf-8 .spl, reloads spell, treats .sug 404 quietly', function()
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
          FS[opts.outpath] = 100
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      spellfile.setup({ encoding = 'utf-8' })
      vim.bo.spelllang = 'en_gb'
      spellfile.load_file('en_gb')

      vim.net = orig_net
      vim.cmd = orig_cmd

      return {
        spl_written = FS['/rtp/spell/en_gb.utf-8.spl'] ~= nil,
        sug_written = FS['/rtp/spell/en_gb.utf-8.sug'] ~= nil,
        did_reload  = (cmds[1] == 'silent! setlocal spell!' or cmds[2] == 'silent! setlocal spell!')
                      and (cmds[1] == 'silent! setlocal spelllang=' .. vim.bo.spelllang
                        or cmds[2] == 'silent! setlocal spelllang=' .. vim.bo.spelllang),
      }
    ]])
    assert.is_true(out.spl_written)
    assert.is_false(out.sug_written)
    assert.is_true(out.did_reload)
  end)

  it('load_file(): falls back to ascii when utf-8 404s', function()
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

      local orig_cmd = vim.cmd
      local cmds = {}
      vim.cmd = function(c) table.insert(cmds, c) end

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(url, opts, cb)
        local name = url:match('/([^/]+)$')
        if name:find('%.utf%-8%.spl$') then
          cb(nil, { status = 404 })
        elseif name:find('%.ascii%.spl$') then
          FS[opts.outpath] = 100
          cb(nil, { status = 200 })
        else
          cb(nil, { status = 404 })
        end
      end

      spellfile.setup({ encoding = 'utf-8' })
      vim.bo.spelllang = 'pt_br'
      spellfile.load_file('pt_br')

      vim.net = orig_net
      vim.cmd = orig_cmd

      return {
        ascii_written = FS['/rtp/spell/pt_br.ascii.spl'] ~= nil,
        reloaded = (cmds[1] == 'silent! setlocal spell!' or cmds[2] == 'silent! setlocal spell!'),
      }
    ]])
    assert.is_true(out.ascii_written)
    assert.is_true(out.reloaded)
  end)

  it('load_file(): warns once and marks done when both utf-8 and ascii fail', function()
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

      local orig_net = vim.net
      vim.net = vim.net or {}
      vim.net.request = function(_, _, cb) cb(nil, { status = 404 }) end

      vim.bo.spelllang = 'xx'
      local key_before
      if spellfile.parse then
        local d = spellfile.parse('xx')
        key_before = d.key
      end
      spellfile.load_file('xx')

      local done = spellfile.done

      vim.net = orig_net
      vim.notify = orig_notify

      return {
        warned = (#notes > 0),
        done   = done,
        key    = key_before,
      }
    ]])
    assert.is_true(out.warned)
    assert.is_true(out.done[out.key])
  end)
end)
