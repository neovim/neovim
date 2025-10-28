local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local eq = t.eq
local exec_lua = n.exec_lua

describe('nvim.spellfile', function()
  local data_root = 'Xtest_data'
  local rtp_dir = 'Xtest_rtp'

  before_each(function()
    n.clear()
    n.exec('set runtimepath+=' .. rtp_dir)
  end)
  after_each(function()
    n.rmdir(data_root)
    n.rmdir(rtp_dir)
  end)

  it('no-op when .spl and .sug already exist on runtimepath', function()
    local my_spell = vim.fs.joinpath(vim.fs.abspath(rtp_dir), 'spell')
    n.mkdir_p(my_spell)
    t.retry(nil, nil, function()
      assert(vim.uv.fs_stat(my_spell))
    end)
    t.write_file(my_spell .. '/en_gb.utf-8.spl', 'dummy')
    t.write_file(my_spell .. '/en_gb.utf-8.sug', 'dummy')

    local out = exec_lua(
      [[
      local rtp_dir = ...
      local s = require('nvim.spellfile')
      local my_spell = vim.fs.joinpath(vim.fs.abspath(rtp_dir), 'spell')

      vim.uv.fs_access = function(p, mode)
        return p == my_spell
      end

      local prompted = false
      vim.fn.input = function() prompted = true; return 'n' end

      local requests = 0
      vim.net.request = function(...) requests = requests + 1 end

      s.load_file('en_gb')

      return { prompted = prompted, requests = requests }
    ]],
      rtp_dir
    )

    eq(false, out.prompted)
    eq(0, out.requests)
  end)

  it('downloads .spl to stdpath(data)/site/spell, .sug 404 is non-fatal, reloads', function()
    n.mkdir_p(rtp_dir)

    local out = exec_lua(
      [[
        local data_root = ...
        local s = require('nvim.spellfile')

        vim.fn.stdpath = function(k)
          assert(k == 'data')
          return data_root
        end

        vim.fn.input = function() return 'y' end

        local did_reload = false
        local orig_cmd = vim.cmd
        vim.cmd = function(cmd)
          if cmd:match('setlocal%s+spell!') then
            did_reload = true
          end
          return orig_cmd(cmd)
        end

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

        local spl = vim.fs.joinpath(data_root, 'site/spell/en_gb.utf-8.spl')
        local sug = vim.fs.joinpath(data_root, 'site/spell/en_gb.utf-8.sug')

        return {
          has_spl = vim.uv.fs_stat(spl) ~= nil,
          has_sug = vim.uv.fs_stat(sug) ~= nil,
          did_reload = did_reload,
        }
      ]],
      data_root
    )

    eq(true, out.has_spl)
    eq(false, out.has_sug)
    eq(true, out.did_reload)
  end)

  it('failure mode: 404 for all files => warn once, mark done, no reload', function()
    local out = exec_lua(
      [[
      local data_root = ...
      local s = require('nvim.spellfile')

      vim.fn.stdpath = function(k)
        assert(k == 'data')
        return data_root
      end

      vim.fn.input = function() return 'y' end

      local warns = 0
      vim.notify = function(_, lvl)
        if lvl and lvl >= vim.log.levels.WARN then warns = warns + 1 end
      end

      local did_reload = false
      local orig_cmd = vim.cmd
      vim.cmd = function(c)
        if c:match('setlocal%s+spell!') then
          did_reload = true
        end
        return orig_cmd(c)
      end

      vim.net.request = function(_, _, cb) cb(nil, { status = 404 }) end

      local info = s.load_file('zz')
      local done = s._done[info.key] == true

      return { warns = warns, done = done, did_reload = did_reload }
    ]],
      data_root
    )

    eq(1, out.warns)
    eq(true, out.done)
    eq(false, out.did_reload)
  end)
end)
