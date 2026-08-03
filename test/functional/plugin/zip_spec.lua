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

local function clear_zip()
  n.clear({ args = { '--clean' } })
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

  --- Copy an archive into the test directory and return its path.
  local function stage(source_dir, source, as)
    local target = vim.fs.joinpath(root, as or source)
    assert(vim.uv.fs_copyfile(vim.fs.joinpath(source_dir, source), target))
    return target
  end

  --- Stage the browsing fixture, restart, and open it.
  local function browse(as)
    local archive = stage(fixtures, 'browser.zip', as)
    clear_zip()
    edit(archive)
    return archive
  end

  before_each(function()
    t.skip(vim.fn.executable('unzip') == 0, 'unzip not available')
    root = vim.fs.normalize(t.tmpname(false) .. ' space%#')
    t.mkdir(root)
  end)

  after_each(function()
    n.rmdir(root)
  end)

  describe('activation', function()
    it('uses zip.lua by default', function()
      browse()

      eq('folder/', lines()[1])
      eq(true, exec_lua('return vim.g.loaded_nvim_zip_plugin == true'))
      eq(false, exec_lua('return vim.g.loaded_zipPlugin ~= nil'))
    end)

    it('defers to zipPlugin.vim loaded before startup plugins', function()
      local archive = stage(old_samples, 'test.zip', 'legacy.zip')
      n.clear({ args = { '--clean', '--cmd', 'packadd old-zip' } })

      edit(archive)

      eq(true, lines()[1]:find('" zip.vim version', 1, true) ~= nil)
      eq(0, fn.exists('#nvim.zip'))
      eq(false, exec_lua('return vim.g.loaded_nvim_zip_plugin ~= nil'))
    end)

    it('yields to zipPlugin.vim loaded after startup', function()
      local archive = stage(old_samples, 'test.zip', 'legacy.zip')
      clear_zip()
      exec_lua([[vim.cmd.packadd('old-zip')]])

      edit(archive)

      eq(true, lines()[1]:find('" zip.vim version', 1, true) ~= nil)
      eq(1, fn.exists('#nvim.zip'))
      eq(true, exec_lua('return vim.g.loaded_nvim_zip_plugin == true'))
    end)

    it('can be disabled', function()
      local archive = stage(fixtures, 'browser.zip')
      n.clear({
        args = { '--clean', '--cmd', 'let g:loaded_nvim_zip_plugin = 1' },
      })

      edit(archive)

      eq(0, fn.exists('#nvim.zip'))
      eq('', api.nvim_get_option_value('filetype', { buf = 0 }))
    end)

    it('can source zip.lua repeatedly', function()
      clear_zip()

      -- Re-sourcing must reuse the augroup rather than stack duplicate autocmds.
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

    it('reports an unavailable backend without claiming the buffer', function()
      local archive = stage(fixtures, 'browser.zip')
      clear_zip()
      exec_lua([[vim.env.PATH = '']])

      edit(archive)
      poke_eventloop()

      eq(true, exec_capture('messages'):find('unzip executable not found', 1, true) ~= nil)
      eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
    end)
  end)

  describe('browsing', function()
    it('opens zip-compatible file types', function()
      browse('browser.jar')

      eq('folder/', lines()[1])
      eq('zip', api.nvim_get_option_value('filetype', { buf = 0 }))
    end)

    it('browses directories and opens entries', function()
      browse()

      eq({
        'folder/',
        'inner.zip',
        '../escape.txt',
        '/absolute.txt',
        'crlf.txt',
        'noeol.txt',
        'names/',
      }, lines())
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

    it('opens the containing directory from the archive root', function()
      browse()
      feed('-')
      poke_eventloop()

      eq(root, vim.fs.normalize(api.nvim_buf_get_name(0)))
      eq('browser.zip', api.nvim_get_current_line())
      eq('directory', api.nvim_get_option_value('filetype', { buf = 0 }))
    end)

    it('opens entries at quickfix locations', function()
      local archive = stage(fixtures, 'browser.zip')
      clear_zip()
      local uri = ('zip://%s/crlf.txt'):format(archive)
      fn.setqflist({}, 'r', { items = { { filename = uri, lnum = 2, col = 1 } } })

      api.nvim_cmd({ cmd = 'cfirst' }, {})

      eq(uri, api.nvim_buf_get_name(0))
      eq({ 2, 0 }, api.nvim_win_get_cursor(0))
      eq('text', api.nvim_get_option_value('filetype', { buf = 0 }))
    end)

    it('does not reinterpret an entry ending in .zip as an archive', function()
      browse()
      api.nvim_win_set_cursor(0, { line_of('inner.zip'), 0 })
      feed('<CR>')
      poke_eventloop()

      eq({ 'nested payload' }, lines())
      eq(false, exec_lua('return vim.b.nvim_dir ~= nil'))
    end)

    it('preserves normal file reading details for entries', function()
      local archive = stage(fixtures, 'browser.zip')
      clear_zip()

      edit(('zip://%s/crlf.txt'):format(archive))
      eq({ 'one', 'two' }, lines())
      eq('dos', api.nvim_get_option_value('fileformat', { buf = 0 }))
      eq(true, api.nvim_get_option_value('endofline', { buf = 0 }))

      edit(('zip://%s/noeol.txt'):format(archive))
      eq({ 'no final newline' }, lines())
      eq(false, api.nvim_get_option_value('endofline', { buf = 0 }))
    end)

    it('keeps suspicious entry paths visible and readable', function()
      browse()
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

    it('lists a valid empty archive as empty', function()
      local archive = vim.fs.joinpath(root, 'empty.zip')
      local file = assert(io.open(archive, 'wb'))
      -- An end-of-central-directory record with no entries: a valid, empty archive.
      file:write('PK\5\6' .. string.rep('\0', 18))
      file:close()
      clear_zip()

      edit(archive)

      eq({ '' }, lines())
      eq('zip', api.nvim_get_option_value('filetype', { buf = 0 }))
      eq(true, exec_lua('return vim.b.nvim_zip ~= nil'))
    end)

    it('keeps the current level when reload fails', function()
      local archive = browse()
      feed('<CR>')
      poke_eventloop()
      eq({ 'nested/', 'root.txt', 'root.java' }, lines())

      assert(os.remove(archive))
      feed('R')
      poke_eventloop()
      eq({ 'nested/', 'root.txt', 'root.java' }, lines())

      stage(fixtures, 'browser.zip')
      feed('R')
      poke_eventloop()
      eq({ 'nested/', 'root.txt', 'root.java' }, lines())
    end)

    it('integrates Java sources with zip.lua and zipPlugin.vim', function()
      local archive = stage(fixtures, 'browser.zip', 'source.jar')

      for _, legacy in ipairs({ false, true }) do
        if legacy then
          n.clear({ args = { '--clean', '--cmd', 'packadd old-zip' } })
        else
          clear_zip()
        end
        exec_lua('vim.g.ftplugin_java_source_path = ...', archive)
        api.nvim_buf_set_name(0, vim.fs.joinpath(root, 'Test.java'))
        api.nvim_buf_set_lines(0, 0, -1, false, { 'folder.root' })
        api.nvim_cmd({ cmd = 'setfiletype', args = { 'java' } }, {})
        api.nvim_cmd({ cmd = 'runtime', args = { 'ftplugin/java.vim' } }, {})

        feed('gf')
        poke_eventloop()

        local uri = legacy and ('zipfile://%s::folder/root.java'):format(archive)
          or ('zip://%s/folder/root.java'):format(archive)
        eq(uri, api.nvim_buf_get_name(0))
        eq({ 'class root {}' }, lines())
        eq('java', api.nvim_get_option_value('filetype', { buf = 0 }))
      end
    end)
  end)

  -- Info-ZIP expands globs itself and reads leading dashes as options, so archive
  -- and entry paths must always reach it as literal text.
  describe('backend arguments', function()
    it('reads entry selectors literally', function()
      t.skip(t.is_os('win'), 'N/A: archive contains backslashes in entry paths')
      local archive = stage(old_samples, 'testa.zip', 'special.zip')
      clear_zip()

      local cases = {
        { 'zipglob/a[a].txt', 'a test file with []' },
        { 'zipglob/a*.txt', 'a test file with a*' },
        { 'zipglob/a?.txt', 'a test file with a?' },
        { [[zipglob/a\.txt]], [[a test file with a\]] },
        { [[zipglob/a\\.txt]], [[a test file with a double \]] },
      }
      for _, case in ipairs(cases) do
        edit(('zip://%s/%s'):format(archive, case[1]))
        eq({ case[2] }, lines())
      end
    end)

    it('runs the backend when the cwd is its directory', function()
      t.skip(t.is_os('win'), 'N/A: Windows searches the cwd before $PATH')
      local archive = stage(fixtures, 'browser.zip')
      local bin = vim.fs.joinpath(assert(vim.uv.fs_realpath(root)), 'bin')
      t.mkdir(bin)
      assert(vim.uv.fs_symlink(vim.fn.exepath('unzip'), vim.fs.joinpath(bin, 'unzip')))
      n.clear({ args = { '--clean' }, env = { PATH = bin .. ':' .. os.getenv('PATH') } })

      api.nvim_set_current_dir(bin)
      edit(archive)
      eq('folder/', lines()[1])
    end)

    it('keeps a leading dash in a path from becoming a backend option', function()
      local archive = stage(old_samples, 'poc.zip')
      clear_zip()

      edit(archive)
      eq({ '-d/', 'pwned' }, lines())

      edit(('zip://%s/-d/tmp'):format(archive))
      eq({ '' }, lines())
    end)

    it('treats archive glob characters literally', function()
      t.skip(t.is_os('win'), 'N/A: Windows filenames cannot contain these characters')
      local archive = stage(fixtures, 'browser.zip', 'archive::[*?].zip')
      -- Would be matched instead of the archive above if the name were globbed.
      stage(old_samples, 'test.zip', 'archivex.zip')
      clear_zip()

      edit(archive)

      eq('folder/', lines()[1])
      api.nvim_win_set_cursor(0, { line_of('inner.zip'), 0 })
      feed('<CR>')
      poke_eventloop()
      eq({ 'nested payload' }, lines())

      local uri = ('zip://%s/crlf.txt'):format(archive)
      edit(uri)
      eq(uri, api.nvim_buf_get_name(0))
      eq({ 'one', 'two' }, lines())
    end)

    it('lists and opens entries with difficult names', function()
      t.skip(t.is_os('win'), 'N/A: Windows filenames cannot contain these characters')
      local archive = browse()

      -- "star*" and "-dash" are the glob and option cases; the rest are shell
      -- metacharacters that must survive an argv-based backend untouched.
      local names = {
        'space name.txt',
        'two  spaces.txt',
        ' leading.txt',
        'trailing .txt',
        [[back\slash.txt]],
        [[single'quote.txt]],
        'double"quote.txt',
        'dollar$name.txt',
        'backtick`name.txt',
        'semi;name.txt',
        'pipe|name.txt',
        'amp&name.txt',
        'paren(name).txt',
        'bang!name.txt',
        'hash#name.txt',
        'percent%name.txt',
        'star*.txt',
        'question?.txt',
        '[bracket].txt',
        '-dash.txt',
      }

      api.nvim_win_set_cursor(0, { line_of('names/'), 0 })
      feed('<CR>')
      poke_eventloop()
      eq(names, lines())

      api.nvim_win_set_cursor(0, { line_of('star*.txt'), 0 })
      feed('<CR>')
      poke_eventloop()
      eq(('zip://%s/names/star*.txt'):format(archive), api.nvim_buf_get_name(0))
      eq({ 'content of star*.txt' }, lines())

      for _, name in ipairs(names) do
        edit(('zip://%s/names/%s'):format(archive, name))
        eq({ 'content of ' .. name }, lines())
      end
    end)
  end)

  it('prompts for the password of an encrypted archive', function()
    local archive = stage(fixtures, 'encrypted.zip')
    clear_zip()

    edit(archive)
    eq({ 'secret.txt' }, lines())

    -- The password is queued first, so that the prompt consumes it from typeahead.
    exec_lua(function(uri)
      vim.api.nvim_input('hunter2<CR>')
      vim.api.nvim_cmd({ cmd = 'edit', args = { uri }, magic = { file = false, bar = false } }, {})
    end, ('zip://%s/secret.txt'):format(archive))
    poke_eventloop()

    eq({ 'secret content' }, lines())
  end)

  it('reports an incorrect archive password', function()
    local archive = stage(fixtures, 'encrypted.zip')
    clear_zip()

    -- Info-ZIP allows three attempts before giving up.
    exec_lua(function(uri)
      vim.api.nvim_input('no1<CR>no2<CR>no3<CR>')
      vim.api.nvim_cmd({ cmd = 'edit', args = { uri }, magic = { file = false, bar = false } }, {})
    end, ('zip://%s/secret.txt'):format(archive))
    poke_eventloop()

    eq(true, exec_capture('messages'):find('incorrect password', 1, true) ~= nil)
  end)

  describe('extract', function()
    --- Stage an archive, restart with the cwd inside the test directory, and open it.
    local function open_in_cwd(source_dir, source)
      local archive = stage(source_dir, source)
      clear_zip()
      api.nvim_set_current_dir(root)
      edit(archive)
      return archive
    end

    it('extracts the entry under the cursor into the current directory', function()
      open_in_cwd(fixtures, 'browser.zip')
      feed('<CR>')
      poke_eventloop()
      api.nvim_win_set_cursor(0, { line_of('root.java'), 0 })
      feed('x')
      poke_eventloop()

      eq('class root {}\n', t.read_file(vim.fs.joinpath(root, 'root.java')))
    end)

    it('refuses to extract a directory', function()
      open_in_cwd(fixtures, 'browser.zip')
      api.nvim_win_set_cursor(0, { line_of('folder/'), 0 })
      feed('x')
      poke_eventloop()

      eq(true, exec_capture('messages'):find('not a directory', 1, true) ~= nil)
      eq(nil, vim.uv.fs_stat(vim.fs.joinpath(root, 'folder')))
    end)

    it('refuses to overwrite an existing file when extracting', function()
      local target = vim.fs.joinpath(root, 'root.java')
      stage(fixtures, 'browser.zip')
      t.write_file(target, 'untouched', true)
      clear_zip()
      api.nvim_set_current_dir(root)

      edit(vim.fs.joinpath(root, 'browser.zip'))
      feed('<CR>')
      poke_eventloop()
      api.nvim_win_set_cursor(0, { line_of('root.java'), 0 })
      feed('x')
      poke_eventloop()

      eq(true, exec_capture('messages'):find('already exists', 1, true) ~= nil)
      eq('untouched', t.read_file(target))
    end)

    it('extracts suspicious entries without escaping the current directory', function()
      open_in_cwd(old_samples, 'evil.zip')

      eq({
        '../../../../etc/ax-pwn',
        'a/../../../../../../../../../../../../../../../../../../tmp/foobar',
        '/tmp/vim_zip/a/b/payload.txt',
      }, lines())

      for _, entry in ipairs(lines()) do
        api.nvim_win_set_cursor(0, { line_of(entry), 0 })
        feed('x')
        poke_eventloop()
      end

      -- Each lands flat in the cwd, never at the path the entry asked for.
      for _, name in ipairs({ 'ax-pwn', 'foobar', 'payload.txt' }) do
        eq(true, vim.uv.fs_stat(vim.fs.joinpath(root, name)) ~= nil)
      end
      eq(nil, vim.uv.fs_stat(vim.fs.joinpath(root, '..', 'ax-pwn')))
    end)
  end)
end)
