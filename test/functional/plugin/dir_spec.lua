local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, after_each, pending, finally =
  t.describe, t.it, t.after_each, t.pending, t.finally
local api = n.api
local command = n.command
local eq = t.eq
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local ok = t.ok
local poke_eventloop = n.poke_eventloop

local function lines()
  return api.nvim_buf_get_lines(0, 0, -1, true)
end

local function edit(path)
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

local function cd(path)
  api.nvim_cmd({ cmd = 'cd', args = { path }, magic = { file = false, bar = false } }, {})
end

local function line_of(text)
  for i, line in ipairs(lines()) do
    if line == text then
      return i
    end
  end
  error(('missing line %q in %s'):format(text, vim.inspect(lines())))
end

local function bufopt(name)
  return api.nvim_get_option_value(name, { buf = 0 })
end

local function has_syntax_group(name)
  return exec_capture('syntax list ' .. name):find(name, 1, true) ~= nil
end

local function assert_directory(path)
  local ffname = path:sub(-1) == '/' and path or path .. '/'
  eq(ffname, api.nvim_buf_get_name(0))
  eq(path, vim.fs.normalize(fn.fnamemodify(fn.bufname('%'), ':p')))
  eq('directory', bufopt('filetype'))
  eq(true, bufopt('buflisted'))
end

local function filesystem_root(path)
  local root = vim.fs.normalize(vim.fs.abspath(path))
  for parent in vim.fs.parents(root) do
    root = parent
  end
  return root
end

local function write_config_plugin(path, text)
  local plugin_file = vim.fs.joinpath(vim.fn.stdpath('config'), path)
  vim.fs.mkdir(vim.fs.dirname(plugin_file), { parents = true })
  finally(function()
    os.remove(plugin_file)
  end)
  t.write_file(plugin_file, text)
end

---@param args? string[]
---@return string[]
local function with_buftype_optionset(args)
  return vim.list_extend({
    '--clean',
    '--cmd',
    'let g:nvim_dir_events = []',
    '--cmd',
    [[autocmd OptionSet buftype call add(g:nvim_dir_events, v:option_new)]],
  }, args or {})
end

local function expect_buftype_optionset(path)
  assert_directory(path)
  eq({ 'nowrite' }, exec_lua('return vim.g.nvim_dir_events'))
end

