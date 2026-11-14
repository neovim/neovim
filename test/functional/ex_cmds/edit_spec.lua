local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, finally = t.describe, t.it, t.before_each, t.finally
local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local pcall_err = t.pcall_err
local clear = n.clear
local feed = n.feed
local api = n.api

describe(':edit', function()
  before_each(function()
    clear()
  end)

  it('E77 message', function()
    local glob_files = { 'Xedit-glob-one.js', 'Xedit-glob-two.js' }

    finally(function()
      for _, file in ipairs(glob_files) do
        os.remove(file)
      end
    end)

    for _, file in ipairs(glob_files) do
      t.write_file(file, '')
    end

    eq(
      'Vim(edit):E77: Too many file names (glob not allowed)',
      pcall_err(command, 'edit Xedit-glob-*.js')
    )
  end)

  it('without arguments does not restart :terminal buffer', function()
    command('terminal')
    feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('edit')

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)

  it('file:// URI yields the same buffer as file path #39278', function()
    local file = t.tmpname()
    local dir = vim.fs.dirname(file)
    local tail = vim.fs.basename(file)

    command(('edit %s'):format(file))
    local buf = api.nvim_get_current_buf()

    command(('edit %s'):format(vim.uri.from_fname(file)))
    eq(buf, api.nvim_get_current_buf())

    command(('edit %s/./%s'):format(vim.uri.from_fname(dir), tail))
    eq(buf, api.nvim_get_current_buf())
    eq(file, api.nvim_buf_get_name(0))
    eq(1, #api.nvim_list_bufs())
  end)

  it('file:// URI yields the same buffer as directory path #39278', function()
    local dir = t.tmpname(false)
    t.mkdir(dir)

    command(('edit %s'):format(vim.uri.from_fname(dir)))
    eq(dir, vim.fs.normalize(api.nvim_buf_get_name(0)))
    local buf = api.nvim_get_current_buf()
    command(('edit %s'):format(dir))
    eq(buf, api.nvim_get_current_buf())
    eq(1, #api.nvim_list_bufs())
  end)

  it('file:// URI yields the same buffer as symlink and real path #39278', function()
    local file = t.tmpname()
    local link = t.tmpname(false)
    vim.uv.fs_symlink(file, link)

    command(('edit %s'):format(file))
    local buf = api.nvim_get_current_buf()
    command(('edit %s'):format(vim.uri.from_fname(link)))
    eq(buf, api.nvim_get_current_buf())
    eq(file, api.nvim_buf_get_name(0))
    eq(1, #api.nvim_list_bufs())

    command('bwipeout')
    command(('edit %s'):format(vim.uri.from_fname(link)))
    buf = api.nvim_get_current_buf()
    command(('edit %s'):format(file))
    eq(buf, api.nvim_get_current_buf())
    eq(link, api.nvim_buf_get_name(0))
    eq(1, #api.nvim_list_bufs())
  end)
end)
