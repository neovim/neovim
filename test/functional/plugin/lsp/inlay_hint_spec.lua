local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local dedent = t.dedent
local exec_lua = n.exec_lua
local insert = n.insert
local api = n.api

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
        ['textDocument/inlayHint'] = function(_, _, callback)
          callback(nil, vim.json.decode(response))
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
  exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })]])
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
          ['textDocument/inlayHint'] = function(_, _, callback)
            callback(nil, {})
          end,
        }
      })
      client2 = vim.lsp.start({ name = 'dummy2', cmd = server2.cmd })
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    ]])

    exec_lua([[ vim.lsp.stop_client(client2) ]])
    screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
  end)

  describe('enable()', function()
    it('validation', function()
      t.matches(
        'enable: expected boolean, got table',
        t.pcall_err(exec_lua, [[vim.lsp.inlay_hint.enable({}, { bufnr = bufnr })]])
      )
      t.matches(
        'enable: expected boolean, got number',
        t.pcall_err(exec_lua, [[vim.lsp.inlay_hint.enable(42)]])
      )
      t.matches(
        'filter: expected table, got number',
        t.pcall_err(exec_lua, [[vim.lsp.inlay_hint.enable(true, 42)]])
      )
    end)

    describe('clears/applies inlay hints when passed false/true/nil', function()
      before_each(function()
        exec_lua([[
          bufnr2 = vim.api.nvim_create_buf(true, false)
          vim.lsp.buf_attach_client(bufnr2, client_id)
          vim.api.nvim_win_set_buf(0, bufnr2)
        ]])
        insert(text)
        exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr2 })]])
        exec_lua([[vim.api.nvim_win_set_buf(0, bufnr)]])
        screen:expect({ grid = grid_with_inlay_hints })
      end)

      it('for one single buffer', function()
        exec_lua([[
          vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
          vim.api.nvim_win_set_buf(0, bufnr2)
        ]])
        screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
        exec_lua([[vim.api.nvim_win_set_buf(0, bufnr)]])
        screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

        exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })]])
        screen:expect({ grid = grid_with_inlay_hints, unchanged = true })

        exec_lua(
          [[vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })]]
        )
        screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

        exec_lua([[vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })]])
        screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
      end)

      it('for all buffers', function()
        exec_lua([[vim.lsp.inlay_hint.enable(false)]])
        screen:expect({ grid = grid_without_inlay_hints, unchanged = true })
        exec_lua([[vim.api.nvim_win_set_buf(0, bufnr2)]])
        screen:expect({ grid = grid_without_inlay_hints, unchanged = true })

        exec_lua([[vim.lsp.inlay_hint.enable(true)]])
        screen:expect({ grid = grid_with_inlay_hints, unchanged = true })
        exec_lua([[vim.api.nvim_win_set_buf(0, bufnr)]])
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

      exec_lua(
        [[
        local expected2 = ...
        server2 = _create_server({
          capabilities = {
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function(_, _, callback)
              callback(nil, { expected2 })
            end,
          }
        })
        client2 = vim.lsp.start({ name = 'dummy2', cmd = server2.cmd })
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
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
