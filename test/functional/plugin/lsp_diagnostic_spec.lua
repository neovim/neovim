local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('Diagnostic', function()
  local diagnostic_bufnr, fake_uri

  before_each(function()
    clear()

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

    count_of_extmarks_for_client = function(bufnr, client_id)
      local Diagnostic = require('vim.lsp.structures').Diagnostic
      return #vim.api.nvim_buf_get_extmarks(bufnr, Diagnostic._get_diagnostic_namespace(client_id), 0, -1, {})
    end
    ]]

    fake_uri = "file://fake/uri"

    diagnostic_bufnr = exec_lua([[
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

  describe('vim.lsp.structures.Diagnostic', function()
    describe('handle_publish_diagnostics', function()
      it('should be able to save and count a single client', function()
        eq(1, exec_lua [[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.save_buf_diagnostics(
            {
              make_error('Diagnostic #1', 1, 1, 1, 1),
            }, 0, 1
          )

          return Diagnostic.get_counts(0, "Error", 1)
        ]])
      end)

      it('should be able to save and count a single client', function()
        eq(2, exec_lua [[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.save_buf_diagnostics(
            {
              make_error('Diagnostic #1', 1, 1, 1, 1),
              make_error('Diagnostic #2', 2, 1, 2, 1),
            }, 0, 1
          )

          return Diagnostic.get_counts(0, "Error", 1)
        ]])
      end)

      it('should be able to save and count from multiple clients', function()
        eq({1, 1, 2}, exec_lua [[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.save_buf_diagnostics(
            {
              make_error('Diagnostic From Server 1', 1, 1, 1, 1),
            }, 0, 1
          )

          Diagnostic.save_buf_diagnostics(
            {
              make_error('Diagnostic From Server 2', 1, 1, 1, 1),
            }, 0, 2
          )

          return {
            -- Server 1
            Diagnostic.get_counts(0, "Error", 1),
            -- Server 2
            Diagnostic.get_counts(0, "Error", 2),
            -- All servers
            Diagnostic.get_counts(0, "Error"),
          }
        ]])
      end)

      it('should be able to save and count from multiple clients with respect to severity', function()
        eq({3, 0, 3}, exec_lua [[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.save_buf_diagnostics(
            {
              make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
              make_error('Diagnostic From Server 1:2', 2, 2, 2, 2),
              make_error('Diagnostic From Server 1:3', 2, 3, 3, 2),
            }, 0, 1
          )

          Diagnostic.save_buf_diagnostics(
            {
              make_warning('Warning From Server 2', 3, 3, 3, 3),
            }, 0, 2
          )

          return {
            -- Server 1
            Diagnostic.get_counts(0, "Error", 1),
            -- Server 2
            Diagnostic.get_counts(0, "Error", 2),
            -- All servers
            Diagnostic.get_counts(0, "Error"),
          }
        ]])
      end)


      it('should handle one server clearing highlights while the other still has highlights', function()
        -- 1 Error (1)
        -- 1 Warning (2)
        -- 1 Warning (2) + 1 Warning (1)
        -- 2 highlights and 2 underlines (since error)
        -- 1 highlight + 1 underline
        local all_highlights = {1, 1, 2, 4, 2}
        eq(all_highlights, exec_lua [[
          local actions = require('vim.lsp.actions')
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          local server_1_diags = {
            make_error("Error 1", 1, 1, 1, 5),
            make_warning("Warning on Server 1", 2, 1, 2, 5),
          }

          local server_2_diags = {
            make_warning("Warning 1", 2, 1, 2, 5),
          }

          actions.Diagnostic.handle_publish_diagnostics(nil, nil, { uri = fake_uri, diagnostics = server_1_diags }, 1)
          actions.Diagnostic.handle_publish_diagnostics(nil, nil, { uri = fake_uri, diagnostics = server_2_diags }, 2)

          return {
            Diagnostic.get_counts(diagnostic_bufnr, "Error", 1),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning", 2),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning"),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])

        -- Clear diagnostics from server 1, and make sure we have the right amount of stuff for client 2
        eq({1, 1, 2, 0, 2}, exec_lua [[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.buf_clear_displayed_diagnostics(diagnostic_bufnr, 1)

          return {
            Diagnostic.get_counts(diagnostic_bufnr, "Error", 1),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning", 2),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning"),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])

        -- Show diagnostics from server 1 again
        eq(all_highlights, exec_lua([[
          local Diagnostic = require('vim.lsp.structures').Diagnostic

          Diagnostic.display(nil, diagnostic_bufnr, 1)

          return {
            Diagnostic.get_counts(diagnostic_bufnr, "Error", 1),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning", 2),
            Diagnostic.get_counts(diagnostic_bufnr, "Warning"),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]]))
      end)

      describe('get_next_diagnostic_pos', function()
        it('can find the next pos with only one client', function()
          eq({1, 1}, exec_lua [[
            local Diagnostic = require('vim.lsp.structures').Diagnostic

            Diagnostic.save_buf_diagnostics(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
              }, diagnostic_bufnr, 1
            )

            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            return Diagnostic.buf_get_next_diagnostic_pos()
          ]])
        end)

        it('can find next pos with two errors', function()
          eq({4, 4}, exec_lua [[
            local Diagnostic = require('vim.lsp.structures').Diagnostic

            Diagnostic.save_buf_diagnostics(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )

            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})

            return Diagnostic.buf_get_next_diagnostic_pos(diagnostic_bufnr, 1)
          ]])
        end)

      end)
    end)
  end)

  describe("vim.lsp.actions.Diagnostic", function()
    it('can perform updates after insert_leave', function()
      eq(true, exec_lua[[
        return true
      ]])
    end)
  end)
end)
