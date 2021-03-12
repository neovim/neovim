local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local NIL = helpers.NIL

-- Use these to get access to a coroutine so that I can run async tests and use
-- yield.
local run, stop = helpers.run, helpers.stop

-- TODO(justinmk): hangs on Windows https://github.com/neovim/neovim/pull/11837
if helpers.pending_win32(pending) then
  return
end

-- Fake LSP server.
local fake_lsp_server = require('test.functional.plugin.lsp.fake_lsp_server')

teardown(function()
  os.remove(fake_lsp_server.logfile)
end)

local function clear_notrace()
  -- problem: here be dragons
  -- solution: don't look for dragons to closely
  clear({ env = {
    NVIM_LUA_NOTRACK = '1',
    VIMRUNTIME = os.getenv('VIMRUNTIME'),
  } })
end

local function fake_lsp_server_setup(test_name, timeout_ms, options)
  exec_lua(
    [=[
    lsp = require('vim.lsp')
    local test_name, fixture_filename, logfile, timeout, options = ...
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd_env = {
        NVIM_LOG_FILE = logfile;
        NVIM_LUA_NOTRACK = "1";
      };
      cmd = {
        vim.v.progpath, '-Es', '-u', 'NONE', '--headless',
        "-c", string.format("lua TEST_NAME = %q", test_name),
        "-c", string.format("lua TIMEOUT = %d", timeout),
        "-c", "luafile "..fixture_filename,
      };
      handlers = setmetatable({}, {
        __index = function(t, method)
          return function(...)
            return vim.rpcrequest(1, 'handler', ...)
          end
        end;
      });
      workspace_folders = {{
          uri = 'file://' .. vim.loop.cwd(),
          name = 'test_folder',
      }};
      on_init = function(client, result)
        TEST_RPC_CLIENT = client
        vim.rpcrequest(1, "init", result)
      end;
      flags = {
        allow_incremental_sync = options.allow_incremental_sync or false;
        debounce_text_changes = options.debounce_text_changes or 0;
      };
      on_exit = function(...)
        vim.rpcnotify(1, "exit", ...)
      end;
    }
  ]=],
    test_name,
    fake_lsp_server.code,
    fake_lsp_server.logfile,
    timeout_ms or 1e3,
    options or {}
  )
end

