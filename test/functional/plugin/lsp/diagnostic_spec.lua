local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local t_lsp = require('test.functional.plugin.lsp.testutil')

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local neq = t.neq

local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.diagnostic', function()
  local fake_uri --- @type string
  local client_id --- @type integer
  local diagnostic_bufnr --- @type integer

  before_each(function()
    clear { env = {
      NVIM_LUA_NOTRACK = '1',
      VIMRUNTIME = os.getenv 'VIMRUNTIME',
    } }

    exec_lua(function()
      require('vim.lsp')

      _G.make_range = function(x1, y1, x2, y2)
        return { start = { line = x1, character = y1 }, ['end'] = { line = x2, character = y2 } }
      end

      _G.make_error = function(msg, x1, y1, x2, y2)
        return {
          range = _G.make_range(x1, y1, x2, y2),
          message = msg,
          severity = 1,
        }
      end

      _G.make_warning = function(msg, x1, y1, x2, y2)
        return {
          range = _G.make_range(x1, y1, x2, y2),
          message = msg,
          severity = 2,
        }
      end

      _G.make_information = function(msg, x1, y1, x2, y2)
        return {
          range = _G.make_range(x1, y1, x2, y2),
          message = msg,
          severity = 3,
        }
      end

      function _G.get_extmarks(bufnr, client_id0)
        local namespace = vim.lsp.diagnostic.get_namespace(client_id0)
        local ns = vim.diagnostic.get_namespace(namespace)
        local extmarks = {}
        if ns.user_data.virt_text_ns then
          for _, e in
            pairs(
              vim.api.nvim_buf_get_extmarks(
                bufnr,
                ns.user_data.virt_text_ns,
                0,
                -1,
                { details = true }
              )
            )
          do
            table.insert(extmarks, e)
          end
        end
        if ns.user_data.underline_ns then
          for _, e in
            pairs(
              vim.api.nvim_buf_get_extmarks(
                bufnr,
                ns.user_data.underline_ns,
                0,
                -1,
                { details = true }
              )
            )
          do
            table.insert(extmarks, e)
          end
        end
        return extmarks
      end

      client_id = assert(vim.lsp.start({
        cmd_env = {
          NVIM_LUA_NOTRACK = '1',
        },
        cmd = {
          vim.v.progpath,
          '-es',
          '-u',
          'NONE',
          '--headless',
        },
        offset_encoding = 'utf-16',
      }, { attach = false }))
    end)

    fake_uri = 'file:///fake/uri'

    exec_lua(function()
      diagnostic_bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = { '1st line', '2nd line of text', 'wow', 'cool', 'more', 'lines' }
      vim.fn.bufload(diagnostic_bufnr)
      vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, 1, false, lines)
      vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
    end)
  end)

  after_each(function()
    clear()
  end)

  describe('vim.lsp.diagnostic.on_publish_diagnostics', function()
    it('correctly handles UTF-16 offsets', function()
      local line = 'All 💼 and no 🎉 makes Jack a dull 👦'
      local result = exec_lua(function()
        vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, -1, false, { line })

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = fake_uri,
          diagnostics = {
            _G.make_error('UTF-16 Diagnostic', 0, 7, 0, 8),
          },
        }, { client_id = client_id })

        local diags = vim.diagnostic.get(diagnostic_bufnr)
        vim.lsp.stop_client(client_id)
        vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
        return diags
      end)
      eq(1, #result)
      eq(
        exec_lua(function()
          return vim.str_byteindex(line, 'utf-16', 7)
        end),
        result[1].col
      )
      eq(
        exec_lua(function()
          return vim.str_byteindex(line, 'utf-16', 8)
        end),
        result[1].end_col
      )
    end)

    it('does not create buffer on empty diagnostics', function()
      -- No buffer is created without diagnostics
      eq(
        -1,
        exec_lua(function()
          vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = 'file:///fake/uri2',
            diagnostics = {},
          }, { client_id = client_id })
          return vim.fn.bufnr(vim.uri_to_fname('file:///fake/uri2'))
        end)
      )

      -- Create buffer on diagnostics
      neq(
        -1,
        exec_lua(function()
          vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = 'file:///fake/uri2',
            diagnostics = {
              _G.make_error('Diagnostic', 0, 0, 0, 0),
            },
          }, { client_id = client_id })
          return vim.fn.bufnr(vim.uri_to_fname('file:///fake/uri2'))
        end)
      )
      eq(
        1,
        exec_lua(function()
          return #vim.diagnostic.get(_G.bufnr)
        end)
      )

      -- Clear diagnostics after buffer was created
      neq(
        -1,
        exec_lua(function()
          vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = 'file:///fake/uri2',
            diagnostics = {},
          }, { client_id = client_id })
          return vim.fn.bufnr(vim.uri_to_fname('file:///fake/uri2'))
        end)
      )
      eq(
        0,
        exec_lua(function()
          return #vim.diagnostic.get(_G.bufnr)
        end)
      )
    end)
  end)

  describe('vim.lsp.diagnostic.on_diagnostic', function()
    before_each(function()
      exec_lua(create_server_definition)
      exec_lua(function()
        _G.requests = 0
        _G.server = _G._create_server({
          capabilities = {
            diagnosticProvider = {},
          },
          handlers = {
            [vim.lsp.protocol.Methods.textDocument_diagnostic] = function(_, params)
              _G.params = params
              _G.requests = _G.requests + 1
            end,
          },
        })

        function _G.get_extmarks(bufnr, client_id0)
          local namespace = vim.lsp.diagnostic.get_namespace(client_id0, true)
          local ns = vim.diagnostic.get_namespace(namespace)
          local extmarks = {}
          if ns.user_data.virt_text_ns then
            for _, e in
              pairs(
                vim.api.nvim_buf_get_extmarks(
                  bufnr,
                  ns.user_data.virt_text_ns,
                  0,
                  -1,
                  { details = true }
                )
              )
            do
              table.insert(extmarks, e)
            end
          end
          if ns.user_data.underline_ns then
            for _, e in
              pairs(
                vim.api.nvim_buf_get_extmarks(
                  bufnr,
                  ns.user_data.underline_ns,
                  0,
                  -1,
                  { details = true }
                )
              )
            do
              table.insert(extmarks, e)
            end
          end
          return extmarks
        end

        client_id = vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
      end)
    end)

    it('adds diagnostics to vim.diagnostics', function()
      local diags = exec_lua(function()
        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            _G.make_error('Pull Diagnostic', 4, 4, 4, 4),
          },
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})

        return vim.diagnostic.get(diagnostic_bufnr)
      end)
      eq(1, #diags)
      eq('Pull Diagnostic', diags[1].message)
    end)

    it('handles multiline diagnostic ranges #33782', function()
      local diags = exec_lua(function()
        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            _G.make_error('Pull Diagnostic', 0, 6, 1, 10),
          },
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})

        return vim.diagnostic.get(diagnostic_bufnr)
      end)
      local lines = exec_lua(function()
        return vim.api.nvim_buf_get_lines(diagnostic_bufnr, 0, -1, false)
      end)
      -- This test case must be run over a multiline diagnostic in which the start line is shorter
      -- than the end line, and the end_col exceeds the start line's length.
      eq(#lines[1], 8)
      eq(#lines[2], 16)
      eq(1, #diags)
      eq(6, diags[1].col)
      eq(10, diags[1].end_col)
    end)

    it('severity defaults to error if missing', function()
      ---@type vim.Diagnostic[]
      local diagnostics = exec_lua(function()
        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            {
              range = _G.make_range(4, 4, 4, 4),
              message = 'bad!',
            },
          },
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})
        return vim.diagnostic.get(diagnostic_bufnr)
      end)
      eq(1, #diagnostics)
      eq(1, diagnostics[1].severity)
    end)

    it('clears diagnostics when client detaches', function()
      exec_lua(function()
        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            _G.make_error('Pull Diagnostic', 4, 4, 4, 4),
          },
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})
      end)

      eq(
        1,
        exec_lua(function()
          return #vim.diagnostic.get(diagnostic_bufnr)
        end)
      )

      exec_lua(function()
        vim.lsp.stop_client(client_id)
      end)

      eq(
        0,
        exec_lua(function()
          return #vim.diagnostic.get(diagnostic_bufnr)
        end)
      )
    end)

    it('keeps diagnostics when one client detaches and others still are attached', function()
      local client_id2
      exec_lua(function()
        client_id2 = vim.lsp.start({ name = 'dummy2', cmd = _G.server.cmd })

        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          items = {
            _G.make_error('Pull Diagnostic', 4, 4, 4, 4),
          },
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})
      end)

      eq(
        1,
        exec_lua(function()
          return #vim.diagnostic.get(diagnostic_bufnr)
        end)
      )

      exec_lua(function()
        vim.lsp.stop_client(client_id2)
      end)

      eq(
        1,
        exec_lua(function()
          return #vim.diagnostic.get(diagnostic_bufnr)
        end)
      )
    end)

    it('handles server cancellation', function()
      eq(
        1,
        exec_lua(function()
          vim.lsp.diagnostic.on_diagnostic({
            code = vim.lsp.protocol.ErrorCodes.ServerCancelled,
            -- Empty data defaults to retriggering request
            data = {},
            message = '',
          }, {}, {
            method = vim.lsp.protocol.Methods.textDocument_diagnostic,
            client_id = client_id,
            bufnr = diagnostic_bufnr,
          })

          return _G.requests
        end)
      )

      eq(
        2,
        exec_lua(function()
          vim.lsp.diagnostic.on_diagnostic({
            code = vim.lsp.protocol.ErrorCodes.ServerCancelled,
            data = { retriggerRequest = true },
            message = '',
          }, {}, {
            method = vim.lsp.protocol.Methods.textDocument_diagnostic,
            client_id = client_id,
            bufnr = diagnostic_bufnr,
          })

          return _G.requests
        end)
      )

      eq(
        2,
        exec_lua(function()
          vim.lsp.diagnostic.on_diagnostic({
            code = vim.lsp.protocol.ErrorCodes.ServerCancelled,
            data = { retriggerRequest = false },
            message = '',
          }, {}, {
            method = vim.lsp.protocol.Methods.textDocument_diagnostic,
            client_id = client_id,
            bufnr = diagnostic_bufnr,
          })

          return _G.requests
        end)
      )
    end)

    it('requests with the `previousResultId`', function()
      -- Full reports
      eq(
        'dummy_server',
        exec_lua(function()
          vim.lsp.diagnostic.on_diagnostic(nil, {
            kind = 'full',
            resultId = 'dummy_server',
            items = {
              _G.make_error('Pull Diagnostic', 4, 4, 4, 4),
            },
          }, {
            method = vim.lsp.protocol.Methods.textDocument_diagnostic,
            params = {
              textDocument = { uri = fake_uri },
            },
            client_id = client_id,
            bufnr = diagnostic_bufnr,
          })
          vim.api.nvim_exec_autocmds('LspNotify', {
            buffer = diagnostic_bufnr,
            data = {
              method = vim.lsp.protocol.Methods.textDocument_didChange,
              client_id = client_id,
            },
          })
          return _G.params.previousResultId
        end)
      )

      -- Unchanged reports
      eq(
        'squidward',
        exec_lua(function()
          vim.lsp.diagnostic.on_diagnostic(nil, {
            kind = 'unchanged',
            resultId = 'squidward',
          }, {
            method = vim.lsp.protocol.Methods.textDocument_diagnostic,
            params = {
              textDocument = { uri = fake_uri },
            },
            client_id = client_id,
            bufnr = diagnostic_bufnr,
          })
          vim.api.nvim_exec_autocmds('LspNotify', {
            buffer = diagnostic_bufnr,
            data = {
              method = vim.lsp.protocol.Methods.textDocument_didChange,
              client_id = client_id,
            },
          })
          return _G.params.previousResultId
        end)
      )
    end)

    it('handles relatedDocuments diagnostics', function()
      local fake_uri_2 = 'file:///fake/uri2'
      ---@type vim.Diagnostic[], vim.Diagnostic[], string?
      local diagnostics, related_diagnostics, relatedPreviousResultId = exec_lua(function()
        local second_buf = vim.uri_to_bufnr(fake_uri_2)
        vim.fn.bufload(second_buf)

        -- Attach the client to both buffers.
        vim.api.nvim_win_set_buf(0, second_buf)
        vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })

        vim.lsp.diagnostic.on_diagnostic(nil, {
          kind = 'full',
          relatedDocuments = {
            [fake_uri_2] = {
              kind = 'full',
              resultId = 'spongebob',
              items = {
                {
                  range = _G.make_range(4, 4, 4, 4),
                  message = 'related bad!',
                },
              },
            },
          },
          items = {},
        }, {
          params = {
            textDocument = { uri = fake_uri },
          },
          uri = fake_uri,
          client_id = client_id,
          bufnr = diagnostic_bufnr,
        }, {})

        vim.api.nvim_exec_autocmds('LspNotify', {
          buffer = second_buf,
          data = {
            method = vim.lsp.protocol.Methods.textDocument_didChange,
            client_id = client_id,
          },
        })

        return vim.diagnostic.get(diagnostic_bufnr),
          vim.diagnostic.get(second_buf),
          _G.params.previousResultId
      end)
      eq(0, #diagnostics)
      eq(1, #related_diagnostics)
      eq('related bad!', related_diagnostics[1].message)
      eq('spongebob', relatedPreviousResultId)
    end)
  end)
end)