describe('nvim.dir', function()
  local root
  local subdir
  local file

  local function make_fixture()
    root = vim.fs.normalize(t.tmpname(false) .. ' space%#')
    subdir = root .. '/subdir'
    file = root .. '/alpha.txt'
    t.mkdir(root)
    t.mkdir(subdir)
    t.write_file(file, 'alpha', true)
    t.write_file(root .. '/.hidden', 'hidden', true)
  end

  after_each(function()
    if root then
      n.rmdir(root)
    end
    root = nil
  end)

  it('opens a startup directory argument', function()
    make_fixture()
    n.clear({ args = { '--clean', root } })

    assert_directory(root)
    eq(false, vim.tbl_contains(lines(), '../'))
    eq('subdir/', lines()[1])
    line_of('.hidden')
    line_of('alpha.txt')
  end)

  it('3P dir-browser can handle `FileType directory` event and rename buf', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    exec_lua(function()
      _G.nvim_dir_loaded_in_filetype = nil
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'directory',
        callback = function(ev)
          _G.nvim_dir_loaded_in_filetype = package.loaded['nvim.dir'] ~= nil
          local dir = vim.api.nvim_buf_get_name(ev.buf)
          local browser = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_name(browser, 'example://' .. dir)
          vim.api.nvim_buf_set_lines(browser, 0, -1, false, {
            'plugin browser for: ' .. dir,
          })
          vim.api.nvim_set_current_buf(browser)
          vim.api.nvim_buf_delete(ev.buf, { force = true })
        end,
      })
    end)

    edit(root)

    eq(false, exec_lua('return _G.nvim_dir_loaded_in_filetype'))
    eq('example://' .. root .. '/', api.nvim_buf_get_name(0))
    eq({ 'plugin browser for: ' .. root .. '/' }, lines())
    eq(false, exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    eq('', exec_capture('messages'))
  end)

  it('triggers nested autocmds when opening directory buffers', function()
    make_fixture()

    n.clear({
      args = with_buftype_optionset({ root }),
    })
    expect_buftype_optionset(root)

    n.clear({
      args = with_buftype_optionset(),
    })
    edit(root)
    expect_buftype_optionset(root)
  end)

  it('handles nested autocmds deleting the directory buffer', function()
    make_fixture()
    n.clear({
      args = {
        '--clean',
        '--cmd',
        'let g:nvim_dir_wiped = 0',
        '--cmd',
        [[autocmd OptionSet buftype let g:nvim_dir_wiped = 1 | bwipeout!]],
        root,
      },
    })

    eq(1, exec_lua('return vim.g.nvim_dir_wiped'))
    eq('', exec_capture('messages'))
  end)

  it('does not load the module until opening a directory', function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    eq(false, exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    edit(root)
    eq(true, exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    assert_directory(root)
  end)

  it('opens a custom listing provider', function()
    n.clear({ args = { '--clean' } })

    exec_lua(function()
      require('nvim.dir').open(0, 'custom://root', {
        list = function(_, name, cb)
          vim.g.nvim_dir_list_name = name
          cb(nil, {
            { name = 'child', dir = true },
            { name = 'file.txt', dir = false },
          })
        end,
        open = function(_, name, entry)
          vim.g.nvim_dir_opened = entry.name .. ':' .. name
        end,
        open_parent = function(_, name)
          vim.g.nvim_dir_parent = name
        end,
        init = function(buf)
          vim.bo[buf].filetype = 'customdir'
        end,
      })
    end)

    eq('custom://root', api.nvim_buf_get_name(0))
    eq('customdir', bufopt('filetype'))
    eq({ 'child/', 'file.txt' }, lines())
    eq('custom://root', exec_lua('return vim.g.nvim_dir_list_name'))

    api.nvim_win_set_cursor(0, { 2, 0 })
    api.nvim_set_option_value('modifiable', true, { buf = 0 })
    api.nvim_set_current_line('renamed.txt')
    feed('<CR>')
    poke_eventloop()
    eq('renamed.txt:custom://root', exec_lua('return vim.g.nvim_dir_opened'))

    feed('-')
    poke_eventloop()
    eq('custom://root', exec_lua('return vim.g.nvim_dir_parent'))
  end)

  it('reports custom listing provider errors', function()
    n.clear({ args = { '--clean' } })

    exec_lua(function()
      require('nvim.dir').open(0, 'custom://error', {
        list = function(buf, _, cb)
          vim.b[buf].custom_fail = (vim.b[buf].custom_fail or 0) + 1
          if vim.b[buf].custom_fail == 1 then
            cb('simulated error')
          else
            cb(nil, { { name = 'recovered.txt', dir = false } })
          end
        end,
        open = function() end,
        open_parent = function() end,
      })
    end)

    ok(exec_capture('messages'):find('simulated error', 1, true) ~= nil)
    -- A failed initial load renders an empty listing that "R" can retry.
    eq('simulated error', exec_lua([[return vim.b.nvim_dir.err]]))
    eq({ '' }, lines())
    eq('nowrite', bufopt('buftype'))
    eq(false, bufopt('modifiable'))
    feed('R')
    poke_eventloop()
    eq({ 'recovered.txt' }, lines())
    eq(vim.NIL, exec_lua([[return vim.b.nvim_dir.err]]))
  end)

  it('failed directory open does not repeat the error on every BufEnter', function()
    t.skip(t.is_os('win'), 'directory permissions are POSIX-only')
    t.skip(vim.uv.getuid() == 0, 'root ignores directory permissions')
    n.clear({ args = { '--clean' } })
    make_fixture()
    local locked = root .. '/locked'
    t.mkdir(locked)
    finally(function()
      vim.uv.fs_chmod(locked, tonumber('755', 8))
    end)
    vim.uv.fs_chmod(locked, 0)

    edit(root)
    api.nvim_win_set_cursor(0, { line_of('locked/'), 0 })
    feed('<CR>')
    poke_eventloop()
    local function count_errors()
      local _, n_errors = exec_capture('messages'):gsub('EACCES', '')
      return n_errors
    end
    eq(1, count_errors())
    ok(exec_lua([[return vim.b.nvim_dir.err]]):find('EACCES', 1, true) ~= nil)
    eq('nowrite', bufopt('buftype'))
    edit(file)
    feed('<C-^>')
    poke_eventloop()
    eq(1, count_errors())
    vim.uv.fs_chmod(locked, tonumber('755', 8))
    t.write_file(locked .. '/inside.txt', 'inside', true)
    feed('R')
    poke_eventloop()
    eq({ 'inside.txt' }, lines())
  end)

  it('does not swallow errors raised after the list callback', function()
    n.clear({ args = { '--clean' } })

    local err = exec_lua(function()
      local ok_open, e = pcall(require('nvim.dir').open, 0, 'custom://late-error', {
        list = function(_, _, cb)
          cb(nil, { { name = 'file.txt', dir = false } })
          error('late provider error')
        end,
        open = function() end,
        open_parent = function() end,
      })
      return not ok_open and tostring(e) or nil
    end)
    ok(err ~= nil and err:find('late provider error', 1, true) ~= nil)
    eq({ 'file.txt' }, lines())
  end)

  it('reloads custom listing providers', function()
    n.clear({ args = { '--clean' } })

    exec_lua(function()
      require('nvim.dir').open(0, 'custom://root', {
        list = function(buf, _, cb)
          vim.b[buf].custom_count = (vim.b[buf].custom_count or 0) + 1
          cb(nil, { { name = 'file' .. vim.b[buf].custom_count .. '.txt', dir = false } })
        end,
        open = function() end,
        open_parent = function() end,
      })
    end)

    eq({ 'file1.txt' }, lines())
    feed('R')
    poke_eventloop()
    eq({ 'file2.txt' }, lines())
  end)

  it('fires DirReadPost for every listing', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    exec_lua(function()
      vim.g.renders = 0
      vim.api.nvim_create_autocmd('User', {
        pattern = 'DirReadPost',
        callback = function(args)
          vim.g.renders = vim.g.renders + 1
          vim.g.render_lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, true)
          vim.g.render_writable = vim.bo[args.buf].modifiable and not vim.bo[args.buf].readonly
        end,
      })
    end)

    edit(root)
    eq(1, exec_lua('return vim.g.renders'))
    eq({ 'subdir/', '.hidden', 'alpha.txt' }, exec_lua('return vim.g.render_lines'))
    -- Writable while handlers run, locked again afterwards.
    eq(true, exec_lua('return vim.g.render_writable'))
    eq(false, bufopt('modifiable'))
    eq(true, bufopt('readonly'))
    eq(false, bufopt('modified'))

    feed('R')
    poke_eventloop()
    eq(2, exec_lua('return vim.g.renders'))

    edit(root)
    eq(3, exec_lua('return vim.g.renders'))

    api.nvim_win_set_cursor(0, { line_of('subdir/'), 0 })
    feed('<CR>')
    poke_eventloop()
    assert_directory(subdir)
    eq(4, exec_lua('return vim.g.renders'))
  end)

  it('keeps the listing readonly when a handler errors', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    exec_lua(function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'DirReadPost',
        callback = function()
          error('handler error')
        end,
      })
    end)

    edit(root)

    eq({ 'subdir/', '.hidden', 'alpha.txt' }, lines())
    eq(false, bufopt('modifiable'))
    eq(true, bufopt('readonly'))
  end)

  it('selects the origin entry after a handler reorders', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    exec_lua(function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'DirReadPost',
        callback = function()
          vim.cmd('silent keeppatterns sort!')
        end,
      })
    end)

    edit(subdir)
    feed('-')
    poke_eventloop()

    eq({ 'subdir/', 'alpha.txt', '.hidden' }, lines())
    eq('subdir/', api.nvim_get_current_line())
  end)

  it('ignores callbacks from replaced listings', function()
    n.clear({ args = { '--clean' } })

    exec_lua(function()
      local dir = require('nvim.dir')
      dir.open(0, 'custom://old', {
        list = function(_, _, cb)
          _G.nvim_dir_stale_callback = cb
        end,
        open = function() end,
        open_parent = function() end,
      })
      dir.open(0, 'custom://new', {
        list = function(_, _, cb)
          cb(nil, { { name = 'current.txt', dir = false } })
        end,
        open = function() end,
        open_parent = function() end,
      })
    end)

    eq('custom://new', api.nvim_buf_get_name(0))
    eq({ 'current.txt' }, lines())

    exec_lua(function()
      _G.nvim_dir_stale_callback(nil, { { name = 'stale.txt', dir = false } })
    end)

    eq('custom://new', api.nvim_buf_get_name(0))
    eq({ 'current.txt' }, lines())
  end)

  it('replaces listing providers', function()
    n.clear({ args = { '--clean' } })

    exec_lua(function()
      local dir = require('nvim.dir')
      local function provider(label)
        return {
          list = function(buf, _, cb)
            local key = 'nvim_dir_' .. label .. '_lists'
            vim.b[buf][key] = (vim.b[buf][key] or 0) + 1
            vim.g.nvim_dir_provider_list = label .. ':' .. vim.b[buf][key]
            cb(nil, { { name = label .. '.txt', dir = false } })
          end,
          open = function(_, _, entry)
            vim.g.nvim_dir_provider_open = label .. ':' .. entry.name
          end,
          open_parent = function()
            vim.g.nvim_dir_provider_parent = label
          end,
        }
      end
      dir.open(0, 'custom://old', provider('old'))
      dir.open(0, 'custom://new', provider('new'))
    end)

    eq({ 'new.txt' }, lines())
    eq('new:1', exec_lua('return vim.g.nvim_dir_provider_list'))
    for _, plug in ipairs({
      '<Plug>(nvim-dir-open)',
      '<Plug>(nvim-dir-up)',
      '<Plug>(nvim-dir-reload)',
    }) do
      eq(0, fn.maparg(plug, 'n', false, true).buffer)
    end

    feed('<CR>')
    poke_eventloop()
    eq('new:new.txt', exec_lua('return vim.g.nvim_dir_provider_open'))

    feed('-')
    poke_eventloop()
    eq('new', exec_lua('return vim.g.nvim_dir_provider_parent'))

    feed('R')
    poke_eventloop()
    eq('new:2', exec_lua('return vim.g.nvim_dir_provider_list'))
  end)

  it('maps [count]- to open directories', function()
    make_fixture()
    n.clear({ args_rm = { '--cmd' }, args = { '--clean' } })
    local cwd = vim.fs.normalize(fn.getcwd())

    edit(file)
    feed('-')
    poke_eventloop()

    assert_directory(root)
    line_of('alpha.txt')

    -- Ensure the cursor stays on the entry we navigated up from.
    eq('alpha.txt', api.nvim_get_current_line())

    edit(file)
    feed('1-')
    poke_eventloop()

    assert_directory(cwd)

    edit(file)
    feed('-')
    poke_eventloop()
    feed('1-')
    poke_eventloop()
    assert_directory(cwd)

    edit(file)
    feed('2-')
    poke_eventloop()

    assert_directory(vim.fs.dirname(root))
    eq(vim.fs.basename(root) .. '/', api.nvim_get_current_line())
  end)

  it('maps - to open the current directory from a buffer with no path', function()
    make_fixture()
    n.clear({ args_rm = { '--cmd' }, args = { '--clean' } })
    local cwd = fn.getcwd()
    command('terminal')
    eq('terminal', api.nvim_get_option_value('buftype', { buf = 0 }))
    cd(root)
    finally(function()
      cd(cwd)
    end)

    feed('-')
    poke_eventloop()

    assert_directory(root)

    command('enew')
    eq('', api.nvim_buf_get_name(0))
    feed('-')
    poke_eventloop()

    assert_directory(root)
  end)

  it('preserves a modified unnamed buffer when opening the current directory', function()
    make_fixture()
    n.clear({ args_rm = { '--cmd' }, args = { '--clean' } })
    local cwd = fn.getcwd()
    cd(root)
    finally(function()
      cd(cwd)
    end)
    local old_buf = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(old_buf, 0, -1, false, { 'unsaved' })

    feed('-')
    poke_eventloop()

    assert_directory(root)
    eq(old_buf, fn.bufnr('#'))
    eq(true, api.nvim_buf_is_valid(old_buf))
    eq(true, api.nvim_get_option_value('modified', { buf = old_buf }))
    eq({ 'unsaved' }, api.nvim_buf_get_lines(old_buf, 0, -1, false))
  end)

  it('does not shadow startup plugin `-` mappings in directory buffers', function()
    make_fixture()
    write_config_plugin(
      'plugin/dirvish.lua',
      [[
        vim.g.dirvish_up = 0
        vim.keymap.set('n', '-', function()
          vim.g.dirvish_up = vim.g.dirvish_up + 1
        end)
      ]]
    )

    -- Remove -u NONE instead of --clean, which excludes the config dir from 'runtimepath'.
    n.clear({ args_rm = { '-u', '--cmd' } })

    eq(1, fn.exists('g:loaded_nvim_dir_plugin')) -- Avoid false negatives.
    edit(root)
    assert_directory(root)
    eq(0, fn.maparg('-', 'n', false, true).buffer)

    feed('-')
    poke_eventloop()

    eq(1, exec_lua('return vim.g.dirvish_up'))
    assert_directory(root)
  end)

  it('preserves alternate buffer when opening a parent directory', function()
    make_fixture()
    n.clear({ args_rm = { '--cmd' }, args = { '--clean' } })

    edit(file)
    feed('-')
    poke_eventloop()

    assert_directory(root)
    -- Keep the alternate buffer on the file we navigated up from.
    eq(file, api.nvim_buf_get_name(fn.bufnr('#')))

    feed('-')
    poke_eventloop()
    assert_directory(vim.fs.dirname(root))
    eq(file, api.nvim_buf_get_name(fn.bufnr('#')))

    feed('<CR>')
    poke_eventloop()
    assert_directory(root)
    eq(file, api.nvim_buf_get_name(fn.bufnr('#')))

    feed('1-')
    poke_eventloop()
    eq(file, api.nvim_buf_get_name(fn.bufnr('#')))
  end)

  it('uses an absolute buffer name for a relative startup directory argument', function()
    make_fixture()
    local cwd = assert(vim.uv.cwd())
    assert(vim.uv.chdir(root))
    n.clear({ args = { '--clean', '.' } })
    assert(vim.uv.chdir(cwd))

    assert_directory(root)
  end)

  it('normalizes edited directory names', function()
    make_fixture()
    local literal = root .. '/$HOME'
    t.mkdir(literal)
    n.clear({ args = { '--clean' } })

    edit(literal .. '///')

    eq(literal .. '/', api.nvim_buf_get_name(0))
    eq('directory', bufopt('filetype'))
    eq({ '' }, lines())
  end)

  it('does not show a parent entry at the filesystem root', function()
    n.clear({ args = { '--clean' } })
    local root_dir = filesystem_root(fn.getcwd())

    edit(root_dir)

    assert_directory(root_dir)
    eq(false, vim.tbl_contains(lines(), '../'))
  end)

  it('navigates entries and refreshes the listing', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    local cwd = fn.getcwd()

    edit(root)
    assert_directory(root)
    eq(vim.uv.fs_realpath(root), vim.uv.fs_realpath(fn.getcwd()))
    eq('alpha.txt', fn.findfile('alpha.txt'))

    api.nvim_win_set_cursor(0, { line_of('alpha.txt'), 0 })
    feed('<CR>')
    poke_eventloop()
    eq(file, api.nvim_buf_get_name(0))
    eq({ 'alpha' }, lines())
    eq(cwd, fn.getcwd())

    edit(subdir)
    assert_directory(subdir)
    eq({ '' }, lines())
    eq(vim.uv.fs_realpath(subdir), vim.uv.fs_realpath(fn.getcwd()))

    feed('-')
    poke_eventloop()
    assert_directory(root)

    t.write_file(root .. '/beta.txt', 'beta', true)
    feed('R')
    poke_eventloop()
    line_of('beta.txt')
  end)

  it("follows global 'hidden' when abandoned", function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    command('set hidden')

    edit(root)
    local root_buf = api.nvim_get_current_buf()
    eq('', bufopt('bufhidden'))

    edit(subdir)
    eq(true, api.nvim_buf_is_loaded(root_buf))
    eq(1, fn.getbufinfo(root_buf)[1].hidden)

    n.clear({ args = { '--clean' } })
    command('set nohidden')

    edit(root)
    root_buf = api.nvim_get_current_buf()
    eq('', bufopt('bufhidden'))

    edit(subdir)
    eq(false, api.nvim_buf_is_loaded(root_buf))
  end)

  it('reloads directory buffers', function()
    make_fixture()
    n.clear({
      args = { '--clean', '--cmd', [[autocmd FileType directory ++once setlocal bufhidden=delete]] },
    })

    edit(root)
    assert_directory(root)
    eq('delete', bufopt('bufhidden'))
    eq(true, has_syntax_group('directoryDirectory'))
    local buf = api.nvim_get_current_buf()

    t.write_file(root .. '/beta.txt', 'beta', true)
    feed('R')
    poke_eventloop()
    eq('delete', bufopt('bufhidden'))
    eq(true, has_syntax_group('directoryDirectory'))
    line_of('beta.txt')

    t.write_file(root .. '/gamma.txt', 'gamma', true)
    command('edit')
    eq(buf, api.nvim_get_current_buf())
    assert_directory(root)
    eq(true, has_syntax_group('directoryDirectory'))
    line_of('subdir/')
    line_of('alpha.txt')
    line_of('gamma.txt')
  end)

  it('reports an error and keeps the buffer when reloading a removed directory', function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    edit(subdir)
    assert_directory(subdir)

    n.rmdir(subdir)
    feed('R')
    poke_eventloop()

    ok(exec_capture('messages'):find('ENOENT', 1, true) ~= nil)
    ok(exec_lua([[return vim.b.nvim_dir.err]]):find('ENOENT', 1, true) ~= nil)
    assert_directory(subdir)
  end)

  it('refreshes a directory when navigated into again', function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    edit(root)
    api.nvim_win_set_cursor(0, { line_of('subdir/'), 0 })
    feed('<CR>')
    poke_eventloop()
    assert_directory(subdir)
    eq({ '' }, lines())

    t.write_file(subdir .. '/new.txt', 'new', true)
    feed('-')
    poke_eventloop()
    assert_directory(root)

    api.nvim_win_set_cursor(0, { line_of('subdir/'), 0 })
    feed('<CR>')
    poke_eventloop()
    assert_directory(subdir)
    line_of('new.txt')
  end)

  it('displays filenames as buffer text and opens them from the buffer', function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    edit(root)
    line_of('.hidden')
    line_of('subdir/')
    api.nvim_win_set_cursor(0, { line_of('alpha.txt'), 0 })
    feed('<CR>')
    poke_eventloop()

    eq(file, api.nvim_buf_get_name(0))
    eq({ 'alpha' }, lines())
  end)

  it('encodes special filename characters in directory buffers', function()
    -- Windows reserves backslash as a separator and disallows control characters in filenames.
    -- https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
    t.skip(t.is_os('win'), 'N/A: Windows filenames cannot contain these characters')
    make_fixture()
    n.clear({ args = { '--clean' } })

    local name = 'line\nbreak.txt'
    local raw_names = {
      'back\\slash.txt',
      'tab\tname.txt',
      'carriage\rreturn.txt',
      'ctrl\1name.txt',
      'del\127name.txt',
    }
    for _, raw_name in ipairs(raw_names) do
      t.write_file(root .. '/' .. raw_name, 'raw', true)
    end
    t.write_file(root .. '/' .. name, 'newline', true)

    edit(root)
    for _, raw_name in ipairs(raw_names) do
      line_of(raw_name)
    end
    api.nvim_win_set_cursor(0, { line_of('line\0break.txt'), 0 })
    feed('<CR>')
    poke_eventloop()

    eq(root .. '/' .. name, api.nvim_buf_get_name(0))
    eq({ 'newline' }, lines())
  end)

  it('leaves existing special buffers alone', function()
    make_fixture()
    n.clear({ args = { '--clean' } })

    api.nvim_set_option_value('buftype', 'nofile', { buf = 0 })
    api.nvim_buf_set_name(0, root)
    command('doautocmd BufEnter')

    eq('nofile', api.nvim_get_option_value('buftype', { buf = 0 }))
    eq('', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('coexists with netrw and can be disabled', function()
    make_fixture()
    n.clear({ args = { '--clean' } })
    local cwd = fn.getcwd()

    ok(fn.exists(':Explore') > 0)
    edit(root)
    eq('directory', api.nvim_get_option_value('filetype', { buf = 0 }))

    cd(root)
    command('Explore .')
    cd(cwd)
    eq('netrw', api.nvim_get_option_value('filetype', { buf = 0 }))

    n.clear({
      args = { '--clean', '--cmd', 'let g:loaded_nvim_dir_plugin = 1' },
    })
    edit(root)
    eq('netrw', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  for _, case in ipairs({
    { command = 'edit', windows = 1, tabs = 1 },
    { command = 'split', windows = 2, tabs = 1 },
    { command = 'vsplit', windows = 2, tabs = 1 },
    { command = 'tabedit', windows = 1, tabs = 2 },
    { command = 'tabnew', windows = 1, tabs = 2 },
  }) do
    it(('":browse %s"'):format(case.command), function()
      if t.is_zig_build() then
        return pending('broken with build.zig: TMPDIR relative cwd')
      end
      make_fixture()
      n.clear({ args = { '--clean' } })
      local cwd = fn.getcwd()

      cd(root)
      command('browse ' .. case.command)
      cd(cwd)

      eq(case.windows, #api.nvim_tabpage_list_wins(0))
      eq(case.tabs, #api.nvim_list_tabpages())
      assert_directory(root)
      line_of('alpha.txt')
    end)
  end
end)
