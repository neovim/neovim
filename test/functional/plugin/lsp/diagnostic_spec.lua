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

      client_id = assert(vim.lsp.start_client {
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
      })
    end)

    fake_uri = 'file:///fake/uri'

    exec_lua(function()
      diagnostic_bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = { '1st line of text', '2nd line of text', 'wow', 'cool', 'more', 'lines' }
      vim.fn.bufload(diagnostic_bufnr)
      vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, 1, false, lines)
      vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
    end)
  end)

  after_each(function()
    clear()
  end)

  describe('vim.lsp.diagnostic.on_publish_diagnostics', function()
    it('allows configuring the virtual text via vim.lsp.with', function()
      local expected_spacing = 10
      local extmarks = exec_lua(function()
        _G.PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = {
            spacing = expected_spacing,
          },
        })

        _G.PublishDiagnostics(nil, {
          uri = fake_uri,
          diagnostics = {
            _G.make_error('Delayed Diagnostic', 4, 4, 4, 4),
          },
        }, { client_id = client_id })

        return _G.get_extmarks(diagnostic_bufnr, client_id)
      end)

      local spacing = extmarks[1][4].virt_text[1][1]

      eq(expected_spacing, #spacing)
    end)

    it('allows configuring the virtual text via vim.lsp.with using a function', function()
      local expected_spacing = 10
      local extmarks = exec_lua(function()
        _G.PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = function()
            return {
              spacing = expected_spacing,
            }
          end,
        })

        _G.PublishDiagnostics(nil, {
          uri = fake_uri,
          diagnostics = {
            _G.make_error('Delayed Diagnostic', 4, 4, 4, 4),
          },
        }, { client_id = client_id })

        return _G.get_extmarks(diagnostic_bufnr, client_id)
      end)

      local spacing = extmarks[1][4].virt_text[1][1]

      eq(expected_spacing, #spacing)
    end)

    it('allows filtering via severity limit', function()
      local get_extmark_count_with_severity = function(severity_limit)
        return exec_lua(function()
          _G.PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
            underline = false,
            virtual_text = {
              severity = { min = severity_limit },
            },
          })

          _G.PublishDiagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              _G.make_warning('Delayed Diagnostic', 4, 4, 4, 4),
            },
          }, { client_id = client_id })

          return #_G.get_extmarks(diagnostic_bufnr, client_id)
        end, client_id, fake_uri, severity_limit)
      end

      -- No messages with Error or higher
      eq(0, get_extmark_count_with_severity('ERROR'))

      -- But now we don't filter it
      eq(1, get_extmark_count_with_severity('WARN'))
      eq(1, get_extmark_count_with_severity('HINT'))
    end)

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
          return vim.str_byteindex(line, 7, true)
        end),
        result[1].col
      )
      eq(
        exec_lua(function()
          return vim.str_byteindex(line, 8, true)
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
        _G.server = _G._create_server({
          capabilities = {
            diagnosticProvider = {},
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
        }, {})

        return vim.diagnostic.get(diagnostic_bufnr)
      end)
      eq(1, #diags)
      eq('Pull Diagnostic', diags[1].message)
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
        }, {})
        return vim.diagnostic.get(diagnostic_bufnr)
      end)
      eq(1, #diagnostics)
      eq(1, diagnostics[1].severity)
    end)

    it('allows configuring the virtual text via vim.lsp.with', function()
      local expected_spacing = 10
      local extmarks = exec_lua(function()
        _G.Diagnostic = vim.lsp.with(vim.lsp.diagnostic.on_diagnostic, {
          virtual_text = {
            spacing = expected_spacing,
          },
        })

        _G.Diagnostic(nil, {
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
        }, {})

        return _G.get_extmarks(diagnostic_bufnr, client_id)
      end)
      eq(2, #extmarks)
      eq(expected_spacing, #extmarks[1][4].virt_text[1][1])
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
  end)
end)
