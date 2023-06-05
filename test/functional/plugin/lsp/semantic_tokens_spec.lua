local helpers = require('test.functional.helpers')(after_each)
local lsp_helpers = require('test.functional.plugin.lsp.helpers')
local Screen = require('test.functional.ui.screen')

local command = helpers.command
local dedent = helpers.dedent
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local feed_command = helpers.feed_command
local insert = helpers.insert
local matches = helpers.matches

local clear_notrace = lsp_helpers.clear_notrace
local create_server_definition = lsp_helpers.create_server_definition

before_each(function()
  clear_notrace()
end)

after_each(function()
  exec_lua("vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })")
end)

describe('semantic token highlighting', function()

  local screen
  before_each(function()
    screen = Screen.new(40, 16)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 };
      [2] = { foreground = Screen.colors.DarkCyan };
      [3] = { foreground = Screen.colors.SlateBlue };
      [4] = { bold = true, foreground = Screen.colors.SeaGreen };
      [5] = { foreground = tonumber('0x6a0dad') };
      [6] = { foreground = Screen.colors.Blue1 };
      [7] = { bold = true, foreground = Screen.colors.DarkCyan };
      [8] = { bold = true, foreground = Screen.colors.SlateBlue };
      [9] = { bold = true, foreground = tonumber('0x6a0dad') };
    }
    command([[ hi link @lsp.type.namespace Type ]])
    command([[ hi link @lsp.type.function Special ]])
    command([[ hi link @lsp.type.comment Comment ]])
    command([[ hi @lsp.mod.declaration gui=bold ]])
  end)

  describe('general', function()
    local text = dedent([[
    #include <iostream>

    int main()
    {
        int x;
    #ifdef __cplusplus
        std::cout << x << "\n";
    #else
        printf("%d\n", x);
    #endif
    }
    }]])

    local legend = [[{
      "tokenTypes": [
        "variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"
      ],
      "tokenModifiers": [
        "declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"
      ]
    }]]

    local response = [[{
      "data": [ 2, 4, 4, 3, 8193, 2, 8, 1, 1, 1025, 1, 7, 11, 19, 8192, 1, 4, 3, 15, 8448, 0, 5, 4, 0, 8448, 0, 8, 1, 1, 1024, 1, 0, 5, 20, 0, 1, 0, 22, 20, 0, 1, 0, 6, 20, 0 ],
      "resultId": 1
    }]]

    local edit_response = [[{
      "edits": [ {"data": [ 2, 8, 1, 3, 8193, 1, 7, 11, 19, 8192, 1, 4, 3, 15, 8448, 0, 5, 4, 0, 8448, 0, 8, 1, 3, 8192 ], "deleteCount": 25, "start": 5 } ],
      "resultId":"2"
    }]]

    before_each(function()
      exec_lua(create_server_definition)
      exec_lua([[
        local legend, response, edit_response = ...
        server = _create_server({
          capabilities = {
            semanticTokensProvider = {
              full = { delta = true },
              legend = vim.fn.json_decode(legend),
            },
          },
          handlers = {
            ['textDocument/semanticTokens/full'] = function()
              return vim.fn.json_decode(response)
            end,
            ['textDocument/semanticTokens/full/delta'] = function()
              return vim.fn.json_decode(edit_response)
            end,
          }
        })
      ]], legend, response, edit_response)
    end)

    it('buffer is highlighted when attached', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
    end)

    it('use LspTokenUpdate and highlight_token', function()
      exec_lua([[
        vim.api.nvim_create_autocmd("LspTokenUpdate", {
          callback = function(args)
            local token = args.data.token
            if token.type == "function" and token.modifiers.declaration then
              vim.lsp.semantic_tokens.highlight_token(
                token, args.buf, args.data.client_id, "Macro"
              )
            end
          end,
        })
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {9:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }

    end)

    it('buffer is unhighlighted when client is detached', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      exec_lua([[
        vim.notify = function() end
        vim.lsp.buf_detach_client(bufnr, client_id)
      ]])

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int main()                              |
        {                                       |
            int x;                              |
        #ifdef __cplusplus                      |
            std::cout << x << "\n";             |
        #else                                   |
            printf("%d\n", x);                  |
        #endif                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
    end)

    it('buffer is highlighted and unhighlighted when semantic token highlighting is started and stopped'
      , function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      exec_lua([[
        vim.notify = function() end
        vim.lsp.semantic_tokens.stop(bufnr, client_id)
      ]])

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int main()                              |
        {                                       |
            int x;                              |
        #ifdef __cplusplus                      |
            std::cout << x << "\n";             |
        #else                                   |
            printf("%d\n", x);                  |
        #endif                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }

      exec_lua([[
        vim.lsp.semantic_tokens.start(bufnr, client_id)
      ]])

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
    end)

    it('buffer is re-highlighted when force refreshed', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }

      exec_lua([[
        vim.lsp.semantic_tokens.force_refresh(bufnr)
      ]])

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]], unchanged = true }

      local messages = exec_lua('return server.messages')
      local token_request_count = 0
      for _, message in ipairs(messages) do
        assert(message.method ~= 'textDocument/semanticTokens/full/delta', 'delta request received')
        if message.method == 'textDocument/semanticTokens/full' then
          token_request_count = token_request_count + 1
        end
      end
      eq(2, token_request_count)
    end)

    it('destroys the highlighter if the buffer is deleted', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)

      local highlighters = exec_lua([[
        vim.api.nvim_buf_delete(bufnr, { force = true })
        local semantic_tokens = vim.lsp.semantic_tokens
        return semantic_tokens.__STHighlighter.active
      ]])

      eq({}, highlighters)
    end)

    it('updates highlights with delta request on buffer change', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

      insert(text)
      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
      feed_command('%s/int x/int x()/')
      feed_command('noh')
      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            ^int {8:x}();                            |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {3:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        }                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        :noh                                    |
      ]] }
    end)

    it('prevents starting semantic token highlighting with invalid conditions', function()
      exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start_client({ name = 'dummy', cmd = server.cmd })
        notifications = {}
        vim.notify = function(...) table.insert(notifications, 1, {...}) end
      ]])
      eq(false, exec_lua("return vim.lsp.buf_is_attached(bufnr, client_id)"))

      insert(text)

      local notifications = exec_lua([[
        vim.lsp.semantic_tokens.start(bufnr, client_id)
        return notifications
      ]])
      matches('%[LSP%] Client with id %d not attached to buffer %d', notifications[1][1])

      notifications = exec_lua([[
        vim.lsp.semantic_tokens.start(bufnr, client_id + 1)
        return notifications
      ]])
      matches('%[LSP%] No client with id %d', notifications[1][1])
    end)

    it('opt-out: does not activate semantic token highlighting if disabled in client attach',
      function()
        exec_lua([[
          bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_win_set_buf(0, bufnr)
          client_id = vim.lsp.start({
            name = 'dummy',
            cmd = server.cmd,
            on_attach = vim.schedule_wrap(function(client, bufnr)
              client.server_capabilities.semanticTokensProvider = nil
            end),
          })
        ]])
        eq(true, exec_lua("return vim.lsp.buf_is_attached(bufnr, client_id)"))

        insert(text)

        screen:expect { grid = [[
          #include <iostream>                     |
                                                  |
          int main()                              |
          {                                       |
              int x;                              |
          #ifdef __cplusplus                      |
              std::cout << x << "\n";             |
          #else                                   |
              printf("%d\n", x);                  |
          #endif                                  |
          }                                       |
          ^}                                       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
                                                  |
        ]] }

        local notifications = exec_lua([[
          local notifications = {}
          vim.notify = function(...) table.insert(notifications, 1, {...}) end
          vim.lsp.semantic_tokens.start(bufnr, client_id)
          return notifications
        ]])
        eq('[LSP] Server does not support semantic tokens', notifications[1][1])

        screen:expect { grid = [[
          #include <iostream>                     |
                                                  |
          int main()                              |
          {                                       |
              int x;                              |
          #ifdef __cplusplus                      |
              std::cout << x << "\n";             |
          #else                                   |
              printf("%d\n", x);                  |
          #endif                                  |
          }                                       |
          ^}                                       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
                                                  |
          ]], unchanged = true }
      end)

  it('ignores null responses from the server', function()
      exec_lua([[
        local legend, response, edit_response = ...
        server2 = _create_server({
          capabilities = {
            semanticTokensProvider = {
              full = { delta = false },
            },
          },
          handlers = {
            ['textDocument/semanticTokens/full'] = function()
              return nil
            end,
            ['textDocument/semanticTokens/full/delta'] = function()
              return nil
            end,
          }
        })
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server2.cmd })
      ]])
      eq(true, exec_lua("return vim.lsp.buf_is_attached(bufnr, client_id)"))

      insert(text)

      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int main()                              |
        {                                       |
            int x;                              |
        #ifdef __cplusplus                      |
            std::cout << x << "\n";             |
        #else                                   |
            printf("%d\n", x);                  |
        #endif                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
    end)

    it('does not send delta requests if not supported by server', function()
      exec_lua([[
        local legend, response, edit_response = ...
        server2 = _create_server({
          capabilities = {
            semanticTokensProvider = {
              full = { delta = false },
              legend = vim.fn.json_decode(legend),
            },
          },
          handlers = {
            ['textDocument/semanticTokens/full'] = function()
              return vim.fn.json_decode(response)
            end,
            ['textDocument/semanticTokens/full/delta'] = function()
              return vim.fn.json_decode(edit_response)
            end,
          }
        })
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server2.cmd })
      ]], legend, response, edit_response)

      insert(text)
      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            int {7:x};                              |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        ^}                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]] }
      feed_command('%s/int x/int x()/')
      feed_command('noh')

      -- the highlights don't change because our fake server sent the exact
      -- same result for the same method (the full request). "x" would have
      -- changed to highlight index 3 had we sent a delta request
      screen:expect { grid = [[
        #include <iostream>                     |
                                                |
        int {8:main}()                              |
        {                                       |
            ^int {7:x}();                            |
        #ifdef {5:__cplusplus}                      |
            {4:std}::{2:cout} << {2:x} << "\n";             |
        {6:#else}                                   |
        {6:    printf("%d\n", x);}                  |
        {6:#endif}                                  |
        }                                       |
        }                                       |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        :noh                                    |
      ]] }
      local messages = exec_lua('return server2.messages')
      local token_request_count = 0
      for _, message in ipairs(messages) do
        assert(message.method ~= 'textDocument/semanticTokens/full/delta', 'delta request received')
        if message.method == 'textDocument/semanticTokens/full' then
          token_request_count = token_request_count + 1
        end
      end
      eq(2, token_request_count)
    end)
  end)

  describe('token array decoding', function()
    for _, test in ipairs({
      {
        it = 'clangd-15 on C',
        text = [[char* foo = "\n";]],
        response = [[{"data": [0, 6, 3, 0, 8193], "resultId": "1"}]],
        legend = [[{
          "tokenTypes": [
            "variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"
          ],
          "tokenModifiers": [
            "declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"
          ]
        }]],
        expected = {
          {
            line = 0,
            modifiers = { declaration = true, globalScope = true },
            start_col = 6,
            end_col = 9,
            type = 'variable',
            marked = true,
          },
        },
        expected_screen = function()
          screen:expect{grid=[[
            char* {7:foo} = "\n"^;                       |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
      {
        it = 'clangd-15 on C++',
        text = [[#include <iostream>
int main()
{
  #ifdef __cplusplus
  const int x = 1;
  std::cout << x << std::endl;
  #else
    comment
  #endif
}]],
        response = [[{"data": [1, 4, 4, 3, 8193, 2, 9, 11, 19, 8192, 1, 12, 1, 1, 1033, 1, 2, 3, 15, 8448, 0, 5, 4, 0, 8448, 0, 8, 1, 1, 1032, 0, 5, 3, 15, 8448, 0, 5, 4, 3, 8448, 1, 0, 7, 20, 0, 1, 0, 11, 20, 0, 1, 0, 8, 20, 0], "resultId": "1"}]],
        legend = [[{
          "tokenTypes": [
            "variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"
          ],
          "tokenModifiers": [
            "declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"
          ]
        }]],
        expected = {
          { -- main
            line = 1,
            modifiers = { declaration = true, globalScope = true },
            start_col = 4,
            end_col = 8,
            type = 'function',
            marked = true,
          },
          { --  __cplusplus
            line = 3,
            modifiers = { globalScope = true },
            start_col = 9,
            end_col = 20,
            type = 'macro',
            marked = true,
          },
          { -- x
            line = 4,
            modifiers = { declaration = true, readonly = true, functionScope = true },
            start_col = 12,
            end_col = 13,
            type = 'variable',
            marked = true,
          },
          { -- std
            line = 5,
            modifiers = { defaultLibrary = true, globalScope = true },
            start_col = 2,
            end_col = 5,
            type = 'namespace',
            marked = true,
          },
          { -- cout
            line = 5,
            modifiers = { defaultLibrary = true, globalScope = true },
            start_col = 7,
            end_col = 11,
            type = 'variable',
            marked = true,
          },
          { -- x
            line = 5,
            modifiers = { readonly = true, functionScope = true },
            start_col = 15,
            end_col = 16,
            type = 'variable',
            marked = true,
          },
          { -- std
            line = 5,
            modifiers = { defaultLibrary = true, globalScope = true },
            start_col = 20,
            end_col = 23,
            type = 'namespace',
            marked = true,
          },
          { -- endl
            line = 5,
            modifiers = { defaultLibrary = true, globalScope = true },
            start_col = 25,
            end_col = 29,
            type = 'function',
            marked = true,
          },
          { -- #else comment #endif
            line = 6,
            modifiers = {},
            start_col = 0,
            end_col = 7,
            type = 'comment',
            marked = true,
          },
          {
            line = 7,
            modifiers = {},
            start_col = 0,
            end_col = 11,
            type = 'comment',
            marked = true,
          },
          {
            line = 8,
            modifiers = {},
            start_col = 0,
            end_col = 8,
            type = 'comment',
            marked = true,
          },
        },
        expected_screen = function()
          screen:expect{grid=[[
            #include <iostream>                     |
            int {8:main}()                              |
            {                                       |
              #ifdef {5:__cplusplus}                    |
              const int {7:x} = 1;                      |
              {4:std}::{2:cout} << {2:x} << {4:std}::{3:endl};          |
            {6:  #else}                                 |
            {6:    comment}                             |
            {6:  #endif}                                |
            ^}                                       |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
      {
        it = 'sumneko_lua',
        text = [[-- comment
local a = 1
b = "as"]],
        response = [[{"data": [0, 0, 10, 17, 0, 1, 6, 1, 8, 1, 1, 0, 1, 8, 8]}]],
        legend = [[{
          "tokenTypes": [
            "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"
          ],
          "tokenModifiers": [
            "declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"
          ]
        }]],
        expected = {
          {
            line = 0,
            modifiers = {},
            start_col = 0,
            end_col = 10,
            type = 'comment', -- comment
            marked = true,
          },
          {
            line = 1,
            modifiers = { declaration = true }, -- a
            start_col = 6,
            end_col = 7,
            type = 'variable',
            marked = true,
          },
          {
            line = 2,
            modifiers = { static = true }, -- b (global)
            start_col = 0,
            end_col = 1,
            type = 'variable',
            marked = true,
          },
        },
        expected_screen = function()
          screen:expect{grid=[[
            {6:-- comment}                              |
            local {7:a} = 1                             |
            {2:b} = "as^"                                |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
      {
        it = 'rust-analyzer',
        text = [[pub fn main() {
  break rust;
  /// what?
}
]],
        response = [[{"data": [0, 0, 3, 1, 0, 0, 4, 2, 1, 0, 0, 3, 4, 14, 524290, 0, 4, 1, 45, 0, 0, 1, 1, 45, 0, 0, 2, 1, 26, 0, 1, 4, 5, 1, 8192, 0, 6, 4, 52, 0, 0, 4, 1, 48, 0, 1, 4, 9, 0, 1, 1, 0, 1, 26, 0], "resultId": "1"}]],
        legend = [[{
        "tokenTypes": [
          "comment", "keyword", "string", "number", "regexp", "operator", "namespace", "type", "struct", "class", "interface", "enum", "enumMember", "typeParameter", "function", "method", "property", "macro", "variable",
          "parameter", "angle", "arithmetic", "attribute", "attributeBracket", "bitwise", "boolean", "brace", "bracket", "builtinAttribute", "builtinType", "character", "colon", "comma", "comparison", "constParameter", "derive",
          "dot", "escapeSequence", "formatSpecifier", "generic", "label", "lifetime", "logical", "macroBang", "operator", "parenthesis", "punctuation", "selfKeyword", "semicolon", "typeAlias", "toolModule", "union", "unresolvedReference"
        ],
        "tokenModifiers": [
          "documentation", "declaration", "definition", "static", "abstract", "deprecated", "readonly", "defaultLibrary", "async", "attribute", "callable", "constant", "consuming", "controlFlow", "crateRoot", "injected", "intraDocLink",
          "library", "mutable", "public", "reference", "trait", "unsafe"
        ]
        }]],
        expected = {
          {
            line = 0,
            modifiers = {},
            start_col = 0,
            end_col = 3, -- pub
            type = 'keyword',
            marked = true,
          },
          {
            line = 0,
            modifiers = {},
            start_col = 4,
            end_col = 6, -- fn
            type = 'keyword',
            marked = true,
          },
          {
            line = 0,
            modifiers = { declaration = true, public = true },
            start_col = 7,
            end_col = 11, -- main
            type = 'function',
            marked = true,
          },
          {
            line = 0,
            modifiers = {},
            start_col = 11,
            end_col = 12,
            type = 'parenthesis',
            marked = true,
          },
          {
            line = 0,
            modifiers = {},
            start_col = 12,
            end_col = 13,
            type = 'parenthesis',
            marked = true,
          },
          {
            line = 0,
            modifiers = {},
            start_col = 14,
            end_col = 15,
            type = 'brace',
            marked = true,
          },
          {
            line = 1,
            modifiers = { controlFlow = true },
            start_col = 4,
            end_col = 9, -- break
            type = 'keyword',
            marked = true,
          },
          {
            line = 1,
            modifiers = {},
            start_col = 10,
            end_col = 13, -- rust
            type = 'unresolvedReference',
            marked = true,
          },
          {
            line = 1,
            modifiers = {},
            start_col = 13,
            end_col = 13,
            type = 'semicolon',
            marked = true,
          },
          {
            line = 2,
            modifiers = { documentation = true },
            start_col = 4,
            end_col = 11,
            type = 'comment', -- /// what?
            marked = true,
          },
          {
            line = 3,
            modifiers = {},
            start_col = 0,
            end_col = 1,
            type = 'brace',
            marked = true,
          },
        },
        expected_screen = function()
          screen:expect{grid=[[
            pub fn {8:main}() {                         |
              break rust;                           |
              //{6:/ what?}                             |
            }                                       |
            ^                                        |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
    }) do
      it(test.it, function()
        exec_lua(create_server_definition)
        exec_lua([[
          local legend, resp = ...
          server = _create_server({
            capabilities = {
              semanticTokensProvider = {
                full = { delta = false },
                legend = vim.fn.json_decode(legend),
              },
            },
            handlers = {
              ['textDocument/semanticTokens/full'] = function()
                return vim.fn.json_decode(resp)
              end,
            }
          })
          bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_win_set_buf(0, bufnr)
          client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        ]], test.legend, test.response)

        insert(test.text)

        test.expected_screen()

        local highlights = exec_lua([[
          local semantic_tokens = vim.lsp.semantic_tokens
          return semantic_tokens.__STHighlighter.active[bufnr].client_state[client_id].current_result.highlights
        ]])
        eq(test.expected, highlights)
      end)
    end
  end)

  describe('token decoding with deltas', function()
    for _, test in ipairs({
      {
        it = 'semantic_tokens_delta: clangd-15 on C',
        legend = [[{
          "tokenTypes": [
            "variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"
          ],
          "tokenModifiers": [
            "declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"
          ]
        }]],
        text1 = [[char* foo = "\n";]],
        edit = [[ggO<Esc>]],
        response1 = [[{"data": [0, 6, 3, 0, 8193], "resultId": "1"}]],
        response2 = [[{"edits": [{ "start": 0, "deleteCount": 1, "data": [1] }], "resultId": "2"}]],
        expected1 = {
          {
            line = 0,
            modifiers = {
              declaration = true,
              globalScope = true,
            },
            start_col = 6,
            end_col = 9,
            type = 'variable',
            marked = true,
          }
        },
        expected2 = {
          {
            line = 1,
            modifiers = {
              declaration = true,
              globalScope = true,
            },
            start_col = 6,
            end_col = 9,
            type = 'variable',
            marked = true,
          }
        },
        expected_screen1 = function()
        screen:expect{grid=[[
          char* {7:foo} = "\n"^;                       |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
                                                  |
        ]]}
        end,
        expected_screen2 = function()
          screen:expect{grid=[[
            ^                                        |
            char* {7:foo} = "\n";                       |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
      {
        it = 'response with multiple delta edits',
        legend = [[{
        "tokenTypes": [
          "variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"
        ],
        "tokenModifiers": [
          "declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"
        ]
        }]],
        text1 = dedent([[
        #include <iostream>

        int main()
        {
            int x;
        #ifdef __cplusplus
            std::cout << x << "\n";
        #else
            printf("%d\n", x);
        #endif
        }]]),
        text2 = [[#include <iostream>

int main()
{
    int x();
    double y;
#ifdef __cplusplus
    std::cout << x << "\n";
#else
    printf("%d\n", x);
#endif
}]],
        response1 = [[{
        "data": [ 2, 4, 4, 3, 8193, 2, 8, 1, 1, 1025, 1, 7, 11, 19, 8192, 1, 4, 3, 15, 8448, 0, 5, 4, 0, 8448, 0, 8, 1, 1, 1024, 1, 0, 5, 20, 0, 1, 0, 22, 20, 0, 1, 0, 6, 20, 0 ],
        "resultId": 1
        }]],
        response2 = [[{
        "edits": [ {"data": [ 2, 8, 1, 3, 8193, 1, 11, 1, 1, 1025 ], "deleteCount": 5, "start": 5}, {"data": [ 0, 8, 1, 3, 8192 ], "deleteCount": 5, "start": 25 } ],
        "resultId":"2"
        }]],
        expected1 = {
          {
            line = 2,
            start_col = 4,
            end_col = 8,
            modifiers = { declaration = true, globalScope = true },
            type = 'function',
            marked = true,
          },
          {
            line = 4,
            start_col = 8,
            end_col = 9,
            modifiers = { declaration = true, functionScope = true },
            type = 'variable',
            marked = true,
          },
          {
            line = 5,
            start_col = 7,
            end_col = 18,
            modifiers = { globalScope = true },
            type = 'macro',
            marked = true,
          },
          {
            line = 6,
            start_col = 4,
            end_col = 7,
            modifiers = { defaultLibrary = true, globalScope = true },
            type = 'namespace',
            marked = true,
          },
          {
            line = 6,
            start_col = 9,
            end_col = 13,
            modifiers = { defaultLibrary = true, globalScope = true },
            type = 'variable',
            marked = true,
          },
          {
            line = 6,
            start_col = 17,
            end_col = 18,
            marked = true,
            modifiers = { functionScope = true },
            type = 'variable',
          },
          {
            line = 7,
            start_col = 0,
            end_col = 5,
            marked = true,
            modifiers = {},
            type = 'comment',
          },
          {
            line = 8,
            end_col = 22,
            modifiers = {},
            start_col = 0,
            type = 'comment',
            marked = true,
          },
          {
            line = 9,
            start_col = 0,
            end_col = 6,
            modifiers = {},
            type = 'comment',
            marked = true,
          }
        },
        expected2 = {
          {
            line = 2,
            start_col = 4,
            end_col = 8,
            modifiers = { declaration = true, globalScope = true },
            type = 'function',
            marked = true,
          },
          {
            line = 4,
            start_col = 8,
            end_col = 9,
            modifiers = { declaration = true, globalScope = true },
            type = 'function',
            marked = true,
          },
          {
            line = 5,
            end_col = 12,
            start_col = 11,
            modifiers = { declaration = true, functionScope = true },
            type = 'variable',
            marked = true,
          },
          {
            line = 6,
            start_col = 7,
            end_col = 18,
            modifiers = { globalScope = true },
            type = 'macro',
            marked = true,
          },
          {
            line = 7,
            start_col = 4,
            end_col = 7,
            modifiers = { defaultLibrary = true, globalScope = true },
            type = 'namespace',
            marked = true,
          },
          {
            line = 7,
            start_col = 9,
            end_col = 13,
            modifiers = { defaultLibrary = true, globalScope = true },
            type = 'variable',
            marked = true,
          },
          {
            line = 7,
            start_col = 17,
            end_col = 18,
            marked = true,
            modifiers = { globalScope = true },
            type = 'function',
          },
          {
            line = 8,
            start_col = 0,
            end_col = 5,
            marked = true,
            modifiers = {},
            type = 'comment',
          },
          {
            line = 9,
            end_col = 22,
            modifiers = {},
            start_col = 0,
            type = 'comment',
            marked = true,
          },
          {
            line = 10,
            start_col = 0,
            end_col = 6,
            modifiers = {},
            type = 'comment',
            marked = true,
          }
        },
        expected_screen1 = function()
          screen:expect{grid=[[
            #include <iostream>                     |
                                                    |
            int {8:main}()                              |
            {                                       |
                int {7:x};                              |
            #ifdef {5:__cplusplus}                      |
                {4:std}::{2:cout} << {2:x} << "\n";             |
            {6:#else}                                   |
            {6:    printf("%d\n", x);}                  |
            {6:#endif}                                  |
            ^}                                       |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
        expected_screen2 = function()
          screen:expect{grid=[[
            #include <iostream>                     |
                                                    |
            int {8:main}()                              |
            {                                       |
                int {8:x}();                            |
                double {7:y};                           |
            #ifdef {5:__cplusplus}                      |
                {4:std}::{2:cout} << {3:x} << "\n";             |
            {6:#else}                                   |
            {6:    printf("%d\n", x);}                  |
            {6:^#endif}                                  |
            }                                       |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
      {
        it = 'optional token_edit.data on deletion',
        legend = [[{
          "tokenTypes": [
            "comment", "keyword", "operator", "string", "number", "regexp", "type", "class", "interface", "enum", "enumMember", "typeParameter", "function", "method", "property", "variable", "parameter", "module", "intrinsic", "selfParameter", "clsParameter", "magicFunction", "builtinConstant", "parenthesis", "curlybrace", "bracket", "colon", "semicolon", "arrow"
          ],
          "tokenModifiers": [
            "declaration", "static", "abstract", "async", "documentation", "typeHint", "typeHintComment", "readonly", "decorator", "builtin"
          ]
        }]],
        text1 = [[string = "test"]],
        text2 = [[]],
        response1 = [[{"data": [0, 0, 6, 15, 1], "resultId": "1"}]],
        response2 = [[{"edits": [{ "start": 0, "deleteCount": 5 }], "resultId": "2"}]],
        expected1 = {
          {
            line = 0,
            modifiers = {
              declaration = true,
            },
            start_col = 0,
            end_col = 6,
            type = 'variable',
            marked = true,
          }
        },
        expected2 = {
        },
        expected_screen1 = function()
          screen:expect{grid=[[
            {7:string} = "test^"                         |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
        expected_screen2 = function()
          screen:expect{grid=[[
            ^                                        |
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
            {1:~                                       }|
                                                    |
          ]]}
        end,
      },
    }) do
      it(test.it, function()
        exec_lua(create_server_definition)
        exec_lua([[
          local legend, resp1, resp2 = ...
          server = _create_server({
            capabilities = {
              semanticTokensProvider = {
                full = { delta = true },
                legend = vim.fn.json_decode(legend),
              },
            },
            handlers = {
              ['textDocument/semanticTokens/full'] = function()
                return vim.fn.json_decode(resp1)
              end,
              ['textDocument/semanticTokens/full/delta'] = function()
                return vim.fn.json_decode(resp2)
              end,
            }
          })
          bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_win_set_buf(0, bufnr)
          client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })

          -- speed up vim.api.nvim_buf_set_lines calls by changing debounce to 10 for these tests
          semantic_tokens = vim.lsp.semantic_tokens
          vim.schedule(function()
            semantic_tokens.stop(bufnr, client_id)
            semantic_tokens.start(bufnr, client_id, { debounce = 10 })
          end)
        ]], test.legend, test.response1, test.response2)

        insert(test.text1)

        test.expected_screen1()

        local highlights = exec_lua([[
          return semantic_tokens.__STHighlighter.active[bufnr].client_state[client_id].current_result.highlights
        ]])

        eq(test.expected1, highlights)

        if test.edit then
          feed(test.edit)
        else
          exec_lua([[
            local text = ...
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.split(text, "\n"))
            vim.wait(15) -- wait for debounce
          ]], test.text2)
        end

        test.expected_screen2()

        highlights = exec_lua([[
          return semantic_tokens.__STHighlighter.active[bufnr].client_state[client_id].current_result.highlights
        ]])

        eq(test.expected2, highlights)
      end)
    end
  end)
end)
