local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local dedent = t.dedent

local api = n.api
local exec_lua = n.exec_lua
local insert = n.insert
local feed = n.feed

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.inline_completion', function()
  local text = dedent([[
function fibonacci()
]])

  local grid_without_candidates = [[
  function fibonacci()                                 |
  ^                                                     |
  {1:~                                                    }|*11
                                                       |
]]

  local grid_with_candidates = [[
  function fibonacci({1:n) {}                              |
  {1:  if (n <= 0) return 0;}                              |
  {1:  if (n === 1) return 1;}                             |
                                                       |
  {1:  let a = 0, b = 1, c;}                               |
  {1:  for (let i = 2; i <= n; i++) {}                     |
  {1:    c = a + b;}                                       |
  {1:    a = b;}                                           |
  {1:    b = c;}                                           |
  {1:  }}                                                  |
  {1:  return b;}                                          |
  {1:}}                                                    |
  ^                                                     |
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
    exec_lua(create_server_definition)

    screen = Screen.new()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Magenta, bold = true },
    })

    bufnr = n.api.nvim_get_current_buf()
    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          inlineCompletionProvider = true,
        },
        handlers = {
          ['textDocument/inlineCompletion'] = function(_, _, callback)
            callback(nil, {
              items = {
                {
                  command = {
                    command = 'dummy',
                    title = 'Completion Accepted',
                  },
                  insertText = 'function fibonacci(n) {\n  if (n <= 0) return 0;\n  if (n === 1) return 1;\n\n  let a = 0, b = 1, c;\n  for (let i = 2; i <= n; i++) {\n    c = a + b;\n    a = b;\n    b = c;\n  }\n  return b;\n}',
                  range = {
                    ['end'] = {
                      character = 20,
                      line = 0,
                    },
                    start = {
                      character = 0,
                      line = 0,
                    },
                  },
                },
                {
                  command = {
                    command = 'dummy',
                    title = 'Completion Accepted',
                  },
                  insertText = 'function fibonacci(n) {\n  if (n <= 0) return 0;\n  if (n === 1) return 1;\n\n  let a = 0, b = 1, c;\n  for (let i = 2; i <= n; i++) {\n    c = a + b;\n    a = b;\n    b = c;\n  }\n  return c;\n}',
                  range = {
                    ['end'] = {
                      character = 20,
                      line = 0,
                    },
                    start = {
                      character = 0,
                      line = 0,
                    },
                  },
                },
                {
                  command = {
                    command = 'dummy',
                    title = 'Completion Accepted',
                  },
                  insertText = 'function fibonacci(n) {\n  if (n < 0) {\n    throw new Error("Input must be a non-negative integer.");\n  }\n  if (n === 0) return 0;\n  if (n === 1) return 1;\n\n  let a = 0, b = 1, c;\n  for (let i = 2; i <= n; i++) {\n    c = a + b;\n    a = b;\n    b = c;\n  }\n  return b;\n}',
                  range = {
                    ['end'] = {
                      character = 20,
                      line = 0,
                    },
                    start = {
                      character = 0,
                      line = 0,
                    },
                  },
                },
              },
            })
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    exec_lua(function()
      local client = assert(vim.lsp.get_client_by_id(client_id))
      _G.called = false
      client.commands.dummy = function()
        _G.called = true
      end
    end)

    insert(text)
    feed('$')
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  describe('accept()', function()
    it('requests new inline completions or accepts the current candidate', function()
      screen:expect({ grid = grid_without_candidates })

      exec_lua(function()
        vim.lsp.inline_completion.accept()
      end)

      screen:expect({ grid = grid_with_candidates })

      exec_lua(function()
        vim.lsp.inline_completion.accept()
      end)

      screen:expect([[
  function fibonacci(n) {                              |
    if (n <= 0) return 0;                              |
    if (n === 1) return 1;                             |
                                                       |
    let a = 0, b = 1, c;                               |
    for (let i = 2; i <= n; i++) {                     |
      c = a + b;                                       |
      a = b;                                           |
      b = c;                                           |
    }                                                  |
    return b;                                          |
  ^}                                                    |
                                                       |*2
]])
    end)
  end)

  describe('jump()', function()
    it('jumps to the next candidate', function()
      exec_lua(function()
        vim.lsp.inline_completion.accept()
      end)

      screen:expect({ grid = grid_with_candidates })

      exec_lua(function()
        vim.lsp.inline_completion.jump()
      end)

      screen:expect([[
  function fibonacci({1:n) {}                              |
  {1:  if (n <= 0) return 0;}                              |
  {1:  if (n === 1) return 1;}                             |
                                                       |
  {1:  let a = 0, b = 1, c;}                               |
  {1:  for (let i = 2; i <= n; i++) {}                     |
  {1:    c = a + b;}                                       |
  {1:    a = b;}                                           |
  {1:    b = c;}                                           |
  {1:  }}                                                  |
  {1:  return c;}                                          |
  {1:}}{2: (2/3)}                                              |
  ^                                                     |
                                                       |
]])
      exec_lua(function()
        vim.lsp.inline_completion.accept()
      end)

      screen:expect([[
  function fibonacci(n) {                              |
    if (n <= 0) return 0;                              |
    if (n === 1) return 1;                             |
                                                       |
    let a = 0, b = 1, c;                               |
    for (let i = 2; i <= n; i++) {                     |
      c = a + b;                                       |
      a = b;                                           |
      b = c;                                           |
    }                                                  |
    return c;                                          |
  ^}                                                    |
                                                       |*2
]])
    end)
  end)
end)
