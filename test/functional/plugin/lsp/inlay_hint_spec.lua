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

--- Installs the shared action driver in the child process:
--- * `run_inlay_action(action, hints?, during?)` runs an action, checks the completion
---   contract, and reports the buffer left in focus. `during` runs after `action()`
---   returns but before waiting for it to finish.
--- * `capture_hints(record)` is an action handler that records the hints it is given.
local function setup_action_driver()
  exec_lua(function()
    --- @return {buf: integer, client_id: integer?, win: integer?, lines: string[]?}
    function _G.run_inlay_action(action, hints, during)
      local result ---@type table?
      local calls, returned = 0, false
      vim.lsp.inlay_hint.action(action, {
        hints = hints,
        on_done = function(ctx)
          assert(returned, 'on_done must be asynchronous')
          calls = calls + 1
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
      assert(calls == 1, 'on_done must run exactly once')
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
  ---@type table<string, {lines: string[], name: string, filetype: string, bufnr: integer?, uri: string}>
  local mocked_files = {
    main = {
      lines = {
        'use dummy::MyStruct;',
        '',
        'fn process_my_struct(data: MyStruct) {',
        '    println!("Received MyStruct with value: {}", data.value);',
        '}',
        '',
        'fn main() {',
        '    let my_instance = MyStruct::new(42);',
        '    let _MyInstance = MyStruct::new(43);',
        '    process_my_struct(my_instance);',
        '}',
      },
      name = 'src/main.rs',
      uri = 'file:///src/main.rs',
      filetype = 'rust',
      bufnr = nil,
    },
    lib = {
      lines = {
        'pub struct MyStruct {',
        '    pub value: i32,',
        '}',
        '',
        'impl MyStruct {',
        '    pub fn new(value: i32) -> Self {',
        '        MyStruct { value }',
        '    }',
        '}',
      },
      name = 'src/lib.rs',
      uri = 'file:///src/lib.rs',
      filetype = 'rust',
      bufnr = nil,
    },
  }

  --- The location all `MyStruct` label parts point at (the struct definition in lib.rs).
  ---@type lsp.Location
  local lib_location = {
    uri = mocked_files.lib.uri,
    range = {
      start = { line = 0, character = 11 },
      ['end'] = { line = 0, character = 19 },
    },
  }

  --- The hints as they look after `inlayHint/resolve`.
  ---@type lsp.InlayHint[]
  local resolved_response = {
    {
      label = {
        { value = ': ' },
        {
          value = 'MyStruct',
          location = lib_location,
          command = { title = 'Dummy command', command = 'dummy_command' },
          tooltip = 'string tooltip',
        },
      },
      tooltip = { kind = 'plaintext', value = 'plaintext markup tooltip' },
      position = { line = 7, character = 19 },
      textEdits = {
        {
          newText = ': MyStruct',
          range = {
            start = { line = 7, character = 19 },
            ['end'] = { line = 7, character = 19 },
          },
        },
      },
      data = { id = 1 },
    },
    {
      label = {
        { value = ': ' },
        {
          value = 'MyStruct',
          location = lib_location,
          tooltip = 'string tooltip',
        },
      },
      tooltip = { kind = 'plaintext', value = 'plaintext markup tooltip' },
      position = { line = 8, character = 19 },
      textEdits = {
        {
          newText = ': MyStruct',
          range = {
            start = { line = 8, character = 19 },
            ['end'] = { line = 8, character = 19 },
          },
        },
      },
      data = { id = 2 },
    },
    {
      label = { { value = 'data:' } },
      position = { line = 9, character = 22 },
      data = { id = 3 },
    },
  }

  --- The hints as initially returned by `textDocument/inlayHint` (this shape is taken from
  --- basedpyright): hint 1 only carries its location/command/tooltip/textEdits after
  --- `inlayHint/resolve`.
  ---@type lsp.InlayHint[]
  local orig_response = vim.deepcopy(resolved_response)
  orig_response[1].label[2] = { value = 'MyStruct' }
  orig_response[1].tooltip = nil
  orig_response[1].textEdits = nil

  local curr_winid ---@type integer?
  local offset_encoding = 'utf-8'
  local client_id ---@type integer?

  -- Upper bound for the `vim.wait` calls; they all use a condition to stop early.
  local wait_time = 5000

  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)

    mocked_files = exec_lua(function()
      for _, item in pairs(mocked_files) do
        item.bufnr = vim.uri_to_bufnr(item.uri)
        local full_path = vim.uri_to_fname(item.uri)
        vim.api.nvim_buf_set_name(item.bufnr, full_path)
        vim.api.nvim_buf_set_lines(item.bufnr, 0, -1, false, item.lines)
        vim.api.nvim_cmd({ cmd = 'edit', args = { full_path }, bang = true }, {})
      end
      return mocked_files
    end)

    exec_lua(function()
      _G.command_called = {}
      _G.server = _G._create_server({
        capabilities = {
          inlayHintProvider = { resolveProvider = true },
          executeCommandProvider = { commands = { 'dummy_command' } },
        },
        handlers = {
          ['workspace/executeCommand'] = function(_, param, callback)
            table.insert(_G.command_called, param)
            callback(nil, {})
          end,
          ---@param param lsp.InlayHintParams
          ['textDocument/inlayHint'] = function(_, param, callback)
            local buf = vim.uri_to_bufnr(param.textDocument.uri)
            local requested_range = vim.range.lsp(buf, param.range, offset_encoding)
            local range_start = vim.pos(buf, requested_range.start_row, requested_range.start_col)
            local range_end = vim.pos(buf, requested_range.end_row, requested_range.end_col)
            local filtered_hints = vim
              .iter(orig_response)
              :filter(
                ---@param hint lsp.InlayHint
                function(hint)
                  local hint_pos = vim.pos.lsp(buf, hint.position, offset_encoding)
                  return hint_pos >= range_start and hint_pos < range_end
                end
              )
              :totable()
            return callback(nil, filtered_hints)
          end,
          ---@param params lsp.InlayHint
          ['inlayHint/resolve'] = function(_, params, callback)
            if params.data and params.data.id then
              callback(nil, resolved_response[params.data.id])
            else
              callback(nil, params)
            end
          end,
          ---@param params lsp.HoverParams
          ['textDocument/hover'] = function(_, params, callback)
            local pos = params.position
            if
              params.textDocument.uri == mocked_files.lib.uri
              and pos.line == 0
              and pos.character >= 11
              and pos.character < 19
            then
              callback(nil, {
                contents = {
                  kind = 'markdown',
                  value = '\n```rust\ndummy\n```\n\n```rust\npub struct MyStruct {\n    pub value: i32,\n}\n```\n\n---\n\nsize = 4, align = 0x4',
                },
                range = lib_location.range,
              })
            else
              callback()
            end
          end,
        },
      })

      client_id =
        vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd, offset_encoding = offset_encoding })
      vim.wait(wait_time, function()
        return vim.lsp.get_client_by_id(assert(client_id)).initialized
      end)
      if client_id then
        vim.lsp.buf_attach_client(mocked_files.main.bufnr, client_id)
        vim.lsp.buf_attach_client(mocked_files.lib.bufnr, client_id)
        vim.lsp.inlay_hint.enable(true, { bufnr = mocked_files.main.bufnr })
      end
    end)

    exec_lua(function()
      vim.api.nvim_cmd({ cmd = 'buf', args = { tostring(mocked_files.main.bufnr) } }, {})
      curr_winid = vim.api.nvim_get_current_win()
    end)

    setup_action_driver()
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  --- Runs the named action on the hints in the given range of the main file.
  --- @param action vim.lsp.inlay_hint.action.name
  --- @param start_pos [integer, integer] 0-indexed (line, character) LSP position
  --- @param end_pos [integer, integer] 0-indexed (line, character) LSP position
  --- @return {buf: integer, client_id: integer?, win: integer?, lines: string[]?}
  local function run_action(action, start_pos, end_pos)
    return exec_lua(function()
      return _G.run_inlay_action(
        action,
        vim.lsp.inlay_hint.get({
          bufnr = mocked_files.main.bufnr,
          range = {
            start = { line = start_pos[1], character = start_pos[2] },
            ['end'] = { line = end_pos[1], character = end_pos[2] },
          },
        })
      )
    end)
  end

  --- Counts the hints `action()` picks up from the cursor at `from`, or from the charwise
  --- selection between `from` and `to`.
  --- @param from [integer, integer] (1,0)-indexed cursor position
  --- @param to? [integer, integer] (1,0)-indexed end of the visual selection
  --- @return integer
  local function count_selected_hints(from, to)
    return exec_lua(function()
      vim.api.nvim_win_set_cursor(curr_winid, from)
      if to then
        vim.cmd.normal('v')
        vim.api.nvim_win_set_cursor(curr_winid, to)
      end
      local count ---@type integer?
      _G.run_inlay_action(_G.capture_hints(function(hints)
        count = #hints
      end))
      return assert(count)
    end)
  end

  it('uses hints on either side of the cursor in normal mode', function()
    assert(curr_winid)
    eq(1, count_selected_hints({ 8, 18 }))
  end)

  it('uses hints inside the selection in visual mode', function()
    assert(curr_winid)
    eq(2, count_selected_hints({ 8, 0 }, { 9, 30 }))
  end)

  it('invokes on_done without a client when no action was taken', function()
    local ctx = exec_lua(function()
      local done_ctx ---@type table?
      vim.lsp.inlay_hint.action(function()
        return false
      end, {
        hints = {},
        on_done = function(ctx)
          done_ctx = ctx
        end,
      })
      vim.wait(wait_time, function()
        return done_ctx ~= nil
      end)
      return assert(done_ctx)
    end)

    eq(nil, ctx.client)
  end)

  describe('textEdits', function()
    it('inserts the textEdits', function()
      local result = run_action('textEdits', { 7, 18 }, { 8, 20 })
      eq('let my_instance: MyStruct = MyStruct::new(42);', vim.trim(result.lines[8]))
      eq('let _MyInstance: MyStruct = MyStruct::new(43);', vim.trim(result.lines[9]))
    end)

    it('does NOT insert when the hint has no textEdits', function()
      eq(mocked_files.main.lines, run_action('textEdits', { 9, 21 }, { 9, 24 }).lines)
    end)
  end)

  describe('location', function()
    it('jumps to the location when provided', function()
      eq(mocked_files.lib.bufnr, run_action('location', { 7, 18 }, { 7, 20 }).buf)
    end)

    it('does NOT jump when the hint has no location', function()
      eq(mocked_files.main.bufnr, run_action('location', { 9, 21 }, { 9, 24 }).buf)
    end)
  end)

  describe('tooltip', function()
    it('shows the tooltip in a floating window', function()
      -- The path in the tooltip is rendered relative to the client root (unset here), falling
      -- back to the full path, so it depends on the platform.
      local lib_path = exec_lua(function()
        return vim.fn.fnamemodify(vim.uri_to_fname(mocked_files.lib.uri), ':p:~')
      end)

      local result = run_action('tooltip', { 7, 18 }, { 7, 20 })
      neq(mocked_files.main.bufnr, result.buf)
      neq(curr_winid, result.win)
      eq({
        '# `: MyStruct`',
        '',
        'plaintext markup tooltip',
        '',
        '## `MyStruct`',
        '',
        'string tooltip',
        ('_Location_: `%s`:0'):format(lib_path),
        '_Command_: Dummy command',
      }, result.lines)
    end)

    it('does NOT show a tooltip when the hint has none', function()
      local buf_count = #api.nvim_list_bufs()
      run_action('tooltip', { 9, 21 }, { 9, 24 })
      eq(buf_count, #api.nvim_list_bufs())
    end)
  end)

  describe('hover', function()
    local ref_hover = {
      '# `MyStruct`',
      '```rust',
      'dummy',
      '```',
      '',
      '```rust',
      'pub struct MyStruct {',
      '    pub value: i32,',
      '}',
      '```',
      '',
      '---',
      '',
      'size = 4, align = 0x4',
    }

    it('shows hover info of the label location in a floating window', function()
      local result = run_action('hover', { 7, 18 }, { 7, 20 })
      neq(mocked_files.main.bufnr, result.buf)
      neq(curr_winid, result.win)
      eq(ref_hover, result.lines)
    end)

    it('does NOT show hover when the hint has no location', function()
      local buf_count = #api.nvim_list_bufs()
      run_action('hover', { 9, 21 }, { 9, 24 })
      eq(buf_count, #api.nvim_list_bufs())
    end)
  end)

  describe('command', function()
    --- @param start_pos [integer, integer]
    --- @param end_pos [integer, integer]
    --- @return integer
    local function commands_called(start_pos, end_pos)
      run_action('command', start_pos, end_pos)
      return exec_lua(function()
        return #_G.command_called
      end)
    end

    it('executes the command when available', function()
      eq(1, commands_called({ 7, 18 }, { 7, 20 }))
    end)

    it('does NOT execute a command when the hint has none', function()
      eq(0, commands_called({ 9, 21 }, { 9, 24 }))
    end)
  end)
end)

describe('vim.lsp.inlay_hint.action edge cases', function()
  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })

      function _G.start_hint_client(capabilities, handlers)
        handlers = handlers or {}
        handlers['textDocument/inlayHint'] = handlers['textDocument/inlayHint']
          or function(_, _, cb)
            cb(nil, {})
          end
        local server = _G._create_server({
          capabilities = capabilities or { inlayHintProvider = true },
          handlers = handlers,
        })
        local id = assert(vim.lsp.start({ name = 'hints', cmd = server.cmd }, {
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
          textEdits = {
            {
              newText = 'X',
              range = {
                start = { line = 0, character = 1 },
                ['end'] = { line = 0, character = 1 },
              },
            },
          },
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

  it('retains hint order when resolve responses arrive in reverse order', function()
    eq(
      { 'first', 'second' },
      exec_lua(function()
        local pending = {}
        local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, params, cb)
            pending[#pending + 1] = function()
              cb(nil, params)
            end
          end,
        })
        local labels
        run_inlay_action(
          capture_hints(function(hints)
            labels = { hints[1].label, hints[2].label }
          end),
          { hint_entry(client, { label = 'first' }), hint_entry(client, { label = 'second' }) },
          function()
            assert(vim.wait(1000, function()
              return #pending == 2
            end))
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
              textEdits = {
                {
                  newText = 'X',
                  range = {
                    start = { line = 0, character = 1 },
                    ['end'] = { line = 0, character = 1 },
                  },
                },
              },
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

  it('rechecks the buffer before applying scheduled text edits', function()
    eq(
      { 'changed', false },
      exec_lua(function()
        local client = start_hint_client({ inlayHintProvider = { resolveProvider = true } }, {
          ['inlayHint/resolve'] = function(_, params, cb)
            params.textEdits = {
              { newText = 'X', range = { start = params.position, ['end'] = params.position } },
            }
            cb(nil, params)
            -- The response scheduled the edit, but it has not run yet.
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })
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
          local client = start_hint_client({
            inlayHintProvider = { resolveProvider = method == 'inlayHint/resolve' },
            executeCommandProvider = { commands = { 'test' } },
          })
          client.rpc.request = function()
            return false
          end
          local loc = label_loc()
          local result = run_inlay_action(action, {
            hint_entry(client, {
              label = {
                { value = 'T', location = loc, command = { title = 'Test', command = 'test' } },
              },
            }),
          })
          return result.client_id ~= nil
        end)
      )
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

  for _, action in ipairs({ 'location', 'command' }) do
    it('finishes without a client when ' .. action .. ' selection is cancelled', function()
      eq(
        { true, false, true },
        exec_lua(function()
          local client = start_hint_client()
          local buf = vim.api.nvim_get_current_buf()
          local selected = false
          vim.ui.select = function(items, _, cb)
            assert(#items == 2)
            selected = true
            cb(nil, nil)
          end
          local loc = label_loc(buf)
          local result = run_inlay_action(action, {
            hint_entry(client, {
              label = {
                { value = 'A', location = loc, command = { title = 'A', command = 'a' } },
                { value = 'B', location = loc, command = { title = 'B', command = 'b' } },
              },
            }),
          })
          return { selected, result.client_id ~= nil, result.buf == buf }
        end)
      )
    end)
  end

  it('deduplicates identical label locations within a hint', function()
    eq(
      { '# `T`', 'docs' },
      exec_lua(function()
        local client = start_hint_client(nil, {
          ['textDocument/hover'] = function(_, _, cb)
            cb(nil, { contents = { kind = 'markdown', value = 'docs' } })
          end,
        })
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

  it('does not open a hover window for an empty response', function()
    eq(
      { true, false },
      exec_lua(function()
        local client = start_hint_client(nil, {
          ['textDocument/hover'] = function(_, _, cb)
            cb(nil, nil)
          end,
        })
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
    it('executes ' .. scope .. '-side commands locally', function()
      eq(
        { true, true },
        exec_lua(function()
          local client = start_hint_client()
          local called = false
          local commands = scope == 'client' and client.commands or vim.lsp.commands
          commands.test = function(cmd, ctx)
            assert(cmd.arguments[1] == 42 and ctx.bufnr == vim.api.nvim_get_current_buf())
            called = true
          end
          client.rpc.request = function()
            error('unexpected server request')
          end
          local result = run_inlay_action('command', {
            hint_entry(client, {
              label = {
                {
                  value = 'T',
                  command = { title = 'Test', command = 'test', arguments = { 42 } },
                },
              },
            }),
          })
          return { called, result.client_id == client.id }
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

  for _, case in ipairs({
    { 'normal', '' },
    { 'characterwise', 'v' },
    { 'linewise', 'V' },
    { 'blockwise', '\22j' },
    { 'exclusive', 'vj0' },
  }) do
    local mode, keys = case[1], case[2]
    it('selects multibyte hint boundaries in ' .. mode .. ' mode', function()
      local expected = mode == 'blockwise' and { 'left', 'right', 'next' } or { 'left', 'right' }
      eq(
        expected,
        exec_lua(function()
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'é', 'abc' })
          start_hint_client({ positionEncoding = 'utf-16', inlayHintProvider = true }, {
            ['textDocument/inlayHint'] = function(_, _, cb)
              cb(nil, {
                { label = 'left', position = { line = 0, character = 0 } },
                { label = 'right', position = { line = 0, character = 1 } },
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
