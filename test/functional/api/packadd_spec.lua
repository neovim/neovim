local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
local api = n.api
local exec_lua = n.exec_lua

describe('nvim__packadd', function()
  local root, package_path

  before_each(function()
    n.clear()
    root = t.tmpname(false)
    package_path = root .. '/pack/test/opt/plugin % dirs'
    for _, dir in ipairs({ 'plugin/nested', 'after/plugin', 'lua', 'ftdetect' }) do
      n.fn.mkdir(package_path .. '/' .. dir, 'p')
    end
    t.write_file(package_path .. '/plugin/nested/test.lua', 'vim.g.pack_loaded = true')
    t.write_file(package_path .. '/after/plugin/test.lua', 'vim.g.pack_after_loaded = true')
    t.write_file(package_path .. '/ftdetect/test.vim', 'let g:pack_ftdetect_loaded = 1')
    t.write_file(package_path .. '/lua/pack_test.lua', 'return 42')
  end)

  after_each(function()
    n.rmdir(root)
  end)

  it('preserves packadd! runtime path ordering and cache contents', function()
    local function inspect(direct)
      n.clear()
      return exec_lua(function(site, path, use_direct)
        vim.o.packpath = site
        vim.opt.runtimepath:prepend(site)
        vim.opt.runtimepath:append(site .. '/after')
        vim.api.nvim_get_runtime_file('lua/pack_test.lua', false) -- Populate the cache.
        if use_direct then
          vim.api.nvim__packadd(path, false)
          vim.api.nvim__packadd(path, false) -- Do not duplicate runtime path entries.
        else
          vim.cmd.packadd({
            vim.fn.escape('plugin % dirs', ' '),
            bang = true,
            magic = { file = false },
          })
        end
        return { vim.o.runtimepath, vim.api.nvim__runtime_inspect(), require('pack_test') }
      end, root, package_path, direct)
    end
    eq(inspect(false), inspect(true))
    eq(
      {},
      exec_lua('return { vim.g.pack_loaded, vim.g.pack_after_loaded, vim.g.pack_ftdetect_loaded }')
    )
  end)

  it('loads plugin and ftdetect scripts, leaving after scripts to the caller', function()
    n.command('filetype on')
    api.nvim__packadd(package_path, true)
    eq({ true, 1 }, exec_lua('return { vim.g.pack_loaded, vim.g.pack_ftdetect_loaded }'))
    eq(vim.NIL, exec_lua('return vim.g.pack_after_loaded'))
    eq(42, exec_lua('return require("pack_test")'))
  end)

  it('adds only the requested package, independently of packpath', function()
    local other = root .. '/pack/other/start/plugin % dirs'
    n.fn.mkdir(other, 'p')
    exec_lua('vim.o.packpath = ...', root)
    api.nvim__packadd(package_path, false)
    eq(false, exec_lua('return vim.list_contains(vim.opt.rtp:get(), ...)', other))
    exec_lua('vim.o.packpath = ""')
    api.nvim__packadd(package_path, true)
    eq(true, exec_lua('return vim.g.pack_loaded'))
  end)

  it('reports missing directories and propagates plugin errors', function()
    local fs_root = n.fn.fnamemodify(root, ':p'):match('^%a:[/\\]') or '/'
    t.matches('Expected a package directory:', t.pcall_err(api.nvim__packadd, fs_root, false))
    t.matches(
      'Package directory does not exist:',
      t.pcall_err(api.nvim__packadd, root .. '/missing', false)
    )
    t.write_file(package_path .. '/plugin/error.lua', 'error("package load failed")')
    t.matches('package load failed', t.pcall_err(api.nvim__packadd, package_path, true))
  end)
end)
