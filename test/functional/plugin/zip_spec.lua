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

local fixtures = vim.fs.joinpath(t.paths.test_source_path, 'test/functional/fixtures/zip')
local old_samples = vim.fs.joinpath(t.paths.test_source_path, 'test/old/testdir/samples')

local function lines()
  return api.nvim_buf_get_lines(0, 0, -1, false)
end

local function edit(path)
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

---@param value? string
local function clear_zip(value)
  n.clear({
    args_rm = { '-u' },
    args = { '--cmd', ('let g:nvim_zip_plugin = %s'):format(value or '1') },
  })
end

local function copy_fixture(source, target)
  assert(vim.uv.fs_copyfile(source, target))
end

local function line_of(text)
  for i, line in ipairs(lines()) do
    if line == text then
      return i
    end
  end
  error(('missing line %q in %s'):format(text, vim.inspect(lines())))
end

describe('nvim.zip', function()
  local root

  before_each(function()
    t.skip(vim.fn.executable('unzip') == 0, 'unzip not available')
    root = vim.fs.normalize(t.tmpname(false) .. ' space%#')
    t.mkdir(root)
  end)

  after_each(function()
    n.rmdir(root)
  end)

  it('leaves the Vim plugin enabled by default', function()
    local archive = vim.fs.joinpath(root, 'legacy.zip')
    copy_fixture(vim.fs.joinpath(old_samples, 'test.zip'), archive)
    n.clear({ args_rm = { '-u' } })

    edit(archive)

    eq(true, lines()[1]:find('" zip.vim version', 1, true) ~= nil)
    eq(false, exec_lua('return vim.g.nvim_zip_plugin == true'))
  end)

  it('selects the Lua plugin with true values only', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)

    for _, case in ipairs({
      { value = '0', lua = false },
      { value = 'v:false', lua = false },
      { value = "''", lua = false },
      { value = '1', lua = true },
      { value = 'v:true', lua = true },
    }) do
      clear_zip(case.value)
      edit(archive)

      eq(case.lua, lines()[1] == 'folder/')
      eq(not case.lua, exec_lua('return vim.g.loaded_zipPlugin ~= nil'))
      eq(
        case.lua and 2 or 0,
        exec_lua(function()
          local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = 'nvim.zip' })
          local ids = {}
          for _, autocmd in ipairs(ok and autocmds or {}) do
            ids[autocmd.id] = true
          end
          return vim.tbl_count(ids)
        end)
      )
    end
  end)

  it('can source the Lua plugin repeatedly', function()
    clear_zip()

    eq(
      2,
      exec_lua(function()
        vim.cmd.runtime('plugin/zip.lua')
        vim.cmd.runtime('plugin/zip.lua')
        local ids = {}
        for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = 'nvim.zip' })) do
          ids[autocmd.id] = true
        end
        return vim.tbl_count(ids)
      end)
    )
  end)

  it('opens zip-compatible file types', function()
    local archive = vim.fs.joinpath(root, 'browser.jar')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(archive)

    eq('folder/', lines()[1])
    eq('zip', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('browses directories and opens members', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(archive)

    eq(
      { 'folder/', 'inner.zip', '../escape.txt', '/absolute.txt', 'crlf.txt', 'noeol.txt' },
      lines()
    )
    eq('zip', api.nvim_get_option_value('filetype', { buf = 0 }))
    eq(true, exec_capture('syntax list zipDirectory'):find('zipDirectory', 1, true) ~= nil)

    feed('<CR>')
    poke_eventloop()
    eq({ 'nested/', 'root.txt', 'root.java' }, lines())

    feed('<CR>')
    poke_eventloop()
    eq({ 'file.txt' }, lines())

    feed('-')
    poke_eventloop()
    eq({ 'nested/', 'root.txt', 'root.java' }, lines())
    eq('nested/', api.nvim_get_current_line())

    api.nvim_win_set_cursor(0, { 2, 0 })
    feed('<CR>')
    poke_eventloop()
    eq({ 'root text' }, lines())
    eq('nowrite', api.nvim_get_option_value('buftype', { buf = 0 }))
    eq(true, api.nvim_get_option_value('readonly', { buf = 0 }))
    eq(false, api.nvim_get_option_value('modifiable', { buf = 0 }))
    eq(false, api.nvim_get_option_value('swapfile', { buf = 0 }))
  end)

  it('does not reinterpret a member ending in .zip as an archive', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(archive)
    api.nvim_win_set_cursor(0, { line_of('inner.zip'), 0 })
    feed('<CR>')
    poke_eventloop()

    eq({ 'nested payload' }, lines())
    eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
  end)

  it('preserves normal file reading details for members', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(('zipfile://%s::crlf.txt'):format(archive))
    eq({ 'one', 'two' }, lines())
    eq('dos', api.nvim_get_option_value('fileformat', { buf = 0 }))
    eq(true, api.nvim_get_option_value('endofline', { buf = 0 }))

    edit(('zipfile://%s::noeol.txt'):format(archive))
    eq({ 'no final newline' }, lines())
    eq(false, api.nvim_get_option_value('endofline', { buf = 0 }))
  end)

  it('opens Java sources from a configured archive', function()
    local archive = vim.fs.joinpath(root, 'source.jar')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()
    exec_lua('vim.g.ftplugin_java_source_path = ...', archive)
    api.nvim_buf_set_name(0, vim.fs.joinpath(root, 'Test.java'))
    api.nvim_buf_set_lines(0, 0, -1, false, { 'folder.root' })
    api.nvim_cmd({ cmd = 'setfiletype', args = { 'java' } }, {})
    api.nvim_cmd({ cmd = 'runtime', args = { 'ftplugin/java.vim' } }, {})

    feed('gf')
    poke_eventloop()

    eq(('zipfile://%s::folder/root.java'):format(archive), api.nvim_buf_get_name(0))
    eq({ 'class root {}' }, lines())
    eq('java', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('reads member selectors literally', function()
    t.skip(t.is_os('win'), 'N/A: archive contains backslashes in member names')
    local archive = vim.fs.joinpath(root, 'special.zip')
    copy_fixture(vim.fs.joinpath(old_samples, 'testa.zip'), archive)
    clear_zip()

    local cases = {
      { 'zipglob/a[a].txt', 'a test file with []' },
      { 'zipglob/a*.txt', 'a test file with a*' },
      { 'zipglob/a?.txt', 'a test file with a?' },
      { [[zipglob/a\.txt]], [[a test file with a\]] },
      { [[zipglob/a\\.txt]], [[a test file with a double \]] },
    }
    for _, case in ipairs(cases) do
      edit(('zipfile://%s::%s'):format(archive, case[1]))
      eq({ case[2] }, lines())
    end
  end)

  it('treats archive glob characters literally', function()
    t.skip(t.is_os('win'), 'N/A: Windows filenames cannot contain these characters')
    local archive = vim.fs.joinpath(root, 'archive::[*?].zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    copy_fixture(vim.fs.joinpath(old_samples, 'test.zip'), vim.fs.joinpath(root, 'archivex.zip'))
    clear_zip()

    edit(archive)

    eq('folder/', lines()[1])
    api.nvim_win_set_cursor(0, { line_of('inner.zip'), 0 })
    feed('<CR>')
    poke_eventloop()
    eq({ 'nested payload' }, lines())

    local uri = ('zipfile://%s::crlf.txt'):format(archive)
    edit(uri)
    eq(uri, api.nvim_buf_get_name(0))
    eq({ 'one', 'two' }, lines())
  end)

  it('keeps suspicious member paths visible and readable', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(archive)
    api.nvim_win_set_cursor(0, { line_of('../escape.txt'), 0 })
    feed('<CR>')
    poke_eventloop()

    eq({ 'escape payload' }, lines())
  end)

  it('opens non-zip files normally', function()
    local archive = vim.fs.joinpath(root, 'plain.zip')
    t.write_file(archive, 'plain text', true)
    clear_zip()

    edit(archive)

    eq({ 'plain text' }, lines())
    eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
  end)

  it('keeps the current level when reload fails', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()

    edit(archive)
    feed('<CR>')
    poke_eventloop()
    eq({ 'nested/', 'root.txt', 'root.java' }, lines())

    assert(os.remove(archive))
    feed('R')
    poke_eventloop()
    eq({ 'nested/', 'root.txt', 'root.java' }, lines())

    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    feed('R')
    poke_eventloop()
    eq({ 'nested/', 'root.txt', 'root.java' }, lines())
  end)

  it('reports an unavailable backend without claiming the buffer', function()
    local archive = vim.fs.joinpath(root, 'browser.zip')
    copy_fixture(vim.fs.joinpath(fixtures, 'browser.zip'), archive)
    clear_zip()
    exec_lua([[vim.env.PATH = '']])

    edit(archive)
    poke_eventloop()

    eq(true, exec_capture('messages'):find('unzip executable not found', 1, true) ~= nil)
    eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
  end)
end)
