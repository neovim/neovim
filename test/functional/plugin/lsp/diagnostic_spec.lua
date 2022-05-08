local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local neq = require('test.helpers').neq

describe('vim.lsp.diagnostic', function()
  local fake_uri

  before_each(function()
    clear {env={
      NVIM_LUA_NOTRACK="1";
      VIMRUNTIME=os.getenv"VIMRUNTIME";
    }}

    exec_lua [[
      require('vim.lsp')

      make_range = function(x1, y1, x2, y2)
        return { start = { line = x1, character = y1 }, ['end'] = { line = x2, character = y2 } }
      end

      make_error = function(msg, x1, y1, x2, y2)
        return {
          range = make_range(x1, y1, x2, y2),
          message = msg,
          severity = 1,
        }
      end

      make_warning = function(msg, x1, y1, x2, y2)
        return {
          range = make_range(x1, y1, x2, y2),
          message = msg,
          severity = 2,
        }
      end

      make_information = function(msg, x1, y1, x2, y2)
        return {
          range = make_range(x1, y1, x2, y2),
          message = msg,
          severity = 3,
        }
      end

      function get_extmarks(bufnr, client_id)
        local namespace = vim.lsp.diagnostic.get_namespace(client_id)
        local ns = vim.diagnostic.get_namespace(namespace)
        local extmarks = {}
        if ns.user_data.virt_text_ns then
          for _, e in pairs(vim.api.nvim_buf_get_extmarks(bufnr, ns.user_data.virt_text_ns, 0, -1, {details=true})) do
            table.insert(extmarks, e)
          end
        end
        if ns.user_data.underline_ns then
          for _, e in pairs(vim.api.nvim_buf_get_extmarks(bufnr, ns.user_data.underline_ns, 0, -1, {details=true})) do
            table.insert(extmarks, e)
          end
        end
        return extmarks
      end

      client_id = vim.lsp.start_client {
        cmd_env = {
          NVIM_LUA_NOTRACK = "1";
        };
        cmd = {
          vim.v.progpath, '-es', '-u', 'NONE', '--headless'
        };
        offset_encoding = "utf-16";
      }
    ]]

    fake_uri = "file:///fake/uri"

    exec_lua([[
      fake_uri = ...
      diagnostic_bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = {"1st line of text", "2nd line of text", "wow", "cool", "more", "lines"}
      vim.fn.bufload(diagnostic_bufnr)
      vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, 1, false, lines)
      return diagnostic_bufnr
    ]], fake_uri)
  end)

  after_each(function()
    clear()
  end)

  describe('vim.lsp.diagnostic', function()
    it('maintains LSP information when translating diagnostics', function()
      local result = exec_lua [[
        local diagnostics = {
          make_error("Error 1", 1, 1, 1, 5),
        }

        diagnostics[1].code = 42
        diagnostics[1].tags = {"foo", "bar"}
        diagnostics[1].data = "Hello world"

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = fake_uri,
          diagnostics = diagnostics,
        }, {client_id=client_id})

        return {
          vim.diagnostic.get(diagnostic_bufnr, {lnum=1})[1],
          vim.lsp.diagnostic.get_line_diagnostics(diagnostic_bufnr, 1)[1],
        }
      ]]
      eq({code = 42, tags = {"foo", "bar"}, data = "Hello world"}, result[1].user_data.lsp)
      eq(42, result[1].code)
      eq(42, result[2].code)
      eq({"foo", "bar"}, result[2].tags)
      eq("Hello world", result[2].data)
    end)
  end)

  describe("vim.lsp.diagnostic.on_publish_diagnostics", function()
    it('allows configuring the virtual text via vim.lsp.with', function()
      local expected_spacing = 10
      local extmarks = exec_lua([[
        PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = {
            spacing = ...,
          },
        })

        PublishDiagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=client_id}
        )

        return get_extmarks(diagnostic_bufnr, client_id)
      ]], expected_spacing)

      local virt_text = extmarks[1][4].virt_text
      local spacing = virt_text[1][1]

      eq(expected_spacing, #spacing)
    end)

    it('allows configuring the virtual text via vim.lsp.with using a function', function()
      local expected_spacing = 10
      local extmarks = exec_lua([[
        spacing = ...

        PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = function()
            return {
              spacing = spacing,
            }
          end,
        })

        PublishDiagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=client_id}
        )

        return get_extmarks(diagnostic_bufnr, client_id)
      ]], expected_spacing)

      local virt_text = extmarks[1][4].virt_text
      local spacing = virt_text[1][1]

      eq(expected_spacing, #spacing)
    end)

    it('allows filtering via severity limit', function()
      local get_extmark_count_with_severity = function(severity_limit)
        return exec_lua([[
          PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
            underline = false,
            virtual_text = {
              severity_limit = ...
            },
          })

          PublishDiagnostics(nil, {
              uri = fake_uri,
              diagnostics = {
                make_warning('Delayed Diagnostic', 4, 4, 4, 4),
              }
            }, {client_id=client_id}
          )

          return #get_extmarks(diagnostic_bufnr, client_id)
        ]], severity_limit)
      end

      -- No messages with Error or higher
      eq(0, get_extmark_count_with_severity("Error"))

      -- But now we don't filter it
      eq(1, get_extmark_count_with_severity("Warning"))
      eq(1, get_extmark_count_with_severity("Hint"))
    end)

    it('correctly handles UTF-16 offsets', function()
      local line = "All 💼 and no 🎉 makes Jack a dull 👦"
      local result = exec_lua([[
        local line = ...
        vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, -1, false, {line})

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('UTF-16 Diagnostic', 0, 7, 0, 8),
            }
          }, {client_id=client_id}
        )

        local diags = vim.diagnostic.get(diagnostic_bufnr)
        vim.lsp.stop_client(client_id)
        vim.lsp._vim_exit_handler()
        return diags
      ]], line)
      eq(1, #result)
      eq(exec_lua([[return vim.str_byteindex(..., 7, true)]], line), result[1].col)
      eq(exec_lua([[return vim.str_byteindex(..., 8, true)]], line), result[1].end_col)
    end)

    it('does not create buffer on empty diagnostics', function()
      local bufnr

      -- No buffer is created without diagnostics
      bufnr = exec_lua [[
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = "file:///fake/uri2",
          diagnostics = {},
        }, {client_id=client_id})
        return vim.fn.bufnr(vim.uri_to_fname("file:///fake/uri2"))
      ]]
      eq(bufnr, -1)

      -- Create buffer on diagnostics
      bufnr = exec_lua [[
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = "file:///fake/uri2",
          diagnostics = {
            make_error('Diagnostic', 0, 0, 0, 0),
          },
        }, {client_id=client_id})
        return vim.fn.bufnr(vim.uri_to_fname("file:///fake/uri2"))
      ]]
      neq(bufnr, -1)
      eq(exec_lua([[return #vim.diagnostic.get(...)]], bufnr), 1)

      -- Clear diagnostics after buffer was created
      bufnr = exec_lua [[
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = "file:///fake/uri2",
          diagnostics = {},
        }, {client_id=client_id})
        return vim.fn.bufnr(vim.uri_to_fname("file:///fake/uri2"))
      ]]
      neq(bufnr, -1)
      eq(exec_lua([[return #vim.diagnostic.get(...)]], bufnr), 0)
    end)
  end)
end)
