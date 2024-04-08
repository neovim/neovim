local t = require('test.functional.testutil')(after_each)
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local dedent = t.dedent
local exec_lua = t.exec_lua
local insert = t.insert
local api = t.api

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

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
before_each(function()
  clear_notrace()
  screen = Screen.new(50, 9)
  screen:attach()

  exec_lua(create_server_definition)
  exec_lua(
    [[
    local response = ...
    server = _create_server({
      capabilities = {
        inlayHintProvider = true,
      },
      handlers = {
        ['textDocument/inlayHint'] = function()
          return vim.json.decode(response)
        end,
      }
    })

    bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(0, bufnr)

    client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
  ]],
    response
  )

  insert(text)
  exec_lua([[vim.lsp.inlay_hint.enable(bufnr)]])
  screen:expect({ grid = grid_with_inlay_hints })
end)

after_each(function()
  api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
end)

describe('vim.lsp.inlay_hint', function()
  it('clears inlay hints when sole client detaches', function()
    exec_lua([[vim.lsp.stop_client(client_id)]])
    screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
  end)

  it('does not clear inlay hints when one of several clients detaches', function()
    exec_lua([[
      server2 = _create_server({
        capabilities = {
          inlayHintProvider = true,
        },
        handlers = {
          ['textDocument/inlayHint'] = function()
            return {}
          end,
        }
      })
      client2 = vim.lsp.start({ name = 'dummy2', cmd = server2.cmd })
      vim.lsp.inlay_hint.enable(bufnr)
    ]])

    exec_lua([[ vim.lsp.stop_client(client2) ]])
    screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
  end)

  describe('enable()', function()
    it('clears/applies inlay hints when passed false/true/nil', function()
      exec_lua([[vim.lsp.inlay_hint.enable(bufnr, false)]])
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

      exec_lua([[vim.lsp.inlay_hint.enable(bufnr, true)]])
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })

      exec_lua([[vim.lsp.inlay_hint.enable(bufnr, not vim.lsp.inlay_hint.is_enabled(bufnr))]])
      screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

      exec_lua([[vim.lsp.inlay_hint.enable(bufnr)]])
      screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
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

      exec_lua(
        [[
        local expected2 = ...
        server2 = _create_server({
          capabilities = {
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function()
              return { expected2 }
            end,
          }
        })
        client2 = vim.lsp.start({ name = 'dummy2', cmd = server2.cmd })
        vim.lsp.inlay_hint.enable(bufnr)
      ]],
        expected2
      )

      --- @type vim.lsp.inlay_hint.get.ret
      local res = exec_lua([[return vim.lsp.inlay_hint.get()]])
      eq({
        { bufnr = 1, client_id = 1, inlay_hint = expected[1] },
        { bufnr = 1, client_id = 1, inlay_hint = expected[2] },
        { bufnr = 1, client_id = 1, inlay_hint = expected[3] },
        { bufnr = 1, client_id = 2, inlay_hint = expected2 },
      }, res)

      --- @type vim.lsp.inlay_hint.get.ret
      res = exec_lua([[return vim.lsp.inlay_hint.get({
        range = {
          start = { line = 2, character = 10 },
          ["end"] = { line = 2, character = 10 },
        },
      })]])
      eq({
        { bufnr = 1, client_id = 2, inlay_hint = expected2 },
      }, res)

      --- @type vim.lsp.inlay_hint.get.ret
      res = exec_lua([[return vim.lsp.inlay_hint.get({
        bufnr = vim.api.nvim_get_current_buf(),
        range = {
          start = { line = 4, character = 18 },
          ["end"] = { line = 5, character = 17 },
        },
      })]])
      eq({
        { bufnr = 1, client_id = 1, inlay_hint = expected[2] },
        { bufnr = 1, client_id = 1, inlay_hint = expected[3] },
      }, res)

      --- @type vim.lsp.inlay_hint.get.ret
      res = exec_lua([[return vim.lsp.inlay_hint.get({
        bufnr = vim.api.nvim_get_current_buf() + 1,
      })]])
      eq({}, res)
    end)
  end)
end)
