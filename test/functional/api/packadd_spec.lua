local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
local api = n.api
local exec_lua = n.exec_lua

describe('nvim__packadd_opt', function()
  local root, name

  before_each(function()
    n.clear()
    root, name = t.tmpname(false), 'plugin % dirs'
    for _, kind in ipairs({ 'start', 'opt' }) do
      local path = root .. '/pack/test/' .. kind .. '/' .. name
      n.fn.mkdir(path .. '/plugin', 'p')
      t.write_file(path .. '/plugin/test.lua', ('vim.g.pack_%s_loaded = true'):format(kind))
    end
    exec_lua('vim.o.packpath = ...', root)
  end)

  after_each(function()
    n.rmdir(root)
  end)

  it('skips start packages without marking them as loaded', function()
    api.nvim__packadd_opt(name, true)
    eq(
      { true, vim.NIL },
      exec_lua('return { vim.g.pack_opt_loaded, vim.g.pack_start_loaded or vim.NIL }')
    )
    eq(
      false,
      exec_lua(
        'return vim.list_contains(vim.opt.rtp:get(), ...)',
        root .. '/pack/test/start/' .. name
      )
    )
    n.command('packloadall')
    eq(true, exec_lua('return vim.g.pack_start_loaded'))
  end)

  it('retains generic packadd behavior before startup package loading', function()
    exec_lua(function(plugin)
      vim.cmd.packadd({ vim.fn.escape(plugin, ' '), magic = { file = false } })
    end, name)
    eq({ true, true }, exec_lua('return { vim.g.pack_opt_loaded, vim.g.pack_start_loaded }'))
  end)

  it('finds all opt matches and discovers new directories without changing packpath', function()
    api.nvim__packadd_opt(name, false)
    local other = root .. '/pack/new/opt/' .. name
    n.fn.mkdir(other .. '/after', 'p')
    api.nvim__packadd_opt(name, false)
    local paths = exec_lua('return vim.opt.rtp:get()')
    eq(true, vim.list_contains(paths, other))
    eq(true, vim.list_contains(paths, other .. '/after'))
    eq({}, exec_lua('return { vim.g.pack_opt_loaded, vim.g.pack_start_loaded }'))
  end)

  it('preserves runtime ordering, cache contents, and ftdetect loading', function()
    local path = root .. '/pack/test/opt/' .. name
    n.fn.mkdir(path .. '/ftdetect', 'p')
    n.fn.mkdir(path .. '/lua', 'p')
    n.fn.mkdir(path .. '/after', 'p')
    t.write_file(path .. '/ftdetect/test.vim', 'let g:pack_ftdetect_loaded = 1')
    t.write_file(path .. '/lua/pack_test.lua', 'return 42')
    local function inspect(opt_only)
      n.clear()
      return exec_lua(function(site, plugin, only_opt)
        vim.o.packpath = site
        vim.opt.runtimepath:prepend(site)
        vim.opt.runtimepath:append(site .. '/after')
        vim.cmd.packloadall()
        vim.cmd.filetype('on')
        vim.api.nvim_get_runtime_file('lua/pack_test.lua', false)
        if only_opt then
          vim.api.nvim__packadd_opt(plugin, false)
          vim.api.nvim__packadd_opt(plugin, true)
        else
          vim.cmd.packadd({ vim.fn.escape(plugin, ' '), magic = { file = false } })
        end
        return {
          vim.o.runtimepath,
          vim.api.nvim__runtime_inspect(),
          require('pack_test'),
          vim.g.pack_ftdetect_loaded,
        }
      end, root, name, opt_only)
    end
    eq(inspect(false), inspect(true))
  end)

  it('reports missing opt packages even if a start package exists', function()
    t.matches('must not be empty', t.pcall_err(api.nvim__packadd_opt, '', false))
    n.fn.mkdir(root .. '/pack/test/start/start_only', 'p')
    t.matches('E919:', t.pcall_err(api.nvim__packadd_opt, 'start_only', false))
    n.command('packloadall')
    t.matches('E919:', t.pcall_err(api.nvim__packadd_opt, 'start_only', false))
  end)
end)
