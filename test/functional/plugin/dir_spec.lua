local n = require('test.functional.testnvim')()
local t = require('test.testutil')

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

local function expect_directory(path)
  eq(path, api.nvim_buf_get_name(0))
  eq(path, fn.bufname('%'))
  eq('directory', bufopt('filetype'))
  eq(true, bufopt('buflisted'))
end

local function filesystem_root(path)
  local dir = vim.fs.normalize(vim.fs.abspath(path))
  while true do
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      return dir
    end
    dir = parent
  end
end

---@param args? string[]
---@return string[]
local function with_buftype_optionset(args)
  return vim.list_extend({
    '--cmd',
    'let g:nvim_directory_events = []',
    '--cmd',
    [[autocmd OptionSet buftype call add(g:nvim_directory_events, v:option_new)]],
  }, args or {})
end

local function expect_buftype_optionset(path)
  expect_directory(path)
  eq({ 'nowrite' }, exec_lua('return vim.g.nvim_directory_events'))
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
    n.clear({ args_rm = { '-u' }, args = { root } })

    expect_directory(root)
    eq('../', lines()[1])
    line_of('subdir/')
    line_of('.hidden')
    line_of('alpha.txt')
  end)

  it('triggers nested autocmds when opening directory buffers', function()
    make_fixture()

    n.clear({
      args_rm = { '-u' },
      args = with_buftype_optionset({ root }),
    })
    expect_buftype_optionset(root)

    n.clear({
      args_rm = { '-u' },
      args = with_buftype_optionset(),
    })
    edit(root)
    expect_buftype_optionset(root)
  end)

  it('handles nested autocmds deleting the directory buffer', function()
    make_fixture()
    n.clear({
      args_rm = { '-u' },
      args = {
        '--cmd',
        'let g:nvim_directory_wiped = 0',
        '--cmd',
        [[autocmd OptionSet buftype let g:nvim_directory_wiped = 1 | bwipeout!]],
        root,
      },
    })

    eq(1, exec_lua('return vim.g.nvim_directory_wiped'))
    eq('', exec_capture('messages'))
  end)

  it('does not load the module until opening a directory', function()
    make_fixture()
    n.clear({ args_rm = { '-u' } })

    eq(false, exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    edit(root)
    eq(true, exec_lua([[return package.loaded['nvim.dir'] ~= nil]]))
    expect_directory(root)
  end)

  it('uses an absolute buffer name for a relative startup directory argument', function()
    make_fixture()
    local cwd = assert(vim.uv.cwd())
    assert(vim.uv.chdir(root))
    n.clear({ args_rm = { '-u' }, args = { '.' } })
    assert(vim.uv.chdir(cwd))

    expect_directory(root)
  end)

  it('normalizes edited directory names', function()
    make_fixture()
    n.clear({ args_rm = { '-u' } })

    edit(root .. '///')

    expect_directory(root)
  end)

  it('does not show a parent entry at the filesystem root', function()
    n.clear({ args_rm = { '-u' } })
    local root_dir = filesystem_root(fn.getcwd())

    edit(root_dir)

    expect_directory(root_dir)
    eq(false, vim.tbl_contains(lines(), '../'))
  end)

  it('navigates entries and refreshes the listing', function()
    make_fixture()
    n.clear({ args_rm = { '-u' } })

    edit(root)
    expect_directory(root)

    api.nvim_win_set_cursor(0, { line_of('alpha.txt'), 0 })
    feed('<CR>')
    poke_eventloop()
    eq(file, api.nvim_buf_get_name(0))
    eq({ 'alpha' }, lines())

    edit(subdir)
    expect_directory(subdir)
    eq({ '../' }, lines())

    feed('-')
    poke_eventloop()
    expect_directory(root)

    t.write_file(root .. '/beta.txt', 'beta', true)
    feed('R')
    poke_eventloop()
    line_of('beta.txt')
  end)

  it('displays filenames as buffer text and opens stored entries', function()
    -- Windows reserves backslash as a separator and disallows control characters in filenames.
    -- https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
    t.skip(t.is_os('win'), 'N/A: Windows filenames cannot contain these characters')
    make_fixture()
    n.clear({ args_rm = { '-u' } })

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
    n.clear({ args_rm = { '-u' } })

    api.nvim_set_option_value('buftype', 'nofile', { buf = 0 })
    api.nvim_buf_set_name(0, root)
    command('doautocmd BufEnter')

    eq('nofile', api.nvim_get_option_value('buftype', { buf = 0 }))
    eq('', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('coexists with netrw and can be disabled', function()
    make_fixture()
    n.clear({ args_rm = { '-u' } })
    local cwd = fn.getcwd()

    ok(fn.exists(':Explore') > 0)
    edit(root)
    eq('directory', api.nvim_get_option_value('filetype', { buf = 0 }))

    cd(root)
    command('Explore .')
    cd(cwd)
    eq('netrw', api.nvim_get_option_value('filetype', { buf = 0 }))

    n.clear({
      args_rm = { '-u' },
      args = { '--cmd', 'let g:loaded_nvim_directory_plugin = 1' },
    })
    edit(root)
    eq('netrw', api.nvim_get_option_value('filetype', { buf = 0 }))
  end)

  it('supports the FileExplorer browse contract', function()
    make_fixture()
    n.clear({ args_rm = { '-u' } })
    local cwd = fn.getcwd()

    cd(root)
    command('browse edit .')
    cd(cwd)

    expect_directory(root)
    line_of('alpha.txt')
  end)
end)
