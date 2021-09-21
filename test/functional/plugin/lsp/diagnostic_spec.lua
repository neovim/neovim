local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local nvim = helpers.nvim

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

      count_of_extmarks_for_client = function(bufnr, client_id)
        return #vim.api.nvim_buf_get_extmarks(
          bufnr, vim.lsp.diagnostic.get_namespace(client_id), 0, -1, {}
        )
      end
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
    describe('handle_publish_diagnostics', function()
      it('should be able to retrieve diagnostics from all buffers and clients', function()
        local result = exec_lua [[
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic #1', 1, 1, 1, 1),
              make_error('Diagnostic #2', 2, 1, 2, 1),
            }, 1, 1
          )
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic #3', 3, 1, 3, 1),
            }, 2, 2
          )
          return vim.lsp.diagnostic.get_all()
        ]]
        eq(2, #result)
        eq(2, #result[1])
        eq('Diagnostic #1', result[1][1].message)
      end)
      it('should be able to save and count a single client error', function()
        eq(1, exec_lua [[
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic #1', 1, 1, 1, 1),
            }, 0, 1
          )
          return vim.lsp.diagnostic.get_count(0, "Error", 1)
        ]])
      end)

      it('should be able to save and count from two clients', function()
        eq(2, exec_lua [[
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic #1', 1, 1, 1, 1),
              make_error('Diagnostic #2', 2, 1, 2, 1),
            }, 0, 1
          )
          return vim.lsp.diagnostic.get_count(0, "Error", 1)
        ]])
      end)

      it('should be able to save and count from multiple clients', function()
        eq({1, 1, 2}, exec_lua [[
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic From Server 1', 1, 1, 1, 1),
            }, 0, 1
          )
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic From Server 2', 1, 1, 1, 1),
            }, 0, 2
          )
          return {
            -- Server 1
            vim.lsp.diagnostic.get_count(0, "Error", 1),
            -- Server 2
            vim.lsp.diagnostic.get_count(0, "Error", 2),
            -- All servers
            vim.lsp.diagnostic.get_count(0, "Error", nil),
          }
        ]])
      end)

      it('should be able to save and count from multiple clients with respect to severity', function()
        eq({3, 0, 3}, exec_lua [[
          vim.lsp.diagnostic.save(
            {
              make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
              make_error('Diagnostic From Server 1:2', 2, 2, 2, 2),
              make_error('Diagnostic From Server 1:3', 2, 3, 3, 2),
            }, 0, 1
          )
          vim.lsp.diagnostic.save(
            {
              make_warning('Warning From Server 2', 3, 3, 3, 3),
            }, 0, 2
          )
          return {
            -- Server 1
            vim.lsp.diagnostic.get_count(0, "Error", 1),
            -- Server 2
            vim.lsp.diagnostic.get_count(0, "Error", 2),
            -- All servers
            vim.lsp.diagnostic.get_count(0, "Error", nil),
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
          local server_1_diags = {
            make_error("Error 1", 1, 1, 1, 5),
            make_warning("Warning on Server 1", 2, 1, 2, 5),
          }
          local server_2_diags = {
            make_warning("Warning 1", 2, 1, 2, 5),
          }

          vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_1_diags }, {client_id=1})
          vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_2_diags }, {client_id=2})
          return {
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])

        -- Clear diagnostics from server 1, and make sure we have the right amount of stuff for client 2
        eq({1, 1, 2, 0, 2}, exec_lua [[
          vim.lsp.diagnostic.disable(diagnostic_bufnr, 1)
          return {
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])

        -- Show diagnostics from server 1 again
        eq(all_highlights, exec_lua([[
          vim.lsp.diagnostic.enable(diagnostic_bufnr, 1)
          return {
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
            vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]]))
      end)

      it('should not display diagnostics when disabled', function()
        eq({0, 2}, exec_lua [[
          local server_1_diags = {
            make_error("Error 1", 1, 1, 1, 5),
            make_warning("Warning on Server 1", 2, 1, 2, 5),
          }
          local server_2_diags = {
            make_warning("Warning 1", 2, 1, 2, 5),
          }

          vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_1_diags }, {client_id=1})
          vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_2_diags }, {client_id=2})

          vim.lsp.diagnostic.disable(diagnostic_bufnr, 1)

          return {
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])

        eq({4, 0}, exec_lua [[
          vim.lsp.diagnostic.enable(diagnostic_bufnr, 1)
          vim.lsp.diagnostic.disable(diagnostic_bufnr, 2)

          return {
            count_of_extmarks_for_client(diagnostic_bufnr, 1),
            count_of_extmarks_for_client(diagnostic_bufnr, 2),
          }
        ]])
      end)

      describe('reset', function()
        it('diagnostic count is 0 and displayed diagnostics are 0 after call', function()
          -- 1 Error (1)
          -- 1 Warning (2)
          -- 1 Warning (2) + 1 Warning (1)
          -- 2 highlights and 2 underlines (since error)
          -- 1 highlight + 1 underline
          local all_highlights = {1, 1, 2, 4, 2}
          eq(all_highlights, exec_lua [[
            local server_1_diags = {
              make_error("Error 1", 1, 1, 1, 5),
              make_warning("Warning on Server 1", 2, 1, 2, 5),
            }
            local server_2_diags = {
              make_warning("Warning 1", 2, 1, 2, 5),
            }

            vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_1_diags }, {client_id=1})
            vim.lsp.diagnostic.on_publish_diagnostics(nil, { uri = fake_uri, diagnostics = server_2_diags }, {client_id=2})
            return {
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
              count_of_extmarks_for_client(diagnostic_bufnr, 1),
              count_of_extmarks_for_client(diagnostic_bufnr, 2),
            }
          ]])

          -- Reset diagnostics from server 1
          exec_lua([[ vim.lsp.diagnostic.reset(1, { [ diagnostic_bufnr ] = { [ 1 ] = true ; [ 2 ] = true } } )]])

          -- Make sure we have the right diagnostic count
          eq({0, 1, 1, 0, 2} , exec_lua [[
            local diagnostic_count = {}
            vim.wait(100, function () diagnostic_count = {
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
              count_of_extmarks_for_client(diagnostic_bufnr, 1),
              count_of_extmarks_for_client(diagnostic_bufnr, 2),
            } end )
            return diagnostic_count
          ]])

          -- Reset diagnostics from server 2
          exec_lua([[ vim.lsp.diagnostic.reset(2, { [ diagnostic_bufnr ] = { [ 1 ] = true ; [ 2 ] = true } } )]])

          -- Make sure we have the right diagnostic count
          eq({0, 0, 0, 0, 0}, exec_lua [[
            local diagnostic_count = {}
            vim.wait(100, function () diagnostic_count = {
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", 2),
              vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Warning", nil),
              count_of_extmarks_for_client(diagnostic_bufnr, 1),
              count_of_extmarks_for_client(diagnostic_bufnr, 2),
            } end )
            return diagnostic_count
          ]])

          end)
        end)

      describe('get_next_diagnostic_pos', function()
        it('can find the next pos with only one client', function()
          eq({1, 1}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            return vim.lsp.diagnostic.get_next_pos()
          ]])
        end)

        it('can find next pos with two errors', function()
          eq({4, 4}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_next_pos { client_id = 1 }
          ]])
        end)

        it('can cycle when position is past error', function()
          eq({1, 1}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_next_pos { client_id = 1 }
          ]])
        end)

        it('will not cycle when wrap is off', function()
          eq(false, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_next_pos { client_id = 1, wrap = false }
          ]])
        end)

        it('can cycle even from the last line', function()
          eq({4, 4}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(0), 1})
            return vim.lsp.diagnostic.get_prev_pos { client_id =  1 }
          ]])
        end)
      end)

      describe('get_prev_diagnostic_pos', function()
        it('can find the prev pos with only one client', function()
          eq({1, 1}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_prev_pos()
          ]])
        end)

        it('can find prev pos with two errors', function()
          eq({1, 1}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #1', 1, 1, 1, 1),
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_prev_pos { client_id = 1 }
          ]])
        end)

        it('can cycle when position is past error', function()
          eq({4, 4}, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_prev_pos { client_id = 1 }
          ]])
        end)

        it('respects wrap parameter', function()
          eq(false, exec_lua [[
            vim.lsp.diagnostic.save(
              {
                make_error('Diagnostic #2', 4, 4, 4, 4),
              }, diagnostic_bufnr, 1
            )
            vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
            vim.api.nvim_win_set_cursor(0, {3, 1})
            return vim.lsp.diagnostic.get_prev_pos { client_id = 1, wrap = false}
          ]])
        end)
      end)
    end)

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
        }, {client_id=1})

        return {
          vim.diagnostic.get(diagnostic_bufnr, {lnum=1})[1],
          vim.lsp.diagnostic.get_line_diagnostics(diagnostic_bufnr, 1)[1],
        }
      ]]
      eq({code = 42, tags = {"foo", "bar"}, data = "Hello world"}, result[1].user_data.lsp)
      eq(42, result[2].code)
      eq({"foo", "bar"}, result[2].tags)
      eq("Hello world", result[2].data)
    end)
  end)

  describe("vim.lsp.diagnostic.get_line_diagnostics", function()
    it('should return an empty table when no diagnostics are present', function()
      eq({}, exec_lua [[return vim.lsp.diagnostic.get_line_diagnostics(diagnostic_bufnr, 1)]])
    end)

    it('should return all diagnostics when no severity is supplied', function()
      eq(2, exec_lua [[
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = fake_uri,
          diagnostics = {
            make_error("Error 1", 1, 1, 1, 5),
            make_warning("Warning on Server 1", 1, 1, 2, 5),
            make_error("Error On Other Line", 2, 1, 1, 5),
          }
        }, {client_id=1})

        return #vim.lsp.diagnostic.get_line_diagnostics(diagnostic_bufnr, 1)
      ]])
    end)

    it('should return only requested diagnostics when severity_limit is supplied', function()
      eq(2, exec_lua [[
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
          uri = fake_uri,
          diagnostics = {
            make_error("Error 1", 1, 1, 1, 5),
            make_warning("Warning on Server 1", 1, 1, 2, 5),
            make_information("Ignored information", 1, 1, 2, 5),
            make_error("Error On Other Line", 2, 1, 1, 5),
          }
        }, {client_id=1})

        return #vim.lsp.diagnostic.get_line_diagnostics(diagnostic_bufnr, 1, { severity_limit = "Warning" })
      ]])
    end)
  end)

  describe("vim.lsp.diagnostic.on_publish_diagnostics", function()
    it('can use functions for config values', function()
      exec_lua [[
        vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = function() return true end,
        })(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(2, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])

      -- Now, don't enable virtual text.
      -- We should have one less extmark displayed.
      exec_lua [[
        vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          virtual_text = function() return false end,
        })(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(1, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
    end)

    it('can perform updates after insert_leave', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          update_in_insert = false,
        })(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(0, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(2, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
    end)

    it('does not perform updates when not needed', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          update_in_insert = false,
          virtual_text = true,
        })

        -- Count how many times we call display.
        SetVirtualTextOriginal = vim.diagnostic._set_virtual_text

        DisplayCount = 0
        vim.diagnostic._set_virtual_text = function(...)
          DisplayCount = DisplayCount + 1
          return SetVirtualTextOriginal(...)
        end

        PublishDiagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(0, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
      eq(0, exec_lua [[return DisplayCount]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(2, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
      eq(1, exec_lua [[return DisplayCount]])

      -- Go in and out of insert mode one more time.
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      -- Should not have set the virtual text again.
      eq(1, exec_lua [[return DisplayCount]])
    end)

    it('never sets virtual text, in combination with insert leave', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          update_in_insert = false,
          virtual_text = false,
        })

        -- Count how many times we call display.
        SetVirtualTextOriginal = vim.lsp.diagnostic.set_virtual_text

        DisplayCount = 0
        vim.lsp.diagnostic.set_virtual_text = function(...)
          DisplayCount = DisplayCount + 1
          return SetVirtualTextOriginal(...)
        end

        PublishDiagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(0, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
      eq(0, exec_lua [[return DisplayCount]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(1, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
      eq(0, exec_lua [[return DisplayCount]])

      -- Go in and out of insert mode one more time.
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      -- Should not have set the virtual text still.
      eq(0, exec_lua [[return DisplayCount]])
    end)

    it('can perform updates while in insert mode, if desired', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          update_in_insert = true,
        })(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Delayed Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=1}
        )
      ]]

      -- Diagnostics are displayed, because the user wanted them that way!
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(2, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return vim.lsp.diagnostic.get_count(diagnostic_bufnr, "Error", 1)]])
      eq(2, exec_lua [[return count_of_extmarks_for_client(diagnostic_bufnr, 1)]])
    end)

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
          }, {client_id=1}
        )

        return vim.api.nvim_buf_get_extmarks(
          diagnostic_bufnr,
          vim.lsp.diagnostic.get_namespace(1),
          0,
          -1,
          { details = true }
        )
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
          }, {client_id=1}
        )

        return vim.api.nvim_buf_get_extmarks(
          diagnostic_bufnr,
          vim.lsp.diagnostic.get_namespace(1),
          0,
          -1,
          { details = true }
        )
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
            }, {client_id=1}
          )

          return count_of_extmarks_for_client(diagnostic_bufnr, 1)
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
        local client_id = vim.lsp.start_client {
          cmd_env = {
            NVIM_LUA_NOTRACK = "1";
          };
          cmd = {
            vim.v.progpath, '-es', '-u', 'NONE', '--headless'
          };
          offset_encoding = "utf-16";
        }

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
  end)

  describe('lsp.util.show_line_diagnostics', function()
    it('creates floating window and returns popup bufnr and winnr if current line contains diagnostics', function()
      -- Two lines:
      --    Diagnostic:
      --    1. <msg>
      eq(2, exec_lua [[
        local buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
          "testing";
          "123";
        })
        local diagnostics = {
          {
            range = {
              start = { line = 0; character = 1; };
              ["end"] = { line = 0; character = 3; };
            };
            severity = vim.lsp.protocol.DiagnosticSeverity.Error;
            message = "Syntax error";
          },
        }
        vim.api.nvim_win_set_buf(0, buffer)
        vim.lsp.diagnostic.save(diagnostics, buffer, 1)
        local popup_bufnr, winnr = vim.lsp.diagnostic.show_line_diagnostics()
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('creates floating window and returns popup bufnr and winnr without header, if requested', function()
      -- One line (since no header):
      --    1. <msg>
      eq(1, exec_lua [[
        local buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
          "testing";
          "123";
        })
        local diagnostics = {
          {
            range = {
              start = { line = 0; character = 1; };
              ["end"] = { line = 0; character = 3; };
            };
            severity = vim.lsp.protocol.DiagnosticSeverity.Error;
            message = "Syntax error";
          },
        }
        vim.api.nvim_win_set_buf(0, buffer)
        vim.lsp.diagnostic.save(diagnostics, buffer, 1)
        local popup_bufnr, winnr = vim.lsp.diagnostic.show_line_diagnostics { show_header = false }
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)
  end)

  describe('set_signs', function()
    -- TODO(tjdevries): Find out why signs are not displayed when set from Lua...??
    pending('sets signs by default', function()
      exec_lua [[
        PublishDiagnostics = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
          update_in_insert = true,
          signs = true,
        })

        local diagnostics = {
          make_error('Delayed Diagnostic', 1, 1, 1, 2),
          make_error('Delayed Diagnostic', 3, 3, 3, 3),
        }

        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = fake_uri,
            diagnostics = diagnostics
          }, {client_id=1}
        )

        vim.lsp.diagnostic.set_signs(diagnostics, diagnostic_bufnr, 1)
        -- return vim.fn.sign_getplaced()
      ]]

      nvim("input", "o")
      nvim("input", "<esc>")

      -- TODO(tjdevries): Find a way to get the signs to display in the test...
      eq(nil, exec_lua [[
        return im.fn.sign_getplaced()[1].signs
      ]])
    end)
  end)

  describe('set_loclist()', function()
    it('sets diagnostics in lnum order', function()
      local loc_list = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Farther Diagnostic', 4, 4, 4, 4),
              make_error('Lower Diagnostic', 1, 1, 1, 1),
            }
          }, {client_id=1}
        )

        vim.lsp.diagnostic.set_loclist()

        return vim.fn.getloclist(0)
      ]]

      assert(loc_list[1].lnum < loc_list[2].lnum)
    end)

    it('sets diagnostics in lnum order, regardless of client', function()
      local loc_list = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_error('Lower Diagnostic', 1, 1, 1, 1),
            }
          }, {client_id=1}
        )

        vim.lsp.diagnostic.on_publish_diagnostics(nil, {
            uri = fake_uri,
            diagnostics = {
              make_warning('Farther Diagnostic', 4, 4, 4, 4),
            }
          }, {client_id=2}
        )

        vim.lsp.diagnostic.set_loclist()

        return vim.fn.getloclist(0)
      ]]

      assert(loc_list[1].lnum < loc_list[2].lnum)
    end)
  end)
end)
