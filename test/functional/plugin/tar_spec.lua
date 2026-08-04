local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local api = n.api
local eq = t.eq
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local poke_eventloop = n.poke_eventloop

local old_samples = vim.fs.joinpath(t.paths.test_source_path, 'test/old/testdir/samples')

local function lines()
  return api.nvim_buf_get_lines(0, 0, -1, false)
end

local function edit(path)
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

local function clear_tar()
  n.clear({ args = { '--clean' } })
end

describe('nvim.tar', function()
  local root

  --- Copy an archive into the test directory and return its path.
  local function stage(source, as)
    local target = vim.fs.joinpath(root, as or source)
    assert(vim.uv.fs_copyfile(vim.fs.joinpath(old_samples, source), target))
    return target
  end

  --- Stage the sample archive, restart, and open it.
  local function browse(as)
    local archive = stage('sample.tar', as)
    clear_tar()
    edit(archive)
    return archive
  end

  before_each(function()
    t.skip(vim.fn.executable('tar') == 0, 'tar not available')
    root = vim.fs.normalize(t.tmpname(false) .. ' space%#')
    t.mkdir(root)
  end)

  after_each(function()
    n.rmdir(root)
  end)

  it('uses tar.lua by default', function()
    browse()

    eq('testtar/', lines()[1])
    eq(true, exec_lua('return vim.g.loaded_nvim_tar_plugin == true'))
    eq(false, exec_lua('return vim.g.loaded_tarPlugin ~= nil'))
  end)

  it('defers to tarPlugin.vim loaded before startup plugins', function()
    local archive = stage('sample.tar', 'legacy.tar')
    n.clear({ args = { '--clean', '--cmd', 'packadd old-tar' } })

    edit(archive)

    eq(true, lines()[1]:find('" tar.vim version', 1, true) ~= nil)
    eq(0, fn.exists('#nvim.tar'))
    eq(false, exec_lua('return vim.g.loaded_nvim_tar_plugin ~= nil'))
  end)

  it('yields to tarPlugin.vim loaded after startup', function()
    local archive = stage('sample.tar', 'legacy.tar')
    clear_tar()
    exec_lua([[vim.cmd.packadd('old-tar')]])

    edit(archive)

    eq(true, lines()[1]:find('" tar.vim version', 1, true) ~= nil)
    eq(1, fn.exists('#nvim.tar'))
    eq(true, exec_lua('return vim.g.loaded_nvim_tar_plugin == true'))
  end)

  it('can be disabled', function()
    local archive = stage('sample.tar')
    n.clear({ args = { '--clean', '--cmd', 'let g:loaded_nvim_tar_plugin = 1' } })

    edit(archive)

    eq(0, fn.exists('#nvim.tar'))
    eq('', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('can source tar.lua repeatedly', function()
    clear_tar()

    -- Re-sourcing must reuse the augroup rather than stack duplicate autocmds.
    eq(
      2,
      exec_lua(function()
        vim.cmd.runtime('plugin/tar.lua')
        vim.cmd.runtime('plugin/tar.lua')
        local ids = {}
        for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = 'nvim.tar' })) do
          ids[autocmd.id] = true
        end
        return vim.tbl_count(ids)
      end)
    )
  end)

  it('opens tar-compatible file types', function()
    local payload = vim.fs.joinpath(root, 'payload')
    t.mkdir(payload)
    t.write_file(vim.fs.joinpath(payload, 'file.txt'), 'compressed\n', true)
    local archive = vim.fs.joinpath(root, 'sample.tgz')
    eq(0, vim.system({ 'tar', '-c', '-z', '-f', archive, '-C', root, 'payload' }):wait().code)
    clear_tar()

    edit(archive)

    eq('payload/', lines()[1])
    eq('tar', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('browses directories and opens entries', function()
    browse()

    eq({ 'testtar/' }, lines())
    eq('tar', api.nvim_get_option_value('filetype', { buf = 0 }))

    feed('<CR>')
    poke_eventloop()
    eq({ 'file1.txt' }, lines())

    feed('<CR>')
    poke_eventloop()
    eq({ 'testfile' }, lines())
    eq(false, api.nvim_get_option_value('modifiable', { buf = 0 }))
  end)

  it('opens the containing directory from the archive root', function()
    browse()
    feed('-')
    poke_eventloop()

    eq(root, vim.fs.normalize(api.nvim_buf_get_name(0)))
    eq('sample.tar', api.nvim_get_current_line())
    eq('directory', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('opens entries at quickfix locations', function()
    local archive = stage('sample.tar')
    clear_tar()
    local uri = ('nvim-tar://%s/testtar/file1.txt'):format(archive)
    fn.setqflist({}, 'r', { items = { { filename = uri, lnum = 1, col = 1 } } })

    api.nvim_cmd({ cmd = 'cfirst' }, {})

    eq(uri, api.nvim_buf_get_name(0))
    eq({ 'testfile' }, lines())
  end)

  it('keeps suspicious entry paths visible and readable', function()
    local archive = stage('evil.tar')
    clear_tar()

    edit(archive)
    eq({ '/etc/ax-pwn' }, lines())

    feed('<CR>')
    poke_eventloop()
    eq({ 'something' }, lines())
  end)

  it('opens non-tar files normally', function()
    local archive = vim.fs.joinpath(root, 'plain.tar')
    t.write_file(archive, 'plain text', true)
    clear_tar()

    edit(archive)

    eq({ 'plain text' }, lines())
    eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
  end)

  it('reports an unavailable backend without claiming the buffer', function()
    local archive = stage('sample.tar')
    clear_tar()
    exec_lua([[vim.env.PATH = '']])

    edit(archive)
    poke_eventloop()

    eq(true, exec_capture('messages'):find('tar executable not found', 1, true) ~= nil)
    eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
  end)
end)
