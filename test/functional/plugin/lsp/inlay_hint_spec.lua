local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_lsp = require('test.functional.plugin.lsp.testutil')

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
local neq = t.neq
local pcall_err = t.pcall_err
local dedent = t.dedent
local exec_lua = n.exec_lua
local insert = n.insert
local feed = n.feed
local api = n.api

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.inlay_hint', function()
  local text = dedent([[
auto add(int a, int b) { return a + b; }

int main() {
    int x = 1;
    int y = 2;
    return add(x,y);
}
}]])

  ---@type lsp.InlayHint[]
  local response = {
    {
      kind = 1,
      paddingLeft = false,
      paddingRight = false,
      label = '-> int',
      position = { character = 22, line = 0 },
    },
    {
      kind = 2,
      paddingLeft = false,
      paddingRight = true,
      label = 'a:',
      position = { character = 15, line = 5 },
    },
    {
      kind = 2,
      paddingLeft = false,
      paddingRight = true,
      label = 'b:',
      position = { character = 17, line = 5 },
    },
  }

  local grid_without_inlay_hints = [[
  auto add(int a, int b) { return a + b; }          |
                                                    |
  int main() {                                      |
      int x = 1;                                    |
      int y = 2;                                    |
      return add(x,y);                              |
  }                                                 |
  ^}                                                 |
                                                    |
]]

  local grid_with_inlay_hints = [[
  auto add(int a, int b){1:-> int} { return a + b; }    |
                                                    |
  int main() {                                      |
      int x = 1;                                    |
      int y = 2;                                    |
      return add({1:a:} x,{1:b:} y);                        |
  }                                                 |
  ^}                                                 |
                                                    |
]]

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  --- @type integer
  local bufnr

  before_each(function()
    clear_notrace()
    screen = Screen.new(50, 9)

    bufnr = n.api.nvim_get_current_buf()
    exec_lua(create_server_definition)
    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, response)
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    insert(text)
    exec_lua(function()
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end)
    screen:expect({ grid = grid_with_inlay_hints })
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  it('clears inlay hints when sole client detaches', function()
    exec_lua(function()
      vim.lsp.get_client_by_id(client_id):stop()
    end)
    screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
  end)

  it('does not clear inlay hints when one of several clients detaches', function()
    local client_id2 = exec_lua(function()
      _G.server2 = _G._create_server({
        capabilities = {
          textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, {})
          end,
        },
      })
      return vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
    end)

    exec_lua(function()
      vim.lsp.get_client_by_id(client_id2):stop()
    end)
    screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
  end)

  describe('enable()', function()
    it('validation', function()
      t.matches(
        'enable: expected boolean, got table',
        t.pcall_err(exec_lua, function()
          --- @diagnostic disable-next-line:param-type-mismatch
          vim.lsp.inlay_hint.enable({}, { bufnr = bufnr })
        end)
      )
      t.matches(
        'enable: expected boolean, got number',
        t.pcall_err(exec_lua, function()
          --- @diagnostic disable-next-line:param-type-mismatch
          vim.lsp.inlay_hint.enable(42)
        end)
      )
      t.matches(
        'filter: expected table, got number',
        t.pcall_err(exec_lua, function()
          --- @diagnostic disable-next-line:param-type-mismatch
          vim.lsp.inlay_hint.enable(true, 42)
        end)
      )
    end)
  end)

  describe('clears/applies inlay hints when passed false/true/nil', function()
    local bufnr2 --- @type integer
    before_each(function()
      bufnr2 = exec_lua(function()
        local bufnr2_0 = vim.api.nvim_create_buf(true, false)
        vim.lsp.buf_attach_client(bufnr2_0, client_id)
        vim.api.nvim_win_set_buf(0, bufnr2_0)
        return bufnr2_0
      end)
      insert(text)
      screen:expect({ grid = grid_without_inlay_hints })
      exec_lua(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr2 })
      end)
      screen:expect({ grid = grid_with_inlay_hints })
    end)

    it('for one single buffer', function()
      exec_lua(function()
        vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
        vim.api.nvim_win_set_buf(0, bufnr2)
      end)
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
      n.api.nvim_win_set_buf(0, bufnr)
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

      exec_lua(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end)
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })

      exec_lua(function()
        vim.lsp.inlay_hint.enable(
          not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
          { bufnr = bufnr }
        )
      end)
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

      exec_lua(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end)
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
    end)

    it('for all buffers', function()
      exec_lua(function()
        vim.lsp.inlay_hint.enable(false)
      end)
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
      n.api.nvim_win_set_buf(0, bufnr2)
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

      exec_lua(function()
        vim.lsp.inlay_hint.enable(true)
      end)
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
      n.api.nvim_win_set_buf(0, bufnr)
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
    end)
  end)

  describe('get()', function()
    it('returns filtered inlay hints', function()
      local expected2 = {
        kind = 1,
        paddingLeft = false,
        label = ': int',
        position = {
          character = 10,
          line = 2,
        },
        paddingRight = false,
      }

      exec_lua(function()
        _G.server2 = _G._create_server({
          capabilities = {
            textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function(_, _, callback)
              callback(nil, { expected2 })
            end,
          },
        })
        _G.client2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
      end)

      --- @type vim.lsp.inlay_hint.get.ret
      eq(
        {
          { bufnr = 1, client_id = 1, inlay_hint = response[1] },
          { bufnr = 1, client_id = 1, inlay_hint = response[2] },
          { bufnr = 1, client_id = 1, inlay_hint = response[3] },
          { bufnr = 1, client_id = 2, inlay_hint = expected2 },
        },
        exec_lua(function()
          return vim.lsp.inlay_hint.get()
        end)
      )

      eq(
        {
          { bufnr = 1, client_id = 2, inlay_hint = expected2 },
        },
        exec_lua(function()
          return vim.lsp.inlay_hint.get({
            range = {
              start = { line = 2, character = 10 },
              ['end'] = { line = 2, character = 10 },
            },
          })
        end)
      )

      eq(
        {
          { bufnr = 1, client_id = 1, inlay_hint = response[2] },
          { bufnr = 1, client_id = 1, inlay_hint = response[3] },
        },
        exec_lua(function()
          return vim.lsp.inlay_hint.get({
            bufnr = vim.api.nvim_get_current_buf(),
            range = {
              start = { line = 4, character = 18 },
              ['end'] = { line = 5, character = 17 },
            },
          })
        end)
      )

      eq(
        {},
        exec_lua(function()
          return vim.lsp.inlay_hint.get({
            bufnr = vim.api.nvim_get_current_buf() + 1,
          })
        end)
      )
    end)
  end)

  it('does not request hints from lsp when disabled', function()
    local client_id2 = exec_lua(function()
      _G.server2 = _G._create_server({
        capabilities = {
          textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            _G.got_inlay_hint_request = true
            callback(nil, {})
          end,
        },
      })
      return vim.lsp.start({
        name = 'dummy2',
        cmd = _G.server2.cmd,
        on_attach = function(client, _)
          vim.lsp.inlay_hint.enable(false, { client_id = client.id })
        end,
      })
    end)

    local function was_request_sent()
      return exec_lua(function()
        return _G.got_inlay_hint_request or false
      end)
    end

    eq(false, was_request_sent())

    exec_lua(function()
      vim.lsp.inlay_hint.get()
    end)

    eq(false, was_request_sent())

    exec_lua(function()
      vim.lsp.inlay_hint.enable(true, { client_id = client_id2 })
    end)

    eq(true, was_request_sent())
  end)
