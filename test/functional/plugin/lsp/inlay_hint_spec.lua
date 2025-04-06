local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
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

  local response = [==[
[
{"kind":1,"paddingLeft":false,"label":"-> int","position":{"character":22,"line":0},"paddingRight":false},
{"kind":2,"paddingLeft":false,"label":"a:","position":{"character":15,"line":5},"paddingRight":true},
{"kind":2,"paddingLeft":false,"label":"b:","position":{"character":17,"line":5},"paddingRight":true}
]
]==]

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
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, vim.json.decode(response))
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
      vim.lsp.stop_client(client_id)
    end)
    screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
  end)

  it('does not clear inlay hints when one of several clients detaches', function()
    local client_id2 = exec_lua(function()
      _G.server2 = _G._create_server({
        capabilities = {
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, {})
          end,
        },
      })
      local client_id2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      return client_id2
    end)

    exec_lua(function()
      vim.lsp.stop_client(client_id2)
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
        exec_lua(function()
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr2 })
        end)
        n.api.nvim_win_set_buf(0, bufnr)
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
  end)

  describe('get()', function()
    it('returns filtered inlay hints', function()
      --- @type lsp.InlayHint[]
      local expected = vim.json.decode(response)
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
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function(_, _, callback)
              callback(nil, { expected2 })
            end,
          },
        })
        _G.client2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end)

      --- @type vim.lsp.inlay_hint.get.ret
      eq(
        {
          { bufnr = 1, client_id = 1, inlay_hint = expected[1] },
          { bufnr = 1, client_id = 1, inlay_hint = expected[2] },
          { bufnr = 1, client_id = 1, inlay_hint = expected[3] },
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
          { bufnr = 1, client_id = 1, inlay_hint = expected[2] },
          { bufnr = 1, client_id = 1, inlay_hint = expected[3] },
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

    it('does not request hints from lsp when disabled', function()
      exec_lua(function()
        _G.server2 = _G._create_server({
          capabilities = {
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function(_, _, callback)
              _G.got_inlay_hint_request = true
              callback(nil, {})
            end,
          },
        })
        _G.client2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server2.cmd })
      end)

      local function was_request_sent()
        return exec_lua(function()
          return _G.got_inlay_hint_request == true
        end)
      end

      eq(false, was_request_sent())

      exec_lua(function()
        vim.lsp.inlay_hint.get()
      end)

      eq(false, was_request_sent())

      exec_lua(function()
        vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
        vim.lsp.inlay_hint.get()
      end)

      eq(false, was_request_sent())

      exec_lua(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end)

      eq(true, was_request_sent())
    end)
  end)
end)

describe('Inlay hints handler', function()
  local text = dedent([[
test text
  ]])

  local response = [==[
  [
      { "position": { "line": 0, "character": 0 }, "label": "0" },
      { "position": { "line": 0, "character": 0 }, "label": "1" },
      { "position": { "line": 0, "character": 0 }, "label": "2" },
      { "position": { "line": 0, "character": 0 }, "label": "3" },
      { "position": { "line": 0, "character": 0 }, "label": "4" }
  ]
  ]==]

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
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, vim.json.decode(response))
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
      vim.lsp.stop_client(client_id)
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