local function test_rpc_server(config)
  if config.test_name then
    clear_notrace()
    fake_lsp_server_setup(config.test_name, config.timeout_ms or 1e3, config.options)
  end
  local client = setmetatable({}, {
    __index = function(_, name)
      -- Workaround for not being able to yield() inside __index for Lua 5.1 :(
      -- Otherwise I would just return the value here.
      return function(...)
        return exec_lua(
          [=[
        local name = ...
        if type(TEST_RPC_CLIENT[name]) == 'function' then
          return TEST_RPC_CLIENT[name](select(2, ...))
        else
          return TEST_RPC_CLIENT[name]
        end
        ]=],
          name,
          ...
        )
      end
    end,
  })
  local code, signal
  local function on_request(method, args)
    if method == 'init' then
      if config.on_init then
        config.on_init(client, unpack(args))
      end
      return NIL
    end
    if method == 'handler' then
      if config.on_handler then
        config.on_handler(unpack(args))
      end
    end
    return NIL
  end
  local function on_notify(method, args)
    if method == 'exit' then
      code, signal = unpack(args)
      return stop()
    end
  end
  --  TODO specify timeout?
  --  run(on_request, on_notify, config.on_setup, 1000)
  run(on_request, on_notify, config.on_setup)
  if config.on_exit then
    config.on_exit(code, signal)
  end
  stop()
  if config.test_name then
    exec_lua('lsp._vim_exit_handler()')
  end
end

describe('semantic tokens', function()
  before_each(function()
    clear_notrace()

    -- Run an instance of nvim on the file which contains our "scripts".
    -- Pass TEST_NAME to pick the script.
    local test_name = 'basic_init'
    exec_lua(
      [=[
      lsp = require('vim.lsp')
      local test_name, fixture_filename, logfile = ...
      function test__start_client()
        return lsp.start_client {
          cmd_env = {
            NVIM_LOG_FILE = logfile;
          };
          cmd = {
            vim.v.progpath, '-Es', '-u', 'NONE', '--headless',
            "-c", string.format("lua TEST_NAME = %q", test_name),
            "-c", "luafile "..fixture_filename;
          };
          workspace_folders = {{
              uri = 'file://' .. vim.loop.cwd(),
              name = 'test_folder',
          }};
        }
      end
      TEST_CLIENT1 = test__start_client()
    ]=],
      test_name,
      fake_lsp_server.code,
      fake_lsp_server.logfile
    )
  end)

  describe('vim.lsp.buf.semantic_tokens_full', function()
    for _, test in ipairs({
      {
        it = 'semantic_tokens_full: clangd-15 on C',
        name = 'semantic_tokens_full',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          {
            NIL,
            { data = {}, resultId = 1 },
            { method = 'textDocument/semanticTokens/full', client_id = 1, bufnr = 1 },
          },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        text = [[char* foo = "\n";]],
        response = [[{"data": [0, 6, 3, 0, 8193], "resultId": "1"}]],
        legend = [[{"tokenTypes": ["variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"], "tokenModifiers": ["declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"]}]],
        expected = {
          [1] = {
            [1] = {
              length = 3,
              line = 0,
              modifiers = {
                [1] = 'globalScope',
                [2] = 'declaration',
              },
              start_char = 6,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
          },
        },
      },
      {
        it = 'semantic_tokens_full: clangd-15 on C++',
        name = 'semantic_tokens_full',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          {
            NIL,
            { data = {}, resultId = 1 },
            { method = 'textDocument/semanticTokens/full', client_id = 1, bufnr = 1 },
          },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
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
        legend = [[{"tokenTypes": ["variable", "variable", "parameter", "function", "method", "function", "property", "variable", "class", "interface", "enum", "enumMember", "type", "type", "unknown", "namespace", "typeParameter", "concept", "type", "macro", "comment"], "tokenModifiers": ["declaration", "deprecated", "deduced", "readonly", "static", "abstract", "virtual", "dependentName", "defaultLibrary", "usedAsMutableReference", "functionScope", "classScope", "fileScope", "globalScope"]}]],
        expected = {
          {
            { -- main
              length = 4,
              line = 1,
              modifiers = { 'globalScope', 'declaration' },
              start_char = 4,
              offset_encoding = 'utf-16',
              type = 'function',
            },
          },
          {
            { --  __cplusplus
              length = 11,
              line = 3,
              modifiers = { 'globalScope' },
              start_char = 9,
              offset_encoding = 'utf-16',
              type = 'macro',
            },
          },
          {
            { -- x
              length = 1,
              line = 4,
              modifiers = { 'functionScope', 'readonly', 'declaration' },
              start_char = 12,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
          },
          {
            { -- std
              length = 3,
              line = 5,
              modifiers = { 'globalScope', 'defaultLibrary' },
              start_char = 2,
              offset_encoding = 'utf-16',
              type = 'namespace',
            },
            { -- cout
              length = 4,
              line = 5,
              modifiers = { 'globalScope', 'defaultLibrary' },
              start_char = 7,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
            { -- x
              length = 1,
              line = 5,
              modifiers = { 'functionScope', 'readonly' },
              start_char = 15,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
            { -- std
              length = 3,
              line = 5,
              modifiers = { 'globalScope', 'defaultLibrary' },
              start_char = 20,
              offset_encoding = 'utf-16',
              type = 'namespace',
            },
            { -- endl
              length = 4,
              line = 5,
              modifiers = { 'globalScope', 'defaultLibrary' },
              start_char = 25,
              offset_encoding = 'utf-16',
              type = 'function',
            },
          },
          {
            { -- #else comment #endif
              length = 7,
              line = 6,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'comment',
            },
          },
          {
            {
              length = 11,
              line = 7,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'comment',
            },
          },
          {
            {
              length = 8,
              line = 8,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'comment',
            },
          },
        },
      },
      {
        it = 'semantic_tokens_full: sumneko_lua',
        name = 'semantic_tokens_full',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          {
            NIL,
            { data = {}, resultId = 1 },
            { method = 'textDocument/semanticTokens/full', client_id = 1, bufnr = 1 },
          },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        text = [[-- comment
local a = 1
b = "as"]],
        response = [[{"data": [0, 0, 10, 17, 0, 1, 6, 1, 8, 1, 1, 0, 1, 8, 8]}]],
        legend = [[{"tokenTypes": ["namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator"], "tokenModifiers": ["declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary"]}]],
        expected = {
          {
            {
              length = 10,
              line = 0,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'comment', -- comment
            },
          },
          {
            {
              length = 1,
              line = 1,
              modifiers = { 'declaration' }, -- a
              start_char = 6,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
          },
          {
            {
              length = 1,
              line = 2,
              modifiers = { 'static' }, -- b (global)
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'variable',
            },
          },
        },
      },
      {
        it = 'semantic_tokens_full: rust-analyzer',
        name = 'semantic_tokens_full',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          {
            NIL,
            { data = {}, resultId = 1 },
            { method = 'textDocument/semanticTokens/full', client_id = 1, bufnr = 1 },
          },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        text = [[pub fn main() {
  break rust;
  /// what?
}
]],
        response = [[{"data": [0, 0, 3, 1, 0, 0, 4, 2, 1, 0, 0, 3, 4, 14, 524290, 0, 4, 1, 45, 0, 0, 1, 1, 45, 0, 0, 2, 1, 26, 0, 1, 4, 5, 1, 8192, 0, 6, 4, 52, 0, 0, 4, 1, 48, 0, 1, 4, 9, 0, 1, 1, 0, 1, 26, 0], "resultId": "1"}]],
        legend = [[{"tokenTypes": ["comment", "keyword", "string", "number", "regexp", "operator", "namespace", "type", "struct", "class", "interface", "enum", "enumMember", "typeParameter", "function", "method", "property", "macro", "variable", "parameter", "angle", "arithmetic", "attribute", "attributeBracket", "bitwise", "boolean", "brace", "bracket", "builtinAttribute", "builtinType", "character", "colon", "comma", "comparison", "constParameter", "derive", "dot", "escapeSequence", "formatSpecifier", "generic", "label", "lifetime", "logical", "macroBang", "operator", "parenthesis", "punctuation", "selfKeyword", "semicolon", "typeAlias", "toolModule", "union", "unresolvedReference"], "tokenModifiers": ["documentation", "declaration", "definition", "static", "abstract", "deprecated", "readonly", "defaultLibrary", "async", "attribute", "callable", "constant", "consuming", "controlFlow", "crateRoot", "injected", "intraDocLink", "library", "mutable", "public", "reference", "trait", "unsafe"]}]],
        expected = {
          {
            {
              length = 3, -- pub
              line = 0,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'keyword',
            },
            {
              length = 2, -- fn
              line = 0,
              modifiers = {},
              start_char = 4,
              offset_encoding = 'utf-16',
              type = 'keyword',
            },
            {
              length = 4, -- main
              line = 0,
              modifiers = { 'public', 'declaration' },
              start_char = 7,
              offset_encoding = 'utf-16',
              type = 'function',
            },
            {
              length = 1,
              line = 0,
              modifiers = {},
              start_char = 11,
              offset_encoding = 'utf-16',
              type = 'parenthesis',
            },
            {
              length = 1,
              line = 0,
              modifiers = {},
              start_char = 12,
              offset_encoding = 'utf-16',
              type = 'parenthesis',
            },
            {
              length = 1,
              line = 0,
              modifiers = {},
              start_char = 14,
              offset_encoding = 'utf-16',
              type = 'brace',
            },
          },
          {
            {
              length = 5, -- break
              line = 1,
              modifiers = { 'controlFlow' },
              start_char = 4,
              offset_encoding = 'utf-16',
              type = 'keyword',
            },
            {
              length = 4, -- rust
              line = 1,
              modifiers = {},
              start_char = 10,
              offset_encoding = 'utf-16',
              type = 'unresolvedReference',
            },
            {
              length = 1,
              line = 1,
              modifiers = {},
              start_char = 14,
              offset_encoding = 'utf-16',
              type = 'semicolon',
            },
          },
          {
            {
              length = 9,
              line = 2,
              modifiers = { 'documentation' },
              start_char = 4,
              offset_encoding = 'utf-16',
              type = 'comment', -- /// what?
            },
          },
          {
            {
              length = 1,
              line = 3,
              modifiers = {},
              start_char = 0,
              offset_encoding = 'utf-16',
              type = 'brace',
            },
          },
        },
      },
    }) do
      it(test.it, function()
        local client
        test_rpc_server({
          test_name = test.name,
          on_init = function(client_)
            client = client_
            eq(true, client.resolved_capabilities().semantic_tokens_full)
          end,
          on_setup = function() end,
          on_exit = function(code, signal)
            eq(0, code, 'exit code', fake_lsp_server.logfile)
            eq(0, signal, 'exit signal', fake_lsp_server.logfile)
          end,
          on_handler = function(err, result, ctx)
            ctx.params = nil
            eq(table.remove(test.expected_handlers), { err, result, ctx })
            if ctx.method == 'start' then
              exec_lua(
                [[
              local test = ...
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.split(test.text, "\n"))
              vim.lsp.buf.semantic_tokens_full()
            ]],
                test
              )
            elseif ctx.method == 'textDocument/semanticTokens/full' then
              local tokens = exec_lua(
                [[
                local ctx, test = ...
                local bufnr = vim.api.nvim_get_current_buf()
                local tokens = {[bufnr] = {}}
                local client = vim.lsp.get_client_by_id(ctx.client_id)
                client.server_capabilities.semanticTokensProvider.legend = vim.fn.json_decode(test.legend)

                local semantic_tokens = require "vim.lsp.semantic_tokens"
                vim.lsp.handlers["textDocument/semanticTokens/full"] = vim.lsp.with(semantic_tokens.on_full, {
                  on_token = function(ctx, token)
                    tokens[ctx.bufnr][token.line + 1] = tokens[ctx.bufnr][token.line + 1] or {}
                    table.insert(tokens[ctx.bufnr][token.line + 1], token)
                  end,
                  on_invalidate_range = function(ctx) tokens[ctx.bufnr] = {} end,
                })
                vim.lsp.handlers["textDocument/semanticTokens/full"](nil, vim.fn.json_decode(test.response), ctx)
                return vim.tbl_values(tokens[bufnr])
              ]],
                ctx,
                test
              )
              eq(test.expected, tokens)
            elseif ctx.method == 'shutdown' then
              client.stop()
            end
          end,
        })
      end)
    end
  end)
end)