end)

describe('Inlay hints handler', function()
  local text = dedent([[
test text
  ]])

  local response = {
    { position = { line = 0, character = 0 }, label = '0' },
    { position = { line = 0, character = 0 }, label = '1' },
    { position = { line = 0, character = 0 }, label = '2' },
    { position = { line = 0, character = 0 }, label = '3' },
    { position = { line = 0, character = 0 }, label = '4' },
  }

  local grid_without_inlay_hints = [[
  test text                                         |
  ^                                                  |
                                                    |
]]

  local grid_with_inlay_hints = [[
  {1:01234}test text                                    |
  ^                                                  |
                                                    |
]]

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  --- @type integer
  local bufnr

  before_each(function()
    clear_notrace()
    screen = Screen.new(50, 3)

    exec_lua(create_server_definition)
    bufnr = n.api.nvim_get_current_buf()
    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, response)
          end,
        },
      })

      vim.api.nvim_win_set_buf(0, bufnr)

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)
    insert(text)
  end)

  it('renders hints with same position in received order', function()
    exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })]])
    screen:expect({ grid = grid_with_inlay_hints })
    exec_lua(function()
      vim.lsp.get_client_by_id(client_id):stop()
    end)
    screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
  end)

  it('refreshes hints on request', function()
    exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })]])
    screen:expect({ grid = grid_with_inlay_hints })
    feed('kibefore <Esc>')
    screen:expect([[
      before^ {1:01234}test text                             |
                                                        |*2
    ]])
    exec_lua(function()
      vim.lsp.inlay_hint.on_refresh(
        nil,
        nil,
        { method = 'workspace/inlayHint/refresh', client_id = client_id }
      )
    end)
    screen:expect([[
      {1:01234}before^ test text                             |
                                                        |*2
    ]])
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)
end)

--- Run actions in the child, checking asynchronous, once-only completion.
--- `during` runs after action() returns and before waiting for completion.
local function setup_action_driver()
  exec_lua(function()
    --- @return {buf: integer, client_id: integer?, win: integer?, lines: string[]?}
    function _G.run_inlay_action(action, hints, during)
      local result ---@type table?
      local returned = false
      vim.lsp.inlay_hint.action(action, {
        hints = hints,
        on_done = function(ctx)
          assert(returned, 'on_done must be asynchronous')
          assert(result == nil, 'on_done must run exactly once')
          result = { buf = ctx.buf, client_id = ctx.client and ctx.client.id }
        end,
      })
      returned = true
      if during then
        during()
      end
      assert(
        vim.wait(5000, function()
          return result ~= nil
        end),
        'action() did not finish'
      )
      vim.wait(0)
      -- An action may leave behind a buffer that was deleted while it ran.
      if vim.api.nvim_buf_is_valid(result.buf) then
        result.win = vim.fn.bufwinid(result.buf)
        result.lines = vim.api.nvim_buf_get_lines(result.buf, 0, -1, false)
      end
      return result
    end

    --- @param record fun(hints: lsp.InlayHint[])
    function _G.capture_hints(record)
      return function(hints, ctx, done)
        record(hints)
        done(ctx)
        return true
      end
    end
  end)
end

