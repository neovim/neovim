local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')
local Screen = require('test.functional.ui.screen')

local dedent = t.dedent
local eq = t.eq

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

  local grid_without_candidates = dedent([[
    function fibonacci()                                 |
    ^                                                     |
    {1:~                                                    }|*11
                                                         |
  ]])

  local grid_with_candidates = dedent([[
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
    {3:-- INSERT --}                                         |
  ]])

  local grid_applied_candidates = dedent([[
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

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)

    screen = Screen.new()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [3] = { bold = true },
    })

    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          inlineCompletionProvider = true,
        },
        handlers = {
          ['textDocument/inlineCompletion'] = function(_, _, callback)
            if _G.empty then
              callback(nil, {
                items = {
                  {
                    insertText = 'foobar',
                    range = {
                      start = {
                        line = 0,
                        character = 19,
                      },
                      ['end'] = {
                        line = 0,
                        character = 19,
                      },
                    },
                  },
                },
              })
              return
            end

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
    exec_lua(function()
      vim.lsp.inline_completion.enable()
    end)
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  describe('enable()', function()
    it('requests or abort when entered/left insert mode', function()
      screen:expect({ grid = grid_without_candidates })
      feed('i')
      screen:expect({ grid = grid_with_candidates })
      feed('<Esc>')
      screen:expect({ grid = grid_without_candidates })
    end)

    it('no request when leaving insert mode immediately after typing', function()
      screen:expect({ grid = grid_without_candidates })
      feed('ifoobar<Esc>')
      screen:expect([[
        function fibonacci()                                 |
        fooba^r                                               |
        {1:~                                                    }|*11
                                                             |
      ]])
      screen:expect_unchanged(false, 500)
    end)
  end)

  describe('get()', function()
    it('applies the current candidate', function()
      feed('i')
      screen:expect({ grid = grid_with_candidates })
      exec_lua(function()
        vim.lsp.inline_completion.get()
      end)
      n.poke_eventloop()
      feed('<Esc>')
      screen:expect({ grid = grid_applied_candidates })
    end)

    it('correctly displays with absent/empty range', function()
      exec_lua(function()
        _G.empty = true
      end)
      feed('I')
      screen:expect([[
        function fibonacci({1:foobar})                           |
        ^                                                     |
        {1:~                                                    }|*11
        {3:-- INSERT --}                                         |
      ]])
    end)

    it('accepts on_accept callback', function()
      feed('i')
      screen:expect({ grid = grid_with_candidates })
      local result = exec_lua(function()
        ---@type vim.lsp.inline_completion.Item
        local result
        vim.lsp.inline_completion.get({
          on_accept = function(item)
            result = item
          end,
        })
        vim.wait(1000, function()
          return result ~= nil
        end) -- Wait for async callback.
        return result
      end)
      feed('<Esc>')
      screen:expect({ grid = grid_without_candidates })
      eq({
        _index = 1,
        client_id = 1,
        command = {
          command = 'dummy',
          title = 'Completion Accepted',
        },
        insert_text = dedent([[
        function fibonacci(n) {
          if (n <= 0) return 0;
          if (n === 1) return 1;

          let a = 0, b = 1, c;
          for (let i = 2; i <= n; i++) {
            c = a + b;
            a = b;
            b = c;
          }
          return b;
        }]]),
        range = {
          end_ = {
            buf = 1,
            col = 20,
            row = 0,
          },
          start = {
            buf = 1,
            col = 0,
            row = 0,
          },
        },
      }, result)
    end)
  end)

  describe('select()', function()
    it('selects the next candidate', function()
      feed('i')
      screen:expect({ grid = grid_with_candidates })

      exec_lua(function()
        vim.lsp.inline_completion.select()
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
        {3:-- INSERT --}                                         |
      ]])
      exec_lua(function()
        vim.lsp.inline_completion.get()
      end)
      n.poke_eventloop()
      feed('<Esc>')
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
