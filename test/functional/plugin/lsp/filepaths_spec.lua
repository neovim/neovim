local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local eq = t.eq
local exec_lua = n.exec_lua
local api = n.api
local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each

describe('nvim.filepaths', function()
  local root

  before_each(function()
    n.clear()
    root = t.tmpname(false)
    t.mkdir(root)
    t.mkdir(root .. '/dir')
    t.mkdir(root .. '/other')
    t.write_file(root .. '/alpha', '')
    t.write_file(root .. '/Beta', '')
    t.write_file(root .. '/.hidden', '')
    t.write_file(root .. '/other/cwd.txt', '')
    api.nvim_buf_set_name(0, root .. '/edit.lua')
    exec_lua(function(path)
      vim.cmd.cd(path)
      vim.lsp.enable('nvim.filepaths')
      vim.bo.filetype = 'lua'
      assert(vim.wait(1000, function()
        local clients = vim.lsp.get_clients({ bufnr = 0, name = 'nvim.filepaths' })
        _G.client = clients[1]
        return _G.client and _G.client.initialized
      end))
      _G.complete = function(line, col, buf)
        buf = buf or vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        local response = assert(_G.client:request_sync('textDocument/completion', {
          textDocument = { uri = vim.uri_from_bufnr(buf) },
          position = { line = 0, character = vim.str_utfindex(line, 'utf-16', col or #line) },
        }, 1000, buf))
        assert(not response.err, vim.inspect(response.err))
        assert(vim.tbl_isempty(_G.client.requests))
        return response.result
      end
    end, root)
  end)

  after_each(function()
    exec_lua(function()
      vim.lsp.stop_client(vim.lsp.get_clients(), true)
    end)
    n.rmdir(root)
  end)

  local function complete(line, col, buf)
    return exec_lua('return _G.complete(...)', line, col or #line, buf)
  end

  local function labels(line, col, buf)
    local result = complete(line, col, buf)
    return vim.tbl_map(function(item)
      return item.label
    end, result.items)
  end

  local function configure(settings)
    return exec_lua(function(value)
      return _G.client:notify(
        'workspace/didChangeConfiguration',
        { settings = { filepaths = value } }
      )
    end, settings)
  end

  it('is discoverable, opt-in, completion-only, and disables cleanly', function()
    local result = labels('./')
    eq({ 'dir', 'other' }, { result[1], result[2] })
    eq(5, #result)
    -- Directory iteration order differs between Lua runtimes.
    for _, label in ipairs({ '.hidden', 'alpha', 'Beta' }) do
      assert(vim.tbl_contains(result, label))
    end
    eq('utf-16', exec_lua('return _G.client.offset_encoding'))
    eq(false, exec_lua("return _G.client:supports_method('completionItem/resolve')"))
    exec_lua(function()
      vim.lsp.enable('nvim.filepaths', false)
      assert(vim.wait(1000, function()
        return #vim.lsp.get_clients({ name = 'nvim.filepaths' }) == 0
      end))
    end)
    n.clear()
    eq(0, exec_lua("vim.bo.filetype = 'lua'; return #vim.lsp.get_clients()"))
  end)

  it('inserts directories without a separator and preserves following text', function()
    local item = complete('"./di/next"', 5).items[1]
    eq('dir', item.label)
    eq(19, item.kind)
    eq('./dir', item.textEdit.newText)
    exec_lua(function(edit)
      vim.lsp.util.apply_text_edits({ edit }, vim.api.nvim_get_current_buf(), 'utf-16')
    end, item.textEdit)
    eq({ '"./dir/next"' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('requires a path context and matches prefixes case-sensitively', function()
    for _, text in ipairs({ '', 'alpha', '.', '~', 'https://example.com/', 'word ' }) do
      eq({}, labels(text))
    end
    eq({}, labels('./b'))
    eq({ 'Beta' }, labels('./B'))
    eq({ '.hidden' }, labels('./.'))
    eq({ 'cwd.txt' }, labels('other/'))
  end)

  it('supports absolute, parent, environment, and home paths without rewriting prefixes', function()
    eq({ 'alpha' }, labels(root .. '/a'))
    eq({ 'alpha' }, labels('./dir/../a'))
    exec_lua(function(path)
      vim.env.NVIM_FILEPATHS_TEST = path
      vim.env.NVIM_FILEPATHS_MISSING = nil
    end, root)
    eq('$NVIM_FILEPATHS_TEST/alpha', complete('$NVIM_FILEPATHS_TEST/a').items[1].textEdit.newText)
    eq({}, labels('$NVIM_FILEPATHS_MISSING/'))
    exec_lua(function(path)
      vim.uv.os_homedir = function()
        return path
      end
    end, root)
    eq('~/alpha', complete('~/a').items[1].textEdit.newText)
  end)

  it('handles Unicode before and inside a quoted path and spaces in directory names', function()
    local unicode = n.fn.nr2char(0x1F600)
    local dirname = 'space ' .. unicode
    t.mkdir(root .. '/' .. dirname)
    t.write_file(root .. '/' .. dirname .. '/file.txt', '')
    local line = unicode .. ' = "./' .. dirname .. '/fi"'
    local result = complete(line, #line - 1)
    eq(1, #result.items)
    eq(6, result.items[1].textEdit.range.start.character)
    exec_lua(function(edit)
      vim.lsp.util.apply_text_edits({ edit }, vim.api.nvim_get_current_buf(), 'utf-16')
    end, result.items[1].textEdit)
    eq({ unicode .. ' = "./' .. dirname .. '/file.txt"' }, api.nvim_buf_get_lines(0, 0, -1, false))
    eq({ 'file.txt' }, labels("'./" .. dirname .. '/fi'))
    t.write_file(root .. '/' .. unicode, '')
    eq({ unicode }, labels('./' .. unicode))
  end)

  it('uses the requested document even when another buffer is current', function()
    local buf = api.nvim_get_current_buf()
    n.command('enew')
    api.nvim_buf_set_name(0, root .. '/other/edit.lua')
    eq({ 'alpha' }, labels('./a', nil, buf))
  end)

  it('uses cwd and filetype overrides, including changes to local cwd', function()
    configure({ base_dir_overrides = { gitcommit = 'cwd' } })
    n.command('lcd ' .. root .. '/other')
    eq({ 'alpha' }, labels('./a'))
    api.nvim_set_option_value('filetype', 'gitcommit', { buf = 0 })
    eq({ 'cwd.txt' }, labels('./'))
    configure({ base_dir = 'cwd', base_dir_overrides = { gitcommit = 'cur_buf' } })
    eq({ 'alpha' }, labels('./a'))
    configure({ base_dir = 'cwd' })
    eq({ 'cwd.txt' }, labels('./'))
    n.command('lcd ' .. root)
    eq({ 'alpha' }, labels('./a'))
  end)

  it('falls back to cwd for unnamed normal buffers', function()
    api.nvim_buf_set_name(0, '')
    eq({ 'alpha' }, labels('./a'))
  end)

  it('sorts, caps results, and recomputes incomplete lists for a narrower prefix', function()
    configure({ sort = 'system', max_items = 2 })
    local result = complete('./')
    eq(true, result.isIncomplete)
    local result_labels = labels('./')
    eq(2, #result_labels)
    -- Directory iteration order differs between Lua runtimes.
    for _, label in ipairs(result_labels) do
      assert(vim.tbl_contains({ '.hidden', 'alpha', 'Beta' }, label))
    end
    eq(false, complete('./B').isIncomplete)
    eq({ 'Beta' }, labels('./B'))
    configure({ max_items = 1 })
    eq({ 'dir' }, labels('./'))
  end)

  it('validates all settings and retains settings after invalid updates', function()
    configure({ max_items = 1 })
    for _, settings in ipairs({
      { max_items = 0 },
      { max_items = 1.5 },
      { max_items = '2' },
      { base_dir = 'project' },
      { base_dir_overrides = { lua = 'project' } },
      { base_dir_overrides = false },
      { sort = 'none' },
      { label_dir_trailing_slash = true },
      { label_symlink_trailing_at = true },
    }) do
      eq(
        false,
        exec_lua(function(value)
          vim.notify = function() end
          return _G.client.rpc.notify(
            'workspace/didChangeConfiguration',
            { settings = { filepaths = value } }
          )
        end, settings)
      )
      eq({ 'dir' }, labels('./'))
      eq(
        false,
        exec_lua(function(value)
          return pcall(
            vim.lsp.config['nvim.filepaths'].cmd,
            {},
            { settings = { filepaths = value } }
          )
        end, settings)
      )
    end
  end)

  it(
    'returns empty results for missing paths and does not create buffers for unknown URIs',
    function()
      eq({}, labels('./missing/'))
      eq({}, labels('./alpha/'))
      eq(
        true,
        exec_lua(function()
          local before = #vim.api.nvim_list_bufs()
          local response = _G.client:request_sync('textDocument/completion', {
            textDocument = { uri = 'file:///nvim-filepaths-unknown' },
            position = { line = 0, character = 0 },
          }, 1000)
          assert(#response.result.items == 0)
          return #vim.api.nvim_list_bufs() == before
        end)
      )
    end
  )

  it('classifies symlinked directories and broken symlinks', function()
    local ok = exec_lua(function(path)
      return vim.uv.fs_symlink(path .. '/dir', path .. '/linked_dir', { dir = true }) ~= nil
    end, root)
    if t.skip(not ok, 'cannot create symlinks') then
      return
    end
    exec_lua(function(path)
      assert(vim.uv.fs_symlink(path .. '/alpha', path .. '/linked_file'))
      assert(vim.uv.fs_symlink(path .. '/missing', path .. '/linked_broken'))
    end, root)
    local items = complete('./linked_').items
    eq({ 'linked_dir', 'linked_broken', 'linked_file' }, labels('./linked_'))
    eq(19, items[1].kind)
    eq('./linked_dir', items[1].textEdit.newText)
    eq(17, items[2].kind)
  end)

  it('supports native Windows paths and separator triggers', function()
    if t.skip(not t.is_os('win'), 'Windows only') then
      return
    end
    eq({ 'alpha' }, labels(root:gsub('/', '\\') .. '\\a'))
    eq({ 'alpha' }, labels('.\\a'))
    eq(
      { '/', '\\' },
      exec_lua('return _G.client.server_capabilities.completionProvider.triggerCharacters')
    )
  end)

  it('reuses clients across buffers and isolates settings between server instances', function()
    eq(
      true,
      exec_lua(function(path)
        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, path .. '/other/edit.lua')
        local config = vim.lsp.config['nvim.filepaths']
        local reused = vim.lsp.start(config, { bufnr = buf })
        assert(reused == _G.client.id)
        local other = config.cmd(
          { on_exit = function() end },
          { settings = { filepaths = { max_items = 1 } } }
        )
        other.notify(
          'workspace/didChangeConfiguration',
          { settings = { filepaths = { max_items = 2 } } }
        )
        other.terminate()
        return #_G.complete('./').items == 5
      end, root)
    )
  end)

  local function controlled_scan()
    exec_lua(function()
      _G.closed = 0
      vim.uv.fs_opendir = function(_, cb)
        _G.open_cb = cb
      end
      vim.uv.fs_readdir = function(_, cb)
        _G.read_cb = cb
      end
      vim.uv.fs_closedir = function(_, cb)
        _G.closed = _G.closed + 1
        cb()
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { './' })
      _G.responses = 0
      local _, id = _G.client:request('textDocument/completion', {
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = 0, character = 2 },
      }, function(err, result)
        _G.responses = _G.responses + 1
        _G.response_error, _G.response_result = err, result
      end)
      _G.request_id = id
      assert(vim.wait(1000, function()
        return _G.open_cb ~= nil
      end))
    end)
  end

  it('cancels before open completes and closes the eventual handle', function()
    controlled_scan()
    exec_lua(function()
      _G.client:cancel_request(_G.request_id)
      _G.open_cb(nil, {})
      assert(vim.wait(1000, function()
        return _G.closed == 1
      end))
      assert(vim.tbl_isempty(_G.client.requests))
    end)
    eq(0, exec_lua('return _G.responses'))
  end)

  it('rejects stale results and closes handles after end of directory', function()
    controlled_scan()
    exec_lua(function()
      _G.open_cb(nil, {})
      assert(vim.wait(1000, function()
        return _G.read_cb ~= nil
      end))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { './changed' })
      _G.read_cb(nil, nil)
      assert(vim.wait(1000, function()
        return _G.responses == 1
      end))
      assert(vim.tbl_isempty(_G.client.requests))
    end)
    eq(-32801, exec_lua('return _G.response_error.code'))
    eq(1, exec_lua('return _G.closed'))
  end)

  it('returns an empty list on read errors and closes the handle', function()
    controlled_scan()
    exec_lua(function()
      _G.open_cb(nil, {})
      assert(vim.wait(1000, function()
        return _G.read_cb ~= nil
      end))
      _G.read_cb('EACCES', nil)
      assert(vim.wait(1000, function()
        return _G.responses == 1
      end))
    end)
    eq({ isIncomplete = false, items = {} }, exec_lua('return _G.response_result'))
    eq(1, exec_lua('return _G.closed'))
  end)

  it('shuts down with a read pending and reports exit only once', function()
    controlled_scan()
    exec_lua(function()
      _G.open_cb(nil, {})
      assert(vim.wait(1000, function()
        return _G.read_cb ~= nil
      end))
      _G.exits = 0
      _G.client._on_exit_cbs = {
        function()
          _G.exits = _G.exits + 1
        end,
      }
      _G.client:stop(false)
      assert(vim.wait(1000, function()
        return _G.exits == 1
      end))
      _G.client.rpc.terminate()
      _G.client.rpc.notify('exit')
      _G.read_cb(nil, { { name = 'late', type = 'file' } })
      assert(vim.wait(1000, function()
        return _G.closed == 1
      end))
      assert(vim.tbl_isempty(_G.client.requests))
      assert(not _G.client.rpc.request('initialize', {}, function() end))
    end)
    eq({ 0, 1 }, exec_lua('return { _G.responses, _G.exits }'))
  end)

  it(
    'reports unsupported methods and invalid parameters without leaving pending requests',
    function()
      eq(
        -32601,
        exec_lua(function()
          return _G.client:request_sync('filepaths/unknown', {}, 1000).err.code
        end)
      )
      eq(
        -32602,
        exec_lua(function()
          return _G.client:request_sync('textDocument/completion', {}, 1000).err.code
        end)
      )
      eq(true, exec_lua('return vim.tbl_isempty(_G.client.requests)'))
    end
  )

  it('accepts completion in the built-in UI alongside another client', function()
    exec_lua(t_lsp.create_server_definition)
    exec_lua(function()
      local other = _G._create_server({
        capabilities = { completionProvider = {} },
        handlers = {
          ['textDocument/completion'] = function(_, _, cb)
            cb(nil, {})
          end,
        },
      })
      local id = assert(vim.lsp.start({ name = 'other', cmd = other.cmd }))
      assert(vim.wait(1000, function()
        return vim.lsp.get_client_by_id(id).initialized
      end))
      vim.opt.completeopt = { 'menuone', 'noselect' }
      vim.lsp.completion.enable(true, _G.client.id, 0, { autotrigger = true })
      vim.lsp.completion.enable(true, id, 0)
    end)
    n.feed('i./')
    t.retry(nil, 1000, function()
      eq(1, n.fn.pumvisible())
    end)
    n.feed('<C-e>a')
    exec_lua('vim.lsp.completion.get()')
    t.retry(nil, 1000, function()
      eq(1, n.fn.pumvisible())
    end)
    n.feed('<C-n><C-y><Esc>')
    eq({ './alpha' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)