describe('vim.lsp.inlay_hint.action', function()
  local lines = { 'let a = make();', 'let b = make();', 'use(a);' }
  local source, target, win

  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)

    source, target, win = unpack(exec_lua(function()
      local source_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, lines)
      local target_buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(target_buf, 'Xhint_target.rs')
      vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'struct T {}' })
      local location = {
        uri = vim.uri_from_bufnr(target_buf),
        range = { start = { line = 0, character = 7 }, ['end'] = { line = 0, character = 8 } },
      }
      local resolved = {}
      for row = 0, 1 do
        local pos = { line = row, character = 5 }
        resolved[row + 1] = {
          label = {
            { value = ': ' },
            {
              value = 'T',
              location = location,
              command = { title = 'Test command', command = 'test' },
              tooltip = 'string tooltip',
            },
          },
          tooltip = { kind = 'plaintext', value = 'plaintext tooltip' },
          position = pos,
          textEdits = { { newText = ': T', range = { start = pos, ['end'] = pos } } },
          data = row + 1,
        }
      end
      resolved[3] = { label = 'arg:', position = { line = 2, character = 4 }, data = 3 }
      local hints = vim.deepcopy(resolved)
      -- The first hint gains its actionable fields only through resolution.
      hints[1].label[2] = { value = 'T' }
      hints[1].tooltip, hints[1].textEdits = nil, nil

      _G.command_called = {}
      local server = _G._create_server({
        capabilities = {
          inlayHintProvider = { resolveProvider = true },
          hoverProvider = true,
          executeCommandProvider = { commands = { 'test' } },
        },
        handlers = {
          ['workspace/executeCommand'] = function(_, param, callback)
            table.insert(_G.command_called, param)
            callback(nil, {})
          end,
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, vim.deepcopy(hints))
          end,
          ['inlayHint/resolve'] = function(_, params, callback)
            callback(nil, resolved[params.data])
          end,
          ['textDocument/hover'] = function(_, params, callback)
            assert(params.textDocument.uri == location.uri)
            assert(vim.deep_equal(params.position, location.range.start))
            callback(nil, { contents = { kind = 'markdown', value = '```rust\nstruct T {}\n```' } })
          end,
        },
      })

      assert(vim.lsp.start({ name = 'hints', cmd = server.cmd }))
      vim.lsp.inlay_hint.enable(true, { bufnr = source_buf })
      assert(vim.wait(1000, function()
        return #vim.lsp.inlay_hint.get({ bufnr = source_buf }) == 3
      end))
      return { source_buf, target_buf, vim.api.nvim_get_current_win() }
    end))

    setup_action_driver()
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  local function run_action(action, first, last)
    return exec_lua(function()
      return _G.run_inlay_action(
        action,
        vim.lsp.inlay_hint.get({
          bufnr = source,
          range = {
            start = { line = first, character = 0 },
            ['end'] = { line = last or first, character = #lines[(last or first) + 1] },
          },
        })
      )
    end)
  end

  local function count_selected_hints(from, to)
    return exec_lua(function()
      vim.api.nvim_win_set_cursor(win, from)
      if to then
        vim.cmd.normal('v')
        vim.api.nvim_win_set_cursor(win, to)
      end
      local count ---@type integer?
      _G.run_inlay_action(_G.capture_hints(function(hints)
        count = #hints
      end))
      return assert(count)
    end)
  end

  it('selects hints from the cursor, or from the visual selection', function()
    eq(1, count_selected_hints({ 1, 4 }))
    eq(2, count_selected_hints({ 1, 0 }, { 2, 10 }))
  end)

  it('textEdits inserts the edits of every selected hint', function()
    eq(
      { 'let a: T = make();', 'let b: T = make();', 'use(a);' },
      run_action('textEdits', 0, 1).lines
    )
  end)

  for _, hidden in ipairs({ true, false }) do
    it('location reports the destination with hidden=' .. tostring(hidden), function()
      api.nvim_set_option_value('hidden', hidden, {})
      exec_lua(function()
        vim.api.nvim_buf_set_name(source, 'Xhint_source.rs')
        vim.bo[source].modified = false
      end)
      local result = run_action('location', 0)
      eq(target, result.buf)
      eq(target, api.nvim_get_current_buf())
      neq(nil, result.client_id)
      eq(hidden, api.nvim_buf_is_loaded(source))
    end)
  end

  it('tooltip shows the tooltips, location and command in a floating window', function()
    local path = n.fn.fnamemodify(api.nvim_buf_get_name(target), ':~')
    local result = run_action('tooltip', 0)
    neq(source, result.buf)
    neq(win, result.win)
    eq({
      '# `: T`',
      '',
      '```',
      'plaintext tooltip',
      '```',
      '',
      '## `T`',
      '',
      'string tooltip',
      ('_Location_: `%s`:1'):format(path),
      '_Command_: Test command',
    }, result.lines)
  end)

  it('hover shows hover info of the label location in a floating window', function()
    local result = run_action('hover', 0)
    neq(source, result.buf)
    neq(win, result.win)
    eq({ '# `T`', '```rust', 'struct T {}', '```' }, result.lines)
  end)

  it('command executes the label command', function()
    run_action('command', 0)
    eq(1, exec_lua('return #_G.command_called'))
  end)

  it('takes no action on a hint without the needed attributes', function()
    local buf_count = #api.nvim_list_bufs()
    for _, action in ipairs({ 'textEdits', 'location', 'tooltip', 'hover', 'command' }) do
      local result = run_action(action, 2)
      eq(source, result.buf, action)
      eq(lines, result.lines, action)
      eq(nil, result.client_id, action)
    end
    eq(buf_count, #api.nvim_list_bufs())
    eq(0, exec_lua('return #_G.command_called'))
  end)
end)

describe('vim.lsp.inlay_hint.action edge cases', function()
  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })

      function _G.start_hint_client(capabilities, handlers, flags)
        handlers = handlers or {}
        handlers['textDocument/inlayHint'] = handlers['textDocument/inlayHint']
          or function(_, _, cb)
            cb(nil, {})
          end
        local server = _G._create_server({
          capabilities = capabilities or { inlayHintProvider = true },
          handlers = handlers,
        })
        local id = assert(vim.lsp.start({ name = 'hints', cmd = server.cmd, flags = flags }, {
          reuse_client = function()
            return false
          end,
        }))
        local client = assert(vim.lsp.get_client_by_id(id))
        assert(vim.wait(1000, function()
          return client.initialized
        end))
        return client, server
      end

      function _G.hint_entry(client, hint, buf)
        return {
          bufnr = buf or vim.api.nvim_get_current_buf(),
          client_id = client.id,
          inlay_hint = vim.tbl_extend('force', {
            label = 'T',
            position = { line = 0, character = 1 },
          }, hint or {}),
        }
      end

      function _G.label_loc(buf)
        return {
          uri = vim.uri_from_bufnr(buf or 0),
          range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
        }
      end

      function _G.insert_edit(text, pos)
        pos = pos or { line = 0, character = 1 }
        return { newText = text, range = { start = pos, ['end'] = pos } }
      end

      -- A hint/client pair that reaches the given request when its action runs.
      function _G.start_action_client(method, handler)
        local client = start_hint_client({
          inlayHintProvider = { resolveProvider = method == 'inlayHint/resolve' },
          hoverProvider = method == 'textDocument/hover',
          executeCommandProvider = { commands = { 'test' } },
        }, handler and { [method] = handler })
        local loc = label_loc()
        return client,
          hint_entry(client, {
            label = {
              { value = 'T', location = loc, command = { title = 'Test', command = 'test' } },
            },
          })
      end
    end)

    setup_action_driver()
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  it('finishes asynchronously with no hints', function()
    eq(
      { api.nvim_get_current_buf(), true },
      exec_lua(function()
        local result = run_inlay_action('textEdits', {})
        return { result.buf, result.client_id == nil }
      end)
    )
  end)

  it('always supplies custom handlers with a completion function', function()
    eq(
      true,
      exec_lua(function()
        local client = start_hint_client()
        local called = false
        vim.lsp.inlay_hint.action(function(_, ctx, done)
          done(ctx)
          called = true
          return true
        end, { hints = { hint_entry(client) } })
        return vim.wait(1000, function()
          return called
        end)
      end)
    )
  end)

  it('lets custom handlers complete after unloading their source', function()
    eq(
      { true, true, false },
      exec_lua(function()
        local client = start_hint_client()
        local source = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(source, 'Xhint_source')
        vim.bo[source].modified = false
        vim.o.hidden = false
        local target = vim.api.nvim_create_buf(true, false)
        local result = run_inlay_action(function(_, ctx, done)
          vim.api.nvim_set_current_buf(target)
          vim.schedule(function()
            done({ buf = target, client = ctx.client })
          end)
          return true
        end, { hint_entry(client) })
        return {
          result.buf == target,
          result.client_id == client.id,
          vim.api.nvim_buf_is_loaded(source),
        }
      end)
    )
  end)

  it('watches fallback resolution after a custom handler declines', function()
    eq(
      { buf = api.nvim_get_current_buf() },
      exec_lua(function()
        local first = start_hint_client()
        local reply
        local second = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, _, cb)
            reply = cb
          end,
        })
        local result = run_inlay_action(function(_, ctx)
          assert(ctx.client.id == first.id)
          return false
        end, { hint_entry(first), hint_entry(second) }, function()
          assert(vim.wait(1000, function()
            return reply ~= nil
          end))
          second:stop(true)
        end)
        return { buf = result.buf, client_id = result.client_id }
      end)
    )
  end)

  it('tries clients in ID order and stops at the first handled action', function()
    eq(
      { { 1, 2 }, 2 },
      exec_lua(function()
        local first, second, third = start_hint_client(), start_hint_client(), start_hint_client()
        local seen = {}
        local result = run_inlay_action(function(_, ctx, done)
          seen[#seen + 1] = ctx.client.id
          if ctx.client.id == first.id then
            return false
          end
          done(ctx)
          return true
        end, { hint_entry(third), hint_entry(second), hint_entry(first) })
        return { seen, result.client_id }
      end)
    )
  end)

  it('applies supplied edits to their source buffer without resolving again', function()
    eq(
      { 'aXbc', 'other', true },
      exec_lua(function()
        local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function()
            error('unexpected resolve')
          end,
        })
        local source = vim.api.nvim_get_current_buf()
        local entry = hint_entry(client, {
          textEdits = { insert_edit('X') },
        })
        local other = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(other)
        vim.api.nvim_buf_set_lines(other, 0, -1, false, { 'other' })
        local result = run_inlay_action('textEdits', { entry })
        return {
          vim.api.nvim_buf_get_lines(source, 0, -1, false)[1],
          vim.api.nvim_get_current_line(),
          result.buf == source and result.client_id == client.id,
        }
      end)
    )
  end)

  for _, action in ipairs({ 'textEdits', 'location', 'command' }) do
    it('completes and reports errors when ' .. action .. ' fails', function()
      local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
      local result, messages = unpack(exec_lua(function()
        local client, entry = start_action_client('workspace/executeCommand')
        if action == 'textEdits' then
          entry.inlay_hint.textEdits = { insert_edit('X') }
          vim.bo.modifiable = false
        elseif action == 'command' then
          client.commands.test = function(_, ctx)
            vim.api.nvim_buf_set_text(ctx.bufnr, 0, 1, 0, 1, { 'X' })
          end
          vim.bo.modifiable = false
        else
          local target = vim.api.nvim_create_buf(true, false)
          vim.api.nvim_buf_set_name(target, 'Xhint_target')
          entry.inlay_hint.label[1].location = label_loc(target)
          vim.wo.winfixbuf = true
        end
        local messages = {}
        vim.notify = function(message, level)
          messages[#messages + 1] = { message = message, level = level }
        end
        local result = run_inlay_action(action, { entry })
        assert(vim.api.nvim_get_current_buf() == buf)
        return { result, messages }
      end))
      eq({ buf = buf, win = win, lines = { 'abc' } }, result)
      eq(1, #messages)
      eq(vim.log.levels.ERROR, messages[1].level)
      t.matches(
        action == 'location' and 'E1513' or "Buffer is not 'modifiable'",
        messages[1].message
      )
    end)
  end

  it('deduplicates shared edit lists, preserving repeated insertions', function()
    eq(
      { '((abc))' },
      exec_lua(function()
        local client = start_hint_client()
        local start, finish = { line = 0, character = 0 }, { line = 0, character = 3 }
        local edits = {
          insert_edit('(', start),
          insert_edit('(', start),
          insert_edit('))', finish),
        }
        return run_inlay_action('textEdits', {
          hint_entry(client, { position = start, textEdits = edits }),
          hint_entry(client, { position = finish, textEdits = vim.deepcopy(edits) }),
        }).lines
      end)
    )
  end)

  it('ignores cached edits while refreshed hints are pending', function()
    eq(
      { buf = api.nvim_get_current_buf(), lines = { 'Zabc' } },
      exec_lua(function()
        local sent = false
        start_hint_client({ textDocumentSync = 1, inlayHintProvider = true }, {
          ['textDocument/inlayHint'] = function(_, _, cb)
            if sent then
              return
            end
            sent = true
            local pos = { line = 0, character = 1 }
            cb(nil, {
              {
                label = 'T',
                position = pos,
                textEdits = { insert_edit(': T', pos) },
              },
            })
          end,
        })
        vim.lsp.inlay_hint.enable(true)
        assert(vim.wait(1000, function()
          return #vim.lsp.inlay_hint.get({ bufnr = 0 }) == 1
        end))
        vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'Z' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })
        local result = run_inlay_action('textEdits')
        return { buf = result.buf, client_id = result.client_id, lines = result.lines }
      end)
    )
  end)

  it('rejects mixed-buffer hints before invoking a handler', function()
    eq(
      { false, true, false },
      exec_lua(function()
        local client = start_hint_client()
        local called = false
        local ok, err = pcall(vim.lsp.inlay_hint.action, function()
          called = true
          return true
        end, {
          hints = {
            hint_entry(client),
            hint_entry(client, {}, vim.api.nvim_create_buf(true, false)),
          },
        })
        vim.wait(0)
        return { ok, tostring(err):find('same buffer', 1, true) ~= nil, called }
      end)
    )
  end)

  it('converts cached positions for UTF-16 resolution without mutating them', function()
    eq(
      { 3, 6, 6 },
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'é😀x' })
        local sent
        start_hint_client({
          positionEncoding = 'utf-16',
          inlayHintProvider = { resolveProvider = true },
        }, {
          ['textDocument/inlayHint'] = function(_, _, cb)
            cb(nil, { { label = 'T', position = { line = 0, character = 3 } } })
          end,
          ['inlayHint/resolve'] = function(_, params, cb)
            sent = params.position.character
            cb(nil, params)
          end,
        })
        vim.lsp.inlay_hint.enable(true)
        assert(vim.wait(1000, function()
          return #vim.lsp.inlay_hint.get({ bufnr = 0 }) == 1
        end))
        local hints = vim.lsp.inlay_hint.get({ bufnr = 0 })
        local received
        run_inlay_action(
          capture_hints(function(resolved)
            received = resolved[1].position.character
          end),
          hints
        )
        return { sent, received, hints[1].inlay_hint.position.character }
      end)
    )
  end)

  it('retains successful hint order when resolve responses arrive in reverse order', function()
    eq(
      { 'first', 'second' },
      exec_lua(function()
        local pending = {}
        local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, params, cb)
            pending[#pending + 1] = function()
              if params.label == 'failed' then
                cb({ code = -32603, message = 'failed' })
              else
                cb(nil, params)
              end
            end
          end,
        })
        local labels
        run_inlay_action(
          capture_hints(function(hints)
            labels = { hints[1].label, hints[2].label }
          end),
          {
            hint_entry(client, { label = 'first' }),
            hint_entry(client, { label = 'failed' }),
            hint_entry(client, { label = 'second' }),
          },
          function()
            assert(vim.wait(1000, function()
              return #pending == 3
            end))
            pending[3]()
            pending[2]()
            pending[1]()
          end
        )
        return labels
      end)
    )
  end)

  for _, change in ipairs({ 'edit', 'delete' }) do
    it('abandons resolved edits after a buffer ' .. change, function()
      eq(
        { false, true },
        exec_lua(function()
          local reply
          local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
            ['inlayHint/resolve'] = function(_, _, cb)
              reply = cb
            end,
          })
          local buf = vim.api.nvim_get_current_buf()
          local result = run_inlay_action('textEdits', { hint_entry(client) }, function()
            assert(vim.wait(1000, function()
              return reply ~= nil
            end))
            if change == 'edit' then
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'ZZabc' })
            else
              vim.api.nvim_buf_delete(buf, { force = true })
            end
            reply(nil, {
              textEdits = { insert_edit('X') },
            })
          end)
          return {
            result.client_id ~= nil,
            result.buf == buf
              and (
                change == 'delete' or vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == 'ZZabc'
              ),
          }
        end)
      )
    end)
  end

  it('applies text edits from a deferred resolve response', function()
    eq(
      { 'aXbc', true },
      exec_lua(function()
        local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, params, cb)
            params.textEdits = { insert_edit('X', params.position) }
            vim.schedule(function()
              cb(nil, params)
            end)
          end,
        })
        local result = run_inlay_action('textEdits', { hint_entry(client) })
        return { vim.api.nvim_get_current_line(), result.client_id ~= nil }
      end)
    )
  end)

  for _, case in ipairs({
    { 'inlayHint/resolve', 'textEdits' },
    { 'textDocument/hover', 'hover' },
    { 'workspace/executeCommand', 'command' },
  }) do
    local method, action = case[1], case[2]
    it('completes when submitting ' .. method .. ' fails', function()
      eq(
        false,
        exec_lua(function()
          local client, entry = start_action_client(method)
          client.rpc.request = function()
            return false
          end
          local result = run_inlay_action(action, { entry })
          return result.client_id ~= nil
        end)
      )
    end)

    it('completes when the client exits during ' .. method, function()
      local buf, windows = api.nvim_get_current_buf(), api.nvim_list_wins()
      eq(
        { buf = buf },
        exec_lua(function()
          local reply
          local client, entry = start_action_client(method, function(_, _, cb)
            reply = cb
          end)
          local result = run_inlay_action(action, { entry }, function()
            assert(vim.wait(1000, function()
              return reply ~= nil
            end))
            client:stop(true)
          end)
          -- Completion must not depend on a reply, and late replies cannot revive it.
          reply(nil, {
            contents = 'docs',
            textEdits = { insert_edit('X', entry.inlay_hint.position) },
          })
          vim.wait(0)
          return { buf = result.buf, client_id = result.client_id }
        end)
      )
      eq({ 'abc' }, api.nvim_buf_get_lines(buf, 0, -1, false))
      eq(windows, api.nvim_list_wins())
    end)
  end

  it('falls back to another client after a resolve error', function()
    eq(
      2,
      exec_lua(function()
        local first = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, _, cb)
            cb({ code = -32603, message = 'failed' })
          end,
        })
        local second = start_hint_client()
        local result = run_inlay_action('tooltip', {
          hint_entry(first),
          hint_entry(second, { tooltip = 'docs' }),
        })
        return result.client_id
      end)
    )
  end)

  it('skips hint clients without hover support', function()
    eq(
      { false, true, { '# `T`', 'docs' } },
      exec_lua(function()
        local unsupported_request = false
        local first = start_hint_client(nil, {
          ['textDocument/hover'] = function(_, _, cb)
            unsupported_request = true
            cb({ code = -32601, message = 'Method not found' })
          end,
        })
        local second, entry = start_action_client('textDocument/hover', function(_, _, cb)
          cb(nil, { contents = 'docs' })
        end)
        local result = run_inlay_action('hover', {
          hint_entry(first, entry.inlay_hint),
          entry,
        })
        return { unsupported_request, result.client_id == second.id, result.lines }
      end)
    )
  end)

  for _, action in ipairs({ 'location', 'command' }) do
    it('formats ' .. action .. ' choices and handles cancellation', function()
      api.nvim_buf_set_name(0, 'Xhint_source')
      local path = n.fn.fnamemodify(api.nvim_buf_get_name(0), ':~')
      local expected = action == 'command' and { 'A: A (string tooltip)', 'B: B (markup tooltip)' }
        or { ('A\t%s:1'):format(path), ('B\t%s:1'):format(path) }
      eq(
        { expected, false, true },
        exec_lua(function()
          local client = start_hint_client()
          local buf = vim.api.nvim_get_current_buf()
          local formatted
          vim.ui.select = function(items, opts, cb)
            assert(#items == 2)
            formatted = vim.tbl_map(opts.format_item, items)
            cb(nil, nil)
          end
          local labels = {
            { value = 'A', tooltip = 'string tooltip' },
            { value = 'B', tooltip = { kind = 'markdown', value = 'markup tooltip' } },
          }
          for _, label in ipairs(labels) do
            label.location = label_loc(buf)
            label.command = { title = label.value, command = label.value }
          end
          local result = run_inlay_action(action, { hint_entry(client, { label = labels }) })
          return { formatted, result.client_id ~= nil, result.buf == buf }
        end)
      )
    end)
  end

  for _, action in ipairs({ 'hover', 'tooltip' }) do
    it('renders plaintext ' .. action .. ' content literally', function()
      local screen = Screen.new(80, 14)
      local lines = { '*ptr*', '---', '[link](url) &amp; \\path `code`' }
      exec_lua(function()
        vim.cmd('syntax off')
        local contents = { kind = 'plaintext', value = table.concat(lines, '\n') }
        local _, entry = start_action_client('textDocument/hover', function(_, _, cb)
          cb(nil, { contents = contents })
        end)
        entry.inlay_hint.tooltip = { kind = 'plaintext', value = lines[1] .. '\n' .. lines[2] }
        entry.inlay_hint.label[1].tooltip = { kind = 'plaintext', value = lines[3] }
        run_inlay_action(action, { entry })
      end)
      screen:expect({ any = vim.tbl_map(vim.pesc, lines), attr_ids = {} })
    end)
  end

  it('preserves repeated label parts within a hint', function()
    eq(
      { '# `T`', 'docs', '', '# `T`', 'docs' },
      exec_lua(function()
        local client = start_action_client('textDocument/hover', function(_, _, cb)
          cb(nil, { contents = { kind = 'markdown', value = 'docs' } })
        end)
        local loc = label_loc()
        local result = run_inlay_action('hover', {
          hint_entry(client, {
            label = { { value = 'T', location = loc }, { value = 'T', location = loc } },
          }),
        })
        return result.lines
      end)
    )
  end)

  it('retains hover label order with reversed replies and an empty response', function()
    eq(
      { '# `A`', 'docs', '', '# `C`', 'docs' },
      exec_lua(function()
        local pending = {}
        local client = start_action_client('textDocument/hover', function(_, _, cb)
          pending[#pending + 1] = cb
        end)
        local loc = label_loc()
        local result = run_inlay_action('hover', {
          hint_entry(client, {
            label = {
              { value = 'A', location = loc },
              { value = 'B', location = loc },
              { value = 'C', location = loc },
            },
          }),
        }, function()
          assert(vim.wait(1000, function()
            return #pending == 3
          end))
          pending[3](nil, { contents = 'docs' })
          pending[2](nil, nil)
          pending[1](nil, { contents = 'docs' })
        end)
        return result.lines
      end)
    )
  end)

  it('preserves distinct label-only tooltips', function()
    eq(
      { '# `TT`', '', '', '## `T`', '', 'first', '', '## `T`', '', 'second' },
      exec_lua(function()
        local client = start_hint_client()
        local result = run_inlay_action('tooltip', {
          hint_entry(client, {
            label = {
              { value = 'T', tooltip = 'first' },
              { value = 'T', tooltip = 'second' },
            },
          }),
        })
        return vim.api.nvim_buf_get_lines(result.buf, 0, -1, false)
      end)
    )
  end)

  it('does not open a buffer for an unopened hover location', function()
    eq(
      { true, true },
      exec_lua(function()
        local hovered = false
        -- An empty reply keeps a preview buffer from being opened, so any new buffer is
        -- one the request itself created.
        local client = start_action_client('textDocument/hover', function(_, _, cb)
          hovered = true
          cb(nil, nil)
        end)
        local loc = {
          uri = vim.uri_from_fname(vim.fs.abspath('Xhint_unopened')),
          range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 1 } },
        }
        local buffers = #vim.api.nvim_list_bufs()
        run_inlay_action('hover', {
          hint_entry(client, { label = { { value = 'T', location = loc } } }),
        })
        return { #vim.api.nvim_list_bufs() == buffers, hovered }
      end)
    )
  end)

  it('flushes pending changes in the hover target buffer', function()
    eq(
      { 'textDocument/didChange', 'textDocument/hover' },
      exec_lua(function()
        local target = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(target, 'Xhint_target')
        local loc = label_loc(target)
        local client, server = start_hint_client({
          textDocumentSync = 1,
          inlayHintProvider = true,
          hoverProvider = true,
        }, {
          ['textDocument/hover'] = function(_, _, cb)
            cb(nil, nil)
          end,
        }, { debounce_text_changes = 10000 })
        assert(vim.lsp.buf_attach_client(target, client.id))
        server.messages = {}
        vim.api.nvim_buf_set_lines(target, 0, -1, false, { 'new documentation' })
        assert(#server.messages == 0, 'target changes should still be pending')
        run_inlay_action('hover', {
          hint_entry(client, { label = { { value = 'T', location = loc } } }),
        })
        return vim.tbl_map(function(message)
          assert(message.params.textDocument.uri == loc.uri)
          return message.method
        end, server.messages)
      end)
    )
  end)

  it('does not open a hover window for an empty response', function()
    eq(
      { true, false },
      exec_lua(function()
        local client = start_action_client('textDocument/hover', function(_, _, cb)
          cb(nil, nil)
        end)
        local buf = vim.api.nvim_get_current_buf()
        local loc = label_loc(buf)
        local entry = hint_entry(client, { label = { { value = 'T', location = loc } } })
        local windows = #vim.api.nvim_list_wins()
        local result = run_inlay_action('hover', { entry })
        return {
          result.buf == buf and #vim.api.nvim_list_wins() == windows,
          result.client_id ~= nil,
        }
      end)
    )
  end)

  for _, action in ipairs({ 'hover', 'tooltip' }) do
    for _, change in ipairs({ 'buffer', 'cursor' }) do
      it('abandons delayed ' .. action .. ' when the invoking ' .. change .. ' changes', function()
        local buf, windows = api.nvim_get_current_buf(), api.nvim_list_wins()
        eq(
          { buf = buf },
          exec_lua(function()
            local reply
            local method = action == 'hover' and 'textDocument/hover' or 'inlayHint/resolve'
            local _, entry = start_action_client(method, function(_, _, cb)
              reply = cb
            end)
            local result = run_inlay_action(action, { entry }, function()
              assert(vim.wait(1000, function()
                return reply ~= nil
              end))
              if change == 'buffer' then
                vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
              else
                vim.api.nvim_win_set_cursor(0, { 1, 2 })
              end
              reply(nil, { contents = 'docs', tooltip = 'docs' })
            end)
            return { buf = result.buf, client_id = result.client_id }
          end)
        )
        eq(windows, api.nvim_list_wins())
      end)
    end
  end

  it('shows supplied hints from another buffer in the invoking window', function()
    eq(
      true,
      exec_lua(function()
        local client = start_hint_client()
        local source = vim.api.nvim_get_current_buf()
        local entry = hint_entry(client, { tooltip = 'docs' })
        local other = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(other)
        local result = run_inlay_action('tooltip', { entry })
        return result.buf ~= source
          and result.buf ~= other
          and result.client_id == client.id
          and vim.api.nvim_get_current_buf() == other
      end)
    )
  end)

  it('focuses an existing target window when jumping to a location', function()
    eq(
      true,
      exec_lua(function()
        local client = start_hint_client()
        local source_win = vim.api.nvim_get_current_win()
        vim.cmd.vnew()
        local target_win = vim.api.nvim_get_current_win()
        local target_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(target_buf, 'Xhint_target')
        vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, { 'target' })
        vim.api.nvim_set_current_win(source_win)
        local loc = label_loc(target_buf)
        local entry = hint_entry(client, { label = { { value = 'T', location = loc } } })
        local result = run_inlay_action('location', { entry })
        return result.buf == target_buf and vim.api.nvim_get_current_win() == target_win
      end)
    )
  end)

  for _, outcome in ipairs({ 'result', 'error' }) do
    it('completes a server command with a server ' .. outcome, function()
      eq(
        { { command = 'test', arguments = { 42 } }, outcome == 'result' },
        exec_lua(function()
          local failed = outcome == 'error'
          local sent
          local client = start_hint_client({
            inlayHintProvider = true,
            executeCommandProvider = { commands = { 'test' } },
          }, {
            ['workspace/executeCommand'] = function(_, params, cb)
              sent = params
              cb(failed and { code = -32603, message = 'failed' } or nil, nil)
            end,
          })
          local handled = false
          client.handlers['workspace/executeCommand'] = function(err)
            assert((err ~= nil) == failed)
            handled = true
          end
          local entry = hint_entry(client, {
            label = {
              { value = 'T', command = { title = 'Test', command = 'test', arguments = { 42 } } },
            },
          })
          local result = run_inlay_action('command', { entry })
          assert(handled)
          return { sent, result.client_id ~= nil }
        end)
      )
    end)
  end

  for _, scope in ipairs({ 'client', 'global' }) do
    it('completes ' .. scope .. '-side commands that unload their source', function()
      eq(
        { true, true, false },
        exec_lua(function()
          local client, entry = start_action_client('workspace/executeCommand')
          entry.inlay_hint.label[1].command.arguments = { 42 }
          local source = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_name(source, 'Xhint_source')
          vim.bo[source].modified = false
          vim.o.hidden = false
          local target = vim.api.nvim_create_buf(true, false)
          local commands = scope == 'client' and client.commands or vim.lsp.commands
          commands.test = function(cmd, ctx)
            assert(cmd.arguments[1] == 42 and ctx.bufnr == source)
            vim.api.nvim_set_current_buf(target)
          end
          client.rpc.request = function()
            error('unexpected server request')
          end
          local result = run_inlay_action('command', { entry })
          return {
            result.client_id == client.id,
            result.buf == source,
            vim.api.nvim_buf_is_loaded(source),
          }
        end)
      )
    end)
  end

  it('finishes unsupported commands without sending a server request', function()
    eq(
      { true, false },
      exec_lua(function()
        local client = start_hint_client()
        local notified = false
        vim.notify_once = function()
          notified = true
        end
        client.rpc.request = function()
          error('unexpected server request')
        end
        local result = run_inlay_action('command', {
          hint_entry(client, {
            label = {
              { value = 'T', command = { title = 'Test', command = 'test' } },
            },
          }),
        })
        return { notified, result.client_id ~= nil }
      end)
    )
  end)

  it('uses the cursor of the invoking window', function()
    eq(
      'second',
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb' })
        start_hint_client(nil, {
          ['textDocument/inlayHint'] = function(_, _, cb)
            cb(nil, {
              { label = 'first', position = { line = 0, character = 1 } },
              { label = 'second', position = { line = 1, character = 1 } },
            })
          end,
        })
        vim.lsp.inlay_hint.enable(true)
        assert(vim.wait(1000, function()
          return #vim.lsp.inlay_hint.get({ bufnr = 0 }) == 2
        end))
        vim.cmd.vsplit()
        local wins = vim.api.nvim_tabpage_list_wins(0)
        vim.api.nvim_win_set_cursor(wins[1], { 1, 0 })
        vim.api.nvim_win_set_cursor(wins[2], { 2, 0 })
        vim.api.nvim_set_current_win(wins[2])
        local label
        run_inlay_action(capture_hints(function(hints)
          label = hints[1].label
        end))
        return label
      end)
    )
  end)

  it('excludes virtual block segments while retaining real hint boundaries', function()
    eq(
      { 'abc: Td', 'a', '', 'ab: T', 'abc: Td' },
      exec_lua(function()
        local lines = { 'abcd', 'a', '', 'ab', 'abcd' }
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        start_hint_client(nil, {
          ['textDocument/inlayHint'] = function(_, _, cb)
            local hints = {}
            for i, line in ipairs(lines) do
              local pos = { line = i - 1, character = math.min(#line, 3) }
              hints[i] = { label = 'T', position = pos, textEdits = { insert_edit(': T', pos) } }
            end
            cb(nil, hints)
          end,
        })
        vim.lsp.inlay_hint.enable(true)
        assert(vim.wait(1000, function()
          return #vim.lsp.inlay_hint.get({ bufnr = 0 }) == #lines
        end))
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        vim.cmd.normal('\22' .. '4jl')
        return run_inlay_action('textEdits').lines
      end)
    )
  end)

  for _, case in ipairs({
    { 'normal', '' },
    { 'characterwise', 'v' },
    { 'linewise', 'V' },
    { 'blockwise', '\22j' },
    { 'exclusive', 'vj0' },
  }) do
    local mode, keys = case[1], case[2]
    it('selects hints around composing characters in ' .. mode .. ' mode', function()
      local expected = mode == 'blockwise' and { 'left', 'right', 'next' } or { 'left', 'right' }
      eq(
        expected,
        exec_lua(function()
          -- A multibyte base character followed by a combining cedilla.
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'é\204\167', 'abc' })
          start_hint_client({ positionEncoding = 'utf-16', inlayHintProvider = true }, {
            ['textDocument/inlayHint'] = function(_, _, cb)
              cb(nil, {
                { label = 'left', position = { line = 0, character = 0 } },
                { label = 'right', position = { line = 0, character = 2 } },
                { label = 'next', position = { line = 1, character = 0 } },
              })
            end,
          })
          vim.lsp.inlay_hint.enable(true)
          assert(vim.wait(1000, function()
            return #vim.lsp.inlay_hint.get({ bufnr = 0 }) == 3
          end))
          vim.api.nvim_win_set_cursor(0, { 1, 0 })
          if mode == 'exclusive' then
            vim.o.selection = 'exclusive'
          end
          if keys ~= '' then
            vim.cmd.normal(keys)
          end
          local labels
          run_inlay_action(capture_hints(function(hints)
            labels = vim.tbl_map(function(h)
              return h.label
            end, hints)
          end))
          return labels
        end)
      )
    end)
  end
end)
