local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local t_lsp = require('test.functional.plugin.lsp.testutil')

local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local matches = t.matches
local pcall_err = t.pcall_err
local retry = t.retry
local stop = n.stop
local NIL = vim.NIL
local api = n.api
local skip = t.skip
local is_os = t.is_os

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition
local fake_lsp_logfile = t_lsp.fake_lsp_logfile
local test_rpc_server = t_lsp.test_rpc_server
local test_root = vim.uv.cwd()

-- TODO(justinmk): hangs on Windows https://github.com/neovim/neovim/pull/11837
if skip(is_os('win')) then
  return
end

describe('vim.lsp.buf', function()
  local function exec_capture(cmd)
    return exec_lua(function(cmd0)
      return vim.api.nvim_exec2(cmd0, { output = true }).output
    end, cmd)
  end

  before_each(function()
    clear_notrace()
    command('cd ' .. test_root)
  end)

  after_each(function()
    stop()
    exec_lua(function()
      vim.iter(vim.lsp.get_clients({ _uninitialized = true })):each(function(client)
        client:stop(true)
      end)
    end)
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  teardown(function()
    os.remove(fake_lsp_logfile)
  end)

  describe('vim.lsp.buf.outgoing_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['callHierarchy/outgoingCalls'](nil, nil, {}, nil)
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right caller', function()
      local qflist = exec_lua(function()
        local rust_analyzer_response = {
          {
            fromRanges = {
              {
                ['end'] = {
                  character = 7,
                  line = 3,
                },
                start = {
                  character = 4,
                  line = 3,
                },
              },
            },
            to = {
              detail = 'fn foo()',
              kind = 12,
              name = 'foo',
              range = {
                ['end'] = {
                  character = 11,
                  line = 0,
                },
                start = {
                  character = 0,
                  line = 0,
                },
              },
              selectionRange = {
                ['end'] = {
                  character = 6,
                  line = 0,
                },
                start = {
                  character = 3,
                  line = 0,
                },
              },
              uri = 'file:///src/main.rs',
            },
          },
        }
        local handler = require 'vim.lsp.handlers'['callHierarchy/outgoingCalls']
        local bufnr = vim.api.nvim_get_current_buf()
        handler(nil, rust_analyzer_response, { bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 1,
          col = 5,
          end_col = 0,
          lnum = 4,
          end_lnum = 0,
          module = '',
          nr = 0,
          pattern = '',
          text = 'foo',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.incoming_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['callHierarchy/incomingCalls'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right callee', function()
      local qflist = exec_lua(function()
        local rust_analyzer_response = {
          {
            from = {
              detail = 'fn main()',
              kind = 12,
              name = 'main',
              range = {
                ['end'] = {
                  character = 1,
                  line = 4,
                },
                start = {
                  character = 0,
                  line = 2,
                },
              },
              selectionRange = {
                ['end'] = {
                  character = 7,
                  line = 2,
                },
                start = {
                  character = 3,
                  line = 2,
                },
              },
              uri = 'file:///src/main.rs',
            },
            fromRanges = {
              {
                ['end'] = {
                  character = 7,
                  line = 3,
                },
                start = {
                  character = 4,
                  line = 3,
                },
              },
            },
          },
        }

        local handler = require 'vim.lsp.handlers'['callHierarchy/incomingCalls']
        handler(nil, rust_analyzer_response, {})
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 5,
          end_col = 0,
          lnum = 4,
          end_lnum = 0,
          module = '',
          nr = 0,
          pattern = '',
          text = 'main',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.typehierarchy subtypes', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['typeHierarchy/subtypes'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right subtypes', function()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local clangd_response = {
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'EDC336589C09ABB2',
            },
            kind = 5,
            name = 'D2',
            range = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'AFFCAED15557EF08',
            },
            kind = 5,
            name = 'D1',
            range = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/subtypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'class B : public A{};',
          'class C : public B{};',
          'class D1 : public C{};',
          'class D2 : public C{};',
          'class E : public D1, D2 {};',
        })
        handler(nil, clangd_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D2',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 3,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D1',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)

    it('opens the quickfix list with the right subtypes and details', function()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local jdtls_response = {
          {
            data = { element = '=hello-java_ed323c3c/_<{Main.java[Main[A' },
            detail = '',
            kind = 5,
            name = 'A',
            range = {
              ['end'] = { character = 26, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 8, line = 3 },
              start = { character = 7, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/Main.java',
          },
          {
            data = { element = '=hello-java_ed323c3c/_<mylist{MyList.java[MyList[Inner' },
            detail = 'mylist',
            kind = 5,
            name = 'MyList$Inner',
            range = {
              ['end'] = { character = 37, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 19, line = 3 },
              start = { character = 14, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/mylist/MyList.java',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/subtypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'package mylist;',
          '',
          'public class MyList {',
          ' static class Inner extends MyList{}',
          '~}',
        })
        handler(nil, jdtls_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'A',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 3,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'MyList$Inner mylist',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }
      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.typehierarchy supertypes', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['typeHierarchy/supertypes'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right supertypes', function()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local clangd_response = {
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'EDC336589C09ABB2',
            },
            kind = 5,
            name = 'D2',
            range = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'AFFCAED15557EF08',
            },
            kind = 5,
            name = 'D1',
            range = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/supertypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'class B : public A{};',
          'class C : public B{};',
          'class D1 : public C{};',
          'class D2 : public C{};',
          'class E : public D1, D2 {};',
        })

        handler(nil, clangd_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D2',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 3,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D1',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)

    it('opens the quickfix list with the right supertypes and details', function()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local jdtls_response = {
          {
            data = { element = '=hello-java_ed323c3c/_<{Main.java[Main[A' },
            detail = '',
            kind = 5,
            name = 'A',
            range = {
              ['end'] = { character = 26, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 8, line = 3 },
              start = { character = 7, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/Main.java',
          },
          {
            data = { element = '=hello-java_ed323c3c/_<mylist{MyList.java[MyList[Inner' },
            detail = 'mylist',
            kind = 5,
            name = 'MyList$Inner',
            range = {
              ['end'] = { character = 37, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 19, line = 3 },
              start = { character = 14, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/mylist/MyList.java',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/supertypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'package mylist;',
          '',
          'public class MyList {',
          ' static class Inner extends MyList{}',
          '~}',
        })
        handler(nil, jdtls_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'A',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 3,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'MyList$Inner mylist',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }
      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.rename', function()
    for _, test in ipairs({
      {
        it = 'does not attempt to rename on nil response',
        name = 'prepare_rename_nil',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
      },
      {
        it = 'handles prepareRename placeholder response',
        name = 'prepare_rename_placeholder',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { {}, NIL, { method = 'textDocument/rename', client_id = 1, request_id = 3, bufnr = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        expected_text = 'placeholder', -- see fake lsp response
      },
      {
        it = 'handles range response',
        name = 'prepare_rename_range',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { {}, NIL, { method = 'textDocument/rename', client_id = 1, request_id = 3, bufnr = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        expected_text = 'line', -- see test case and fake lsp response
      },
      {
        it = 'handles error',
        name = 'prepare_rename_error',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
      },
    }) do
      it(test.it, function()
        local client --- @type vim.lsp.Client
        test_rpc_server {
          test_name = test.name,
          on_init = function(_client)
            client = _client
            eq(true, client.server_capabilities().renameProvider.prepareProvider)
          end,
          on_setup = function()
            exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.lsp._stubs = {}
              --- @diagnostic disable-next-line:duplicate-set-field
              vim.fn.input = function(opts, _)
                vim.lsp._stubs.input_prompt = opts.prompt
                vim.lsp._stubs.input_text = opts.default
                return 'renameto' -- expect this value in fake lsp
              end
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '', 'this is line two' })
              vim.fn.cursor(2, 13) -- the space between "line" and "two"
            end)
          end,
          on_exit = function(code, signal)
            eq(0, code, 'exit code')
            eq(0, signal, 'exit signal')
          end,
          on_handler = function(err, result, ctx)
            -- Don't compare & assert params and version, they're not relevant for the testcase
            -- This allows us to be lazy and avoid declaring them
            ctx.params = nil
            ctx.version = nil

            eq(table.remove(test.expected_handlers), { err, result, ctx }, 'expected handler')
            if ctx.method == 'start' then
              exec_lua(function()
                vim.lsp.buf.rename()
              end)
            end
            if ctx.method == 'shutdown' then
              if test.expected_text then
                eq(
                  'New Name: ',
                  exec_lua(function()
                    return vim.lsp._stubs.input_prompt
                  end)
                )
                eq(
                  test.expected_text,
                  exec_lua(function()
                    return vim.lsp._stubs.input_text
                  end)
                )
              end
              client:stop()
            end
          end,
        }
      end)
    end
  end)

  describe('vim.lsp.buf.code_action', function()
    it('calls client side command if available', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'code_action_with_resolve',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              vim.lsp.commands['dummy1'] = function(_)
                vim.lsp.commands['dummy2'] = function() end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              --- @diagnostic disable-next-line:duplicate-set-field
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            end)
          elseif ctx.method == 'shutdown' then
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['dummy2'])
              end)
            )
            client:stop()
          end
        end,
      }
    end)

    it('calls workspace/executeCommand if no client side command', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        {
          NIL,
          { command = 'dummy1', title = 'Command 1' },
          { bufnr = 1, method = 'workspace/executeCommand', request_id = 3, client_id = 1 },
        },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server({
        test_name = 'code_action_server_side_command',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code', fake_lsp_logfile)
          eq(0, signal, 'exit signal', fake_lsp_logfile)
        end,
        on_handler = function(err, result, ctx)
          ctx.params = nil -- don't compare in assert
          ctx.version = nil
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            end)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      })
    end)

    it('filters and automatically applies action if requested', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'code_action_filter',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              vim.lsp.commands['preferred_command'] = function(_)
                vim.lsp.commands['executed_preferred'] = function() end
              end
              vim.lsp.commands['type_annotate_command'] = function(_)
                vim.lsp.commands['executed_type_annotate'] = function() end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.lsp.buf.code_action({
                filter = function(a)
                  return a.isPreferred
                end,
                apply = true,
              })
              vim.lsp.buf.code_action({
                -- expect to be returned actions 'type-annotate' and 'type-annotate.foo'
                context = { only = { 'type-annotate' } },
                apply = true,
                filter = function(a)
                  if a.kind == 'type-annotate.foo' then
                    vim.lsp.commands['filtered_type_annotate_foo'] = function() end
                    return false
                  elseif a.kind == 'type-annotate' then
                    return true
                  else
                    assert(nil, 'unreachable')
                  end
                end,
              })
            end)
          elseif ctx.method == 'shutdown' then
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['executed_preferred'])
              end)
            )
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['filtered_type_annotate_foo'])
              end)
            )
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['executed_type_annotate'])
              end)
            )
            client:stop()
          end
        end,
      }
    end)

    it('uses diagnostics at cursor position', function()
      exec_lua(create_server_definition)
      local severity = exec_lua(function()
        return vim.diagnostic.severity.ERROR
      end)
      local messages = exec_lua(function(severity_)
        local server = _G._create_server({
          capabilities = {
            codeActionProvider = true,
          },
          handlers = {
            ['textDocument/codeAction'] = function(_, _, callback)
              callback(nil, {})
            end,
          },
        })

        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'local first, second = 1, 2' })

        local client_id = assert(vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        }))

        local expected_messages = 2 -- initialize, initialized
        local function wait_for_messages()
          assert(
            vim.wait(200, function()
              return #server.messages == expected_messages
            end),
            'Timed out waiting for expected number of messages. Current messages seen so far: '
              .. vim.inspect(server.messages)
          )
        end

        wait_for_messages()

        vim.api.nvim_win_set_cursor(0, { 1, 15 })

        local ns = vim.lsp.diagnostic.get_namespace(client_id)
        vim.diagnostic.set(ns, bufnr, {
          {
            lnum = 0,
            col = 6,
            end_lnum = 0,
            end_col = 11,
            message = 'first',
            severity = severity_,
            user_data = {
              lsp = {
                range = {
                  start = { line = 0, character = 6 },
                  ['end'] = { line = 0, character = 11 },
                },
                message = 'first',
                severity = severity_,
              },
            },
          },
          {
            lnum = 0,
            col = 13,
            end_lnum = 0,
            end_col = 19,
            message = 'second',
            severity = severity_,
            user_data = {
              lsp = {
                range = {
                  start = { line = 0, character = 13 },
                  ['end'] = { line = 0, character = 19 },
                },
                message = 'second',
                severity = severity_,
              },
            },
          },
        })

        vim.lsp.buf.code_action()

        expected_messages = expected_messages + 1
        wait_for_messages()

        vim.lsp.get_client_by_id(client_id):stop()

        return server.messages
      end, severity)

      eq('textDocument/codeAction', messages[3].method)
      eq({
        {
          range = {
            start = { line = 0, character = 13 },
            ['end'] = { line = 0, character = 19 },
          },
          message = 'second',
          severity = severity,
        },
      }, messages[3].params.context.diagnostics)
    end)

    it('fallback to command execution on resolve error', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            executeCommandProvider = {
              commands = { 'command:1' },
            },
            codeActionProvider = {
              resolveProvider = true,
            },
          },
          handlers = {
            ['textDocument/codeAction'] = function(_, _, callback)
              callback(nil, {
                {
                  title = 'Code Action 1',
                  command = {
                    title = 'Command 1',
                    command = 'command:1',
                  },
                },
              })
            end,
            ['codeAction/resolve'] = function(_, _, callback)
              callback('resolve failed', nil)
            end,
          },
        })

        local client_id = assert(vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        }))

        vim.lsp.buf.code_action({ apply = true })
        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      eq('codeAction/resolve', result[4].method)
      eq('workspace/executeCommand', result[5].method)
      eq('command:1', result[5].params.command)
    end)

    it('resolves command property', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            executeCommandProvider = {
              commands = { 'command:1' },
            },
            codeActionProvider = {
              resolveProvider = true,
            },
          },
          handlers = {
            ['textDocument/codeAction'] = function(_, _, callback)
              callback(nil, {
                { title = 'Code Action 1' },
              })
            end,
            ['codeAction/resolve'] = function(_, _, callback)
              callback(nil, {
                title = 'Code Action 1',
                command = {
                  title = 'Command 1',
                  command = 'command:1',
                },
              })
            end,
          },
        })

        local client_id = assert(vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        }))

        vim.lsp.buf.code_action({ apply = true })
        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      eq('codeAction/resolve', result[4].method)
      eq('workspace/executeCommand', result[5].method)
      eq('command:1', result[5].params.command)
    end)

    it('supports disabled actions', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            executeCommandProvider = {
              commands = { 'command:1' },
            },
            codeActionProvider = {
              resolveProvider = true,
            },
          },
          handlers = {
            ['textDocument/codeAction'] = function(_, _, callback)
              callback(nil, {
                {
                  title = 'Code Action 1',
                  disabled = {
                    reason = 'This action is disabled',
                  },
                },
              })
            end,
            ['codeAction/resolve'] = function(_, _, callback)
              callback(nil, {
                title = 'Code Action 1',
                command = {
                  title = 'Command 1',
                  command = 'command:1',
                },
              })
            end,
          },
        })

        local client_id = assert(vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        }))

        --- @diagnostic disable-next-line:duplicate-set-field
        vim.notify = function(message, code)
          server.messages[#server.messages + 1] = {
            params = {
              message = message,
              code = code,
            },
          }
        end

        vim.lsp.buf.code_action({ apply = true })
        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      eq(
        exec_lua(function()
          return { message = 'This action is disabled', code = vim.log.levels.ERROR }
        end),
        result[4].params
      )
      -- No command is resolved/applied after selecting a disabled code action
      eq('shutdown', result[5].method)
    end)
  end)

  describe('vim.lsp.commands', function()
    it('accepts only string keys', function()
      matches(
        '.*The key for commands in `vim.lsp.commands` must be a string',
        pcall_err(exec_lua, 'vim.lsp.commands[1] = function() end')
      )
    end)

    it('accepts only function values', function()
      matches(
        '.*Command added to `vim.lsp.commands` must be a function',
        pcall_err(exec_lua, 'vim.lsp.commands.dummy = 10')
      )
    end)
  end)

  describe('vim.lsp.buf.format', function()
    it('aborts with notify if no client matches filter', function()
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(c)
          client = c
        end,
        on_handler = function()
          local notify_msg = exec_lua(function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
            local notify_msg --- @type string?
            local notify = vim.notify
            vim.notify = function(msg, _)
              notify_msg = msg
            end
            vim.lsp.buf.format({ name = 'does-not-exist' })
            vim.notify = notify
            return notify_msg
          end)
          eq('[LSP] Format request failed, no matching language servers.', notify_msg)
          client:stop()
        end,
      }
    end)

    it('sends textDocument/formatting request to format buffer', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({ bufnr = bufnr })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('sends textDocument/rangeFormatting request to format a range', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'range_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar' })
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({
                bufnr = bufnr,
                range = {
                  start = { 1, 1 },
                  ['end'] = { 1, 1 },
                },
              })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('sends textDocument/rangesFormatting request to format multiple ranges', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'ranges_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar', 'baz' })
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({
                bufnr = bufnr,
                range = {
                  {
                    start = { 1, 1 },
                    ['end'] = { 1, 1 },
                  },
                  {
                    start = { 2, 2 },
                    ['end'] = { 2, 2 },
                  },
                },
              })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('can format async', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local result = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)

              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end

              _G.handler_called = false
              vim.lsp.buf.format({ bufnr = bufnr, async = true })
              vim.wait(1000, function()
                return _G.handler_called
              end)

              vim.notify = notify
              return { notify_msg = notify_msg, handler_called = _G.handler_called }
            end)
            eq({ handler_called = true }, result)
          elseif ctx.method == 'textDocument/formatting' then
            exec_lua('_G.handler_called = true')
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('format formats range in visual mode', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            documentFormattingProvider = true,
            documentRangeFormattingProvider = true,
          },
        })
        local bufnr = vim.api.nvim_get_current_buf()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.api.nvim_win_set_buf(0, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd.normal('v')
        vim.api.nvim_win_set_cursor(0, { 2, 3 })
        vim.lsp.buf.format({ bufnr = bufnr, false })
        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      eq('textDocument/rangeFormatting', result[3].method)
      local expected_range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 1, character = 4 },
      }
      eq(expected_range, result[3].params.range)
    end)

    it('format formats range in visual line mode', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            documentFormattingProvider = true,
            documentRangeFormattingProvider = true,
          },
        })
        local bufnr = vim.api.nvim_get_current_buf()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.api.nvim_win_set_buf(0, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar baz' })
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        vim.cmd.normal('V')
        vim.api.nvim_win_set_cursor(0, { 2, 1 })
        vim.lsp.buf.format({ bufnr = bufnr, false })

        -- Format again with visual lines going from bottom to top
        -- Must result in same formatting
        vim.cmd.normal('<ESC>')
        vim.api.nvim_win_set_cursor(0, { 2, 1 })
        vim.cmd.normal('V')
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        vim.lsp.buf.format({ bufnr = bufnr, false })

        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      local expected_methods = {
        'initialize',
        'initialized',
        'textDocument/rangeFormatting',
        '$/cancelRequest',
        'textDocument/rangeFormatting',
        '$/cancelRequest',
        'shutdown',
        'exit',
      }
      eq(
        expected_methods,
        vim.tbl_map(function(x)
          return x.method
        end, result)
      )
      -- uses first column of start line and last column of end line
      local expected_range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 1, character = 7 },
      }
      eq(expected_range, result[3].params.range)
      eq(expected_range, result[5].params.range)
    end)

    it('aborts with notify if no clients support requested method', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        vim.notify = function(msg, _)
          _G.notify_msg = msg
        end
      end)
      local fail_msg = '[LSP] Format request failed, no matching language servers.'
      --- @param name string
      --- @param formatting boolean
      --- @param range_formatting boolean
      local function check_notify(name, formatting, range_formatting)
        local timeout_msg = '[LSP][' .. name .. '] timeout'
        exec_lua(function()
          local server = _G._create_server({
            capabilities = {
              documentFormattingProvider = formatting,
              documentRangeFormattingProvider = range_formatting,
            },
          })
          vim.lsp.start({ name = name, cmd = server.cmd })
          _G.notify_msg = nil
          vim.lsp.buf.format({ name = name, timeout_ms = 1 })
        end)
        eq(
          formatting and timeout_msg or fail_msg,
          exec_lua(function()
            return _G.notify_msg
          end)
        )
        exec_lua(function()
          _G.notify_msg = nil
          vim.lsp.buf.format({
            name = name,
            timeout_ms = 1,
            range = {
              start = { 1, 0 },
              ['end'] = {
                1,
                0,
              },
            },
          })
        end)
        eq(
          range_formatting and timeout_msg or fail_msg,
          exec_lua(function()
            return _G.notify_msg
          end)
        )
      end
      check_notify('none', false, false)
      check_notify('formatting', true, false)
      check_notify('rangeFormatting', false, true)
      check_notify('both', true, true)
    end)
  end)

  describe('vim.lsp.buf.definition', function()
    it('jumps to single location and can reuse win', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local server = _G._create_server({
          capabilities = {
            definitionProvider = true,
          },
          handlers = {
            ['textDocument/definition'] = function(_, _, callback)
              local location = {
                range = {
                  start = { line = 0, character = 0 },
                  ['end'] = { line = 0, character = 0 },
                },
                uri = vim.uri_from_bufnr(bufnr),
              }
              callback(nil, location)
            end,
          },
        })
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'local x = 10', '', 'print(x)' })
        vim.api.nvim_win_set_cursor(win, { 3, 6 })
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.lsp.buf.definition()
        return {
          win = win,
          bufnr = bufnr,
          client_id = client_id,
          cursor = vim.api.nvim_win_get_cursor(win),
          messages = server.messages,
          tagstack = vim.fn.gettagstack(win),
        }
      end)
      eq('textDocument/definition', result.messages[3].method)
      eq({ 1, 0 }, result.cursor)
      eq(1, #result.tagstack.items)
      eq('x', result.tagstack.items[1].tagname)
      eq(3, result.tagstack.items[1].from[2])
      eq(7, result.tagstack.items[1].from[3])

      local result_bufnr = api.nvim_get_current_buf()
      n.feed(':tabe<CR>')
      api.nvim_win_set_buf(0, result_bufnr)
      local displayed_result_win = api.nvim_get_current_win()
      n.feed(':vnew<CR>')
      api.nvim_win_set_buf(0, result.bufnr)
      api.nvim_win_set_cursor(0, { 3, 6 })
      n.feed(':set switchbuf=usetab<CR>')
      n.feed(':=vim.lsp.buf.definition()<CR>')
      eq(displayed_result_win, api.nvim_get_current_win())
      exec_lua(function()
        vim.lsp.get_client_by_id(result.client_id):stop()
      end)
    end)
    it('merges results from multiple servers', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local function serveropts(character)
          return {
            capabilities = {
              definitionProvider = true,
            },
            handlers = {
              ['textDocument/definition'] = function(_, _, callback)
                local location = {
                  range = {
                    start = { line = 0, character = character },
                    ['end'] = { line = 0, character = character },
                  },
                  uri = vim.uri_from_bufnr(bufnr),
                }
                callback(nil, location)
              end,
            },
          }
        end
        local server1 = _G._create_server(serveropts(0))
        local server2 = _G._create_server(serveropts(7))
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'local x = 10', '', 'print(x)' })
        vim.api.nvim_win_set_cursor(win, { 3, 6 })
        local client_id1 = assert(vim.lsp.start({ name = 'dummy1', cmd = server1.cmd }))
        local client_id2 = assert(vim.lsp.start({ name = 'dummy2', cmd = server2.cmd }))
        local response
        vim.lsp.buf.definition({
          on_list = function(r)
            response = r
          end,
        })
        vim.lsp.get_client_by_id(client_id1):stop()
        vim.lsp.get_client_by_id(client_id2):stop()
        return response
      end)
      eq(2, #result.items)
    end)
  end)

  describe('vim.lsp.buf.workspace_diagnostics()', function()
    local fake_uri = 'file:///fake/uri'

    --- @param kind lsp.DocumentDiagnosticReportKind
    --- @param msg string
    --- @param pos integer
    --- @return lsp.WorkspaceDocumentDiagnosticReport
    local function make_report(kind, msg, pos)
      return {
        kind = kind,
        uri = fake_uri,
        items = {
          {
            range = {
              start = { line = pos, character = pos },
              ['end'] = { line = pos, character = pos },
            },
            message = msg,
            severity = 1,
          },
        },
      }
    end

    --- @param items lsp.WorkspaceDocumentDiagnosticReport[]
    --- @return integer
    local function setup_server(items)
      exec_lua(create_server_definition)
      return exec_lua(function()
        _G.server = _G._create_server({
          capabilities = {
            diagnosticProvider = { workspaceDiagnostics = true },
          },
          handlers = {
            ['workspace/diagnostic'] = function(_, _, callback)
              callback(nil, { items = items })
            end,
          },
        })
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd }))
        vim.lsp.buf.workspace_diagnostics()
        return client_id
      end, { items })
    end

    it('updates diagnostics obtained with vim.diagnostic.get()', function()
      setup_server({ make_report('full', 'Error here', 1) })

      retry(nil, nil, function()
        eq(
          1,
          exec_lua(function()
            return #vim.diagnostic.get()
          end)
        )
      end)

      eq(
        'Error here',
        exec_lua(function()
          return vim.diagnostic.get()[1].message
        end)
      )
    end)

    it('ignores unchanged diagnostic reports', function()
      setup_server({ make_report('unchanged', '', 1) })

      eq(
        0,
        exec_lua(function()
          -- Wait for diagnostics to be processed.
          vim.uv.sleep(50)

          return #vim.diagnostic.get()
        end)
      )
    end)

    it('favors document diagnostics over workspace diagnostics', function()
      local client_id = setup_server({ make_report('full', 'Workspace error', 1) })
      local diagnostic_bufnr = exec_lua(function()
        return vim.uri_to_bufnr(fake_uri)
      end)

      exec_lua(function()
        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            {
              range = {
                start = { line = 2, character = 2 },
                ['end'] = { line = 2, character = 2 },
              },
              message = 'Document error',
              severity = 1,
            },
          },
        }, {
          method = 'textDocument/diagnostic',
          params = {
            textDocument = { uri = fake_uri },
          },
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        })
      end)

      eq(
        1,
        exec_lua(function()
          return #vim.diagnostic.get(diagnostic_bufnr)
        end)
      )

      eq(
        'Document error',
        exec_lua(function()
          return vim.diagnostic.get(vim.uri_to_bufnr(fake_uri))[1].message
        end)
      )
    end)
  end)

  describe('vim.lsp.buf.hover()', function()
    it('handles empty contents', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            hoverProvider = true,
          },
          handlers = {
            ['textDocument/hover'] = function(_, _, callback)
              local res = {
                contents = {
                  kind = 'markdown',
                  value = '',
                },
              }
              callback(nil, res)
            end,
          },
        })
        vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      end)

      eq('Empty hover response', exec_capture('lua vim.lsp.buf.hover()'))
    end)

    it('treats markedstring array as not empty', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            hoverProvider = true,
          },
          handlers = {
            ['textDocument/hover'] = function(_, _, callback)
              local res = {
                contents = {
                  {
                    language = 'java',
                    value = 'Example',
                  },
                  'doc comment',
                },
              }
              callback(nil, res)
            end,
          },
        })
        vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      end)

      eq('', exec_capture('lua vim.lsp.buf.hover()'))
    end)
  end)
end)
