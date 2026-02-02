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

describe('vim.lsp.codelens', function()
  local text = dedent([[
    struct S {
        a: i32,
        b: String,
    }

    impl S {
        fn new(a: i32, b: String) -> Self {
            S { a, b }
        }
    }

    fn main() {
        let s = S::new(42, String::from("Hello, world!"));
        println!("S.a: {}, S.b: {}", s.a, s.b);
    }
  ]])

  local grid_with_lenses = dedent([[
    struct S { {1:1 implementation}                          |
        a: i32,                                          |
        b: String,                                       |
    }                                                    |
                                                         |
    impl S {                                             |
        fn new(a: i32, b: String) -> Self {              |
            S { a, b }                                   |
        }                                                |
    }                                                    |
                                                         |
    fn main() { {1:▶︎ Run }                                   |
        let s = S::new(42, String::from("Hello, world!"))|
    ;                                                    |
        println!("S.a: {}, S.b: {}", s.a, s.b);          |
    }                                                    |
    ^                                                     |
    {1:~                                                    }|*2
                                                         |
  ]])

  local grid_without_lenses = dedent([[
    struct S {                                           |
        a: i32,                                          |
        b: String,                                       |
    }                                                    |
                                                         |
    impl S {                                             |
        fn new(a: i32, b: String) -> Self {              |
            S { a, b }                                   |
        }                                                |
    }                                                    |
                                                         |
    fn main() {                                          |
        let s = S::new(42, String::from("Hello, world!"))|
    ;                                                    |
        println!("S.a: {}, S.b: {}", s.a, s.b);          |
    }                                                    |
    ^                                                     |
    {1:~                                                    }|*2
                                                         |
  ]])

  --- @type test.functional.ui.screen
  local screen

  --- @type integer
  local client_id

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)

    screen = Screen.new(nil, 20)

    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          codeLensProvider = {
            resolveProvider = true,
          },
        },
        handlers = {
          ['textDocument/codeLens'] = function(_, _, callback)
            callback(nil, {
              {
                data = {
                  kind = {
                    impls = {
                      position = {
                        character = 7,
                        line = 0,
                      },
                    },
                  },
                  version = 0,
                },
                range = {
                  ['end'] = {
                    character = 8,
                    line = 0,
                  },
                  start = {
                    character = 7,
                    line = 0,
                  },
                },
              },
              {
                command = {
                  arguments = {},
                  command = 'rust-analyzer.runSingle',
                  title = '▶︎ Run ',
                },
                range = {
                  ['end'] = {
                    character = 7,
                    line = 11,
                  },
                  start = {
                    character = 3,
                    line = 11,
                  },
                },
              },
            })
          end,
          ['codeLens/resolve'] = function(_, _, callback)
            vim.schedule(function()
              callback(nil, {
                command = {
                  arguments = {},
                  command = 'rust-analyzer.showReferences',
                  title = '1 implementation',
                },
                range = {
                  ['end'] = {
                    character = 8,
                    line = 0,
                  },
                  start = {
                    character = 7,
                    line = 0,
                  },
                },
              })
            end)
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    insert(text)

    exec_lua(function()
      vim.lsp.codelens.enable()
    end)

    screen:expect({ grid = grid_with_lenses })
  end)

  it('clears code lenses when disabled', function()
    exec_lua(function()
      vim.lsp.codelens.enable(false)
    end)

    screen:expect({ grid = grid_without_lenses })
  end)

  it('clears code lenses when sole client detaches', function()
    exec_lua(function()
      vim.lsp.get_client_by_id(client_id):stop()
    end)

    screen:expect({ grid = grid_without_lenses })
  end)

  it('get code lenses in the current buffer', function()
    local result = exec_lua(function()
      vim.api.nvim_win_set_cursor(0, { 12, 3 })
      return vim.lsp.codelens.get()
    end)

    eq({
      {
        client_id = 1,
        lens = {
          command = {
            arguments = {},
            command = 'rust-analyzer.showReferences',
            title = '1 implementation',
          },
          range = {
            ['end'] = {
              character = 8,
              line = 0,
            },
            start = {
              character = 7,
              line = 0,
            },
          },
        },
      },
      {
        client_id = 1,
        lens = {
          command = {
            arguments = {},
            command = 'rust-analyzer.runSingle',
            title = '▶︎ Run ',
          },
          range = {
            ['end'] = {
              character = 7,
              line = 11,
            },
            start = {
              character = 3,
              line = 11,
            },
          },
        },
      },
    }, result)
  end)

  it('refreshes code lenses on request', function()
    feed('ggdd')

    screen:expect([[
          ^a: i32, {1:1 implementation}                         |
          b: String,                                       |
      }                                                    |
                                                           |
      impl S {                                             |
          fn new(a: i32, b: String) -> Self {              |
              S { a, b }                                   |
          }                                                |
      }                                                    |
                                                           |
      fn main() { {1:▶︎ Run }                                   |
          let s = S::new(42, String::from("Hello, world!"))|
      ;                                                    |
          println!("S.a: {}, S.b: {}", s.a, s.b);          |
      }                                                    |
                                                           |
      {1:~                                                    }|*3
                                                           |
    ]])
    exec_lua(function()
      vim.lsp.codelens.on_refresh(
        nil,
        nil,
        { method = 'workspace/codeLens/refresh', client_id = client_id }
      )
    end)
    screen:expect([[
          ^a: i32, {1:1 implementation}                         |
          b: String,                                       |
      }                                                    |
                                                           |
      impl S {                                             |
          fn new(a: i32, b: String) -> Self {              |
              S { a, b }                                   |
          }                                                |
      }                                                    |
                                                           |
      fn main() {                                          |
          let s = S::new(42, String::from("Hello, world!"))|
      ; {1:▶︎ Run }                                             |
          println!("S.a: {}, S.b: {}", s.a, s.b);          |
      }                                                    |
                                                           |
      {1:~                                                    }|*3
                                                           |
    ]])
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)
end)
