local helpers = require('test.functional.helpers')(after_each)

local NIL = helpers.NIL
local command = helpers.command
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local nvim = helpers.nvim

describe('vim.diagnostic', function()
  before_each(function()
    clear()

    exec_lua [[
      require('vim.diagnostic')

      function make_diagnostic(msg, x1, y1, x2, y2, severity, source)
        return {
          lnum = x1,
          col = y1,
          end_lnum = x2,
          end_col = y2,
          message = msg,
          severity = severity,
          source = source,
        }
      end

      function make_error(msg, x1, y1, x2, y2, source)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.ERROR, source)
      end

      function make_warning(msg, x1, y1, x2, y2, source)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.WARN, source)
      end

      function make_info(msg, x1, y1, x2, y2, source)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.INFO, source)
      end

      function make_hint(msg, x1, y1, x2, y2, source)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.HINT, source)
      end

      function count_diagnostics(bufnr, severity, namespace)
        return #vim.diagnostic.get(bufnr, {severity = severity, namespace = namespace})
      end

      function count_extmarks(bufnr, namespace)
        return #vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
      end
    ]]

    exec_lua([[
      diagnostic_ns = vim.api.nvim_create_namespace("diagnostic_spec")
      other_ns = vim.api.nvim_create_namespace("other_namespace")
      diagnostic_bufnr = vim.api.nvim_create_buf(true, false)
      local lines = {"1st line of text", "2nd line of text", "wow", "cool", "more", "lines"}
      vim.fn.bufload(diagnostic_bufnr)
      vim.api.nvim_buf_set_lines(diagnostic_bufnr, 0, 1, false, lines)
      return diagnostic_bufnr
    ]])
  end)

  after_each(function()
    clear()
  end)

  it('creates highlight groups', function()
    command('runtime plugin/diagnostic.vim')
    eq({
      'DiagnosticError',
      'DiagnosticFloatingError',
      'DiagnosticFloatingHint',
      'DiagnosticFloatingInfo',
      'DiagnosticFloatingWarn',
      'DiagnosticHint',
      'DiagnosticInfo',
      'DiagnosticSignError',
      'DiagnosticSignHint',
      'DiagnosticSignInfo',
      'DiagnosticSignWarn',
      'DiagnosticUnderlineError',
      'DiagnosticUnderlineHint',
      'DiagnosticUnderlineInfo',
      'DiagnosticUnderlineWarn',
      'DiagnosticVirtualTextError',
      'DiagnosticVirtualTextHint',
      'DiagnosticVirtualTextInfo',
      'DiagnosticVirtualTextWarn',
      'DiagnosticWarn',
    }, exec_lua([[return vim.fn.getcompletion('Diagnostic', 'highlight')]]))
  end)

  it('retrieves diagnostics from all buffers and namespaces', function()
    local result = exec_lua [[
      vim.diagnostic.set(diagnostic_ns, 1, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      vim.diagnostic.set(other_ns, 2, {
        make_error('Diagnostic #3', 3, 1, 3, 1),
      })
      return vim.diagnostic.get()
    ]]
    eq(3, #result)
    eq(2, exec_lua([[return #vim.tbl_filter(function(d) return d.bufnr == 1 end, ...)]], result))
    eq('Diagnostic #1', result[1].message)
  end)

  it('saves and count a single error', function()
    eq(1, exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
      })
      return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)
    ]])
  end)

  it('saves and count multiple errors', function()
    eq(2, exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)
    ]])
  end)

  it('saves and count from multiple namespaces', function()
    eq({1, 1, 2}, exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic From Server 1', 1, 1, 1, 1),
      })
      vim.diagnostic.set(other_ns, diagnostic_bufnr, {
        make_error('Diagnostic From Server 2', 1, 1, 1, 1),
      })
      return {
        -- First namespace
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
        -- Second namespace
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, other_ns),
        -- All namespaces
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR),
      }
    ]])
  end)

  it('saves and count from multiple namespaces with respect to severity', function()
    eq({3, 0, 3}, exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
        make_error('Diagnostic From Server 1:2', 2, 2, 2, 2),
        make_error('Diagnostic From Server 1:3', 2, 3, 3, 2),
      })
      vim.diagnostic.set(other_ns, diagnostic_bufnr, {
        make_warning('Warning From Server 2', 3, 3, 3, 3),
      })
      return {
        -- Namespace 1
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
        -- Namespace 2
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, other_ns),
        -- All namespaces
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR),
      }
    ]])
  end)

  it('handles one namespace clearing highlights while the other still has highlights', function()
    -- 1 Error (1)
    -- 1 Warning (2)
    -- 1 Warning (2) + 1 Warning (1)
    -- 2 highlights and 2 underlines (since error)
    -- 1 highlight + 1 underline
    local all_highlights = {1, 1, 2, 4, 2}
    eq(all_highlights, exec_lua [[
      local ns_1_diags = {
        make_error("Error 1", 1, 1, 1, 5),
        make_warning("Warning on Server 1", 2, 1, 2, 5),
      }
      local ns_2_diags = {
        make_warning("Warning 1", 2, 1, 2, 5),
      }

      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
      vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)

      return {
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
        count_extmarks(diagnostic_bufnr, diagnostic_ns),
        count_extmarks(diagnostic_bufnr, other_ns),
      }
    ]])

    -- Clear diagnostics from namespace 1, and make sure we have the right amount of stuff for namespace 2
    eq({1, 1, 2, 0, 2}, exec_lua [[
      vim.diagnostic.disable(diagnostic_bufnr, diagnostic_ns)
      return {
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
        count_extmarks(diagnostic_bufnr, diagnostic_ns),
        count_extmarks(diagnostic_bufnr, other_ns),
      }
    ]])

    -- Show diagnostics from namespace 1 again
    eq(all_highlights, exec_lua([[
      vim.diagnostic.enable(diagnostic_bufnr, diagnostic_ns)
      return {
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
        count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
        count_extmarks(diagnostic_bufnr, diagnostic_ns),
        count_extmarks(diagnostic_bufnr, other_ns),
      }
    ]]))
  end)

  it('does not display diagnostics when disabled', function()
    eq({0, 2}, exec_lua [[
      local ns_1_diags = {
        make_error("Error 1", 1, 1, 1, 5),
        make_warning("Warning on Server 1", 2, 1, 2, 5),
      }
      local ns_2_diags = {
        make_warning("Warning 1", 2, 1, 2, 5),
      }

      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
      vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)

      vim.diagnostic.disable(diagnostic_bufnr, diagnostic_ns)

      return {
        count_extmarks(diagnostic_bufnr, diagnostic_ns),
        count_extmarks(diagnostic_bufnr, other_ns),
      }
    ]])

    eq({4, 0}, exec_lua [[
      vim.diagnostic.enable(diagnostic_bufnr, diagnostic_ns)
      vim.diagnostic.disable(diagnostic_bufnr, other_ns)

      return {
        count_extmarks(diagnostic_bufnr, diagnostic_ns),
        count_extmarks(diagnostic_bufnr, other_ns),
      }
    ]])
  end)

  describe('reset()', function()
    it('diagnostic count is 0 and displayed diagnostics are 0 after call', function()
      -- 1 Error (1)
      -- 1 Warning (2)
      -- 1 Warning (2) + 1 Warning (1)
      -- 2 highlights and 2 underlines (since error)
      -- 1 highlight + 1 underline
      local all_highlights = {1, 1, 2, 4, 2}
      eq(all_highlights, exec_lua [[
        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)

        return {
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
          count_extmarks(diagnostic_bufnr, diagnostic_ns),
          count_extmarks(diagnostic_bufnr, other_ns),
        }
      ]])

      -- Reset diagnostics from namespace 1
      exec_lua([[ vim.diagnostic.reset(diagnostic_ns) ]])

      -- Make sure we have the right diagnostic count
      eq({0, 1, 1, 0, 2} , exec_lua [[
        local diagnostic_count = {}
        vim.wait(100, function () diagnostic_count = {
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
          count_extmarks(diagnostic_bufnr, diagnostic_ns),
          count_extmarks(diagnostic_bufnr, other_ns),
        } end )
        return diagnostic_count
      ]])

      -- Reset diagnostics from namespace 2
      exec_lua([[ vim.diagnostic.reset(other_ns) ]])

      -- Make sure we have the right diagnostic count
      eq({0, 0, 0, 0, 0}, exec_lua [[
        local diagnostic_count = {}
        vim.wait(100, function () diagnostic_count = {
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN, other_ns),
          count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.WARN),
          count_extmarks(diagnostic_bufnr, diagnostic_ns),
          count_extmarks(diagnostic_bufnr, other_ns),
        } end )
        return diagnostic_count
      ]])

    end)
  end)

  describe('get_next_pos()', function()
    it('can find the next pos with only one namespace', function()
      eq({1, 1}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        return vim.diagnostic.get_next_pos()
      ]])
    end)

    it('can find next pos with two errors', function()
      eq({4, 4}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
          make_error('Diagnostic #2', 4, 4, 4, 4),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_next_pos { namespace = diagnostic_ns }
      ]])
    end)

    it('can cycle when position is past error', function()
      eq({1, 1}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_next_pos { namespace = diagnostic_ns }
      ]])
    end)

    it('will not cycle when wrap is off', function()
      eq(false, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_next_pos { namespace = diagnostic_ns, wrap = false }
      ]])
    end)

    it('can cycle even from the last line', function()
      eq({4, 4}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #2', 4, 4, 4, 4),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(0), 1})
        return vim.diagnostic.get_prev_pos { namespace = diagnostic_ns }
      ]])
    end)
  end)

  describe('get_prev_pos()', function()
    it('can find the prev pos with only one namespace', function()
      eq({1, 1}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_prev_pos()
      ]])
    end)

    it('can find prev pos with two errors', function()
      eq({1, 1}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
          make_error('Diagnostic #2', 4, 4, 4, 4),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_prev_pos { namespace = diagnostic_ns }
      ]])
    end)

    it('can cycle when position is past error', function()
      eq({4, 4}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #2', 4, 4, 4, 4),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_prev_pos { namespace = diagnostic_ns }
      ]])
    end)

    it('respects wrap parameter', function()
      eq(false, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #2', 4, 4, 4, 4),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {3, 1})
        return vim.diagnostic.get_prev_pos { namespace = diagnostic_ns, wrap = false}
      ]])
    end)
  end)

  describe('get()', function()
    it('returns an empty table when no diagnostics are present', function()
      eq({}, exec_lua [[return vim.diagnostic.get(diagnostic_bufnr, {namespace=diagnostic_ns})]])
    end)

    it('returns all diagnostics when no severity is supplied', function()
      eq(2, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 1, 1, 2, 5),
        })

        return #vim.diagnostic.get(diagnostic_bufnr)
      ]])
    end)

    it('returns only requested diagnostics when severity is supplied', function()
      eq({2, 3, 2}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 1, 1, 2, 5),
          make_info("Ignored information", 1, 1, 2, 5),
          make_hint("Here's a hint", 1, 1, 2, 5),
        })

        return {
          #vim.diagnostic.get(diagnostic_bufnr, { severity = {min=vim.diagnostic.severity.WARN} }),
          #vim.diagnostic.get(diagnostic_bufnr, { severity = {max=vim.diagnostic.severity.WARN} }),
          #vim.diagnostic.get(diagnostic_bufnr, {
            severity = {
              min=vim.diagnostic.severity.INFO,
              max=vim.diagnostic.severity.WARN,
            }
          }),
        }
      ]])
    end)

    it('allows filtering by line', function()
      eq(1, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 1, 1, 2, 5),
          make_info("Ignored information", 1, 1, 2, 5),
          make_error("Error On Other Line", 2, 1, 1, 5),
        })

        return #vim.diagnostic.get(diagnostic_bufnr, {lnum = 2})
      ]])
    end)
  end)

  describe('config()', function()
    it('can use functions for config values', function()
      exec_lua [[
        vim.diagnostic.config({
          virtual_text = function() return true end,
        }, diagnostic_ns)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Delayed Diagnostic', 4, 4, 4, 4),
        })
      ]]

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(2, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])

      -- Now, don't enable virtual text.
      -- We should have one less extmark displayed.
      exec_lua [[
        vim.diagnostic.config({
          virtual_text = function() return false end,
        }, diagnostic_ns)
      ]]

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(1, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
    end)

    it('allows filtering by severity', function()
      local get_extmark_count_with_severity = function(min_severity)
        return exec_lua([[
          vim.diagnostic.config({
            underline = false,
            virtual_text = {
              severity = {min=...},
            },
          })

          vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
            make_warning('Delayed Diagnostic', 4, 4, 4, 4),
          })

          return count_extmarks(diagnostic_bufnr, diagnostic_ns)
        ]], min_severity)
      end

      -- No messages with Error or higher
      eq(0, get_extmark_count_with_severity("ERROR"))

      -- But now we don't filter it
      eq(1, get_extmark_count_with_severity("WARN"))
      eq(1, get_extmark_count_with_severity("HINT"))
    end)

    it('allows sorting by severity', function()
      exec_lua [[
        vim.diagnostic.config({
          underline = false,
          signs = true,
          virtual_text = true,
        })

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning('Warning', 4, 4, 4, 4),
          make_error('Error', 4, 4, 4, 4),
          make_info('Info', 4, 4, 4, 4),
        })

        function get_virt_text_and_signs(severity_sort)
          vim.diagnostic.config({
            severity_sort = severity_sort,
          })

          local virt_text = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})[1][4].virt_text

          local virt_texts = {}
          for i = 2, #virt_text do
            table.insert(virt_texts, (string.gsub(virt_text[i][2], "DiagnosticVirtualText", "")))
          end

          local signs = {}
          for _, v in ipairs(vim.fn.sign_getplaced(diagnostic_bufnr, {group = "*"})[1].signs) do
            table.insert(signs, (string.gsub(v.name, "DiagnosticSign", "")))
          end

          return {virt_texts, signs}
        end
      ]]

      local result = exec_lua [[return get_virt_text_and_signs(false)]]

      -- Virt texts are defined lowest priority to highest, signs from
      -- highest to lowest
      eq({'Warn', 'Error', 'Info'}, result[1])
      eq({'Info', 'Error', 'Warn'}, result[2])

      result = exec_lua [[return get_virt_text_and_signs(true)]]
      eq({'Info', 'Warn', 'Error'}, result[1])
      eq({'Error', 'Warn', 'Info'}, result[2])

      result = exec_lua [[return get_virt_text_and_signs({ reverse = true })]]
      eq({'Error', 'Warn', 'Info'}, result[1])
      eq({'Info', 'Warn', 'Error'}, result[2])
    end)

    it('can show diagnostic sources in virtual text', function()
      local result = exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0, 'source x'),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = '',
            source = 'always',
          }
        })

        local extmarks = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})
        local virt_text = extmarks[1][4].virt_text[2][1]
        return virt_text
      ]]
      eq(' source x: Some error', result)

      result = exec_lua [[
        vim.diagnostic.config({
          underline = false,
          virtual_text = {
            prefix = '',
            source = 'if_many',
          }
        }, diagnostic_ns)

        local extmarks = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})
        local virt_text = extmarks[1][4].virt_text[2][1]
        return virt_text
      ]]
      eq(' Some error', result)

      result = exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0, 'source x'),
          make_error('Another error', 1, 1, 1, 1, 'source y'),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = '',
            source = 'if_many',
          }
        })

        local extmarks = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})
        local virt_text = {extmarks[1][4].virt_text[2][1], extmarks[2][4].virt_text[2][1]}
        return virt_text
      ]]
      eq(' source x: Some error', result[1])
      eq(' source y: Another error', result[2])
    end)

    it('supports a format function for diagnostic messages', function()
      local result = exec_lua [[
        vim.diagnostic.config({
          underline = false,
          virtual_text = {
            prefix = '',
            format = function(diagnostic)
              if diagnostic.severity == vim.diagnostic.severity.ERROR then
                return string.format("🔥 %s", diagnostic.message)
              end
              return string.format("👀 %s", diagnostic.message)
            end,
          }
        })

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning('Warning', 0, 0, 0, 0),
          make_error('Error', 1, 0, 1, 0),
        })

        local extmarks = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})
        return {extmarks[1][4].virt_text, extmarks[2][4].virt_text}
      ]]
      eq(" 👀 Warning", result[1][2][1])
      eq(" 🔥 Error", result[2][2][1])
    end)

    it('includes source for formatted diagnostics', function()
      local result = exec_lua [[
        vim.diagnostic.config({
          underline = false,
          virtual_text = {
            prefix = '',
            source = 'always',
            format = function(diagnostic)
              if diagnostic.severity == vim.diagnostic.severity.ERROR then
                return string.format("🔥 %s", diagnostic.message)
              end
              return string.format("👀 %s", diagnostic.message)
            end,
          }
        })

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning('Warning', 0, 0, 0, 0, 'some_linter'),
          make_error('Error', 1, 0, 1, 0, 'another_linter'),
        })

        local extmarks = vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, diagnostic_ns, 0, -1, {details = true})
        return {extmarks[1][4].virt_text, extmarks[2][4].virt_text}
      ]]
      eq(" some_linter: 👀 Warning", result[1][2][1])
      eq(" another_linter: 🔥 Error", result[2][2][1])
    end)
  end)

  describe('set()', function()
    it('can perform updates after insert_leave', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        vim.diagnostic.config({
          update_in_insert = false,
        })
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Delayed Diagnostic', 4, 4, 4, 4),
        })
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(0, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(2, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
    end)

    it('does not perform updates when not needed', function()
      exec_lua [[vim.api.nvim_set_current_buf(diagnostic_bufnr)]]
      nvim("input", "o")
      eq({mode='i', blocking=false}, nvim("get_mode"))

      -- Save the diagnostics
      exec_lua [[
        vim.diagnostic.config({
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

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Delayed Diagnostic', 4, 4, 4, 4),
        })
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(0, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
      eq(0, exec_lua [[return DisplayCount]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(2, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
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
        vim.diagnostic.config({
          update_in_insert = false,
          virtual_text = false,
        })

        -- Count how many times we call display.
        SetVirtualTextOriginal = vim.diagnostic._set_virtual_text

        DisplayCount = 0
        vim.diagnostic._set_virtual_text = function(...)
          DisplayCount = DisplayCount + 1
          return SetVirtualTextOriginal(...)
        end

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Delayed Diagnostic', 4, 4, 4, 4),
        })
      ]]

      -- No diagnostics displayed yet.
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(0, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
      eq(0, exec_lua [[return DisplayCount]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(1, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
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
        vim.diagnostic.config({
          update_in_insert = true,
        })

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Delayed Diagnostic', 4, 4, 4, 4),
        })
      ]]

      -- Diagnostics are displayed, because the user wanted them that way!
      eq({mode='i', blocking=false}, nvim("get_mode"))
      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(2, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])

      nvim("input", "<esc>")
      eq({mode='n', blocking=false}, nvim("get_mode"))

      eq(1, exec_lua [[return count_diagnostics(diagnostic_bufnr, vim.diagnostic.severity.ERROR, diagnostic_ns)]])
      eq(2, exec_lua [[return count_extmarks(diagnostic_bufnr, diagnostic_ns)]])
    end)

    it('can set diagnostics without displaying them', function()
      eq(0, exec_lua [[
        vim.diagnostic.disable(diagnostic_bufnr, diagnostic_ns)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
        })
        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])

      eq(2, exec_lua [[
        vim.diagnostic.enable(diagnostic_bufnr, diagnostic_ns)
        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])
    end)

    it('can set display options', function()
      eq(0, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
        }, { virtual_text = false, underline = false })
        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])

      eq(1, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic From Server 1:1', 1, 1, 1, 1),
        }, { virtual_text = true, underline = false })
        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])
    end)

    it('sets signs', function()
      local result = exec_lua [[
        vim.diagnostic.config({
          signs = true,
        })

        local diagnostics = {
          make_error('Error', 1, 1, 1, 2),
          make_warning('Warning', 3, 3, 3, 3),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)

        return vim.fn.sign_getplaced(diagnostic_bufnr, {group = '*'})[1].signs
      ]]

      eq({2, 'DiagnosticSignError'}, {result[1].lnum, result[1].name})
      eq({4, 'DiagnosticSignWarn'}, {result[2].lnum, result[2].name})
    end)
  end)

  describe('show_line_diagnostics()', function()
    it('creates floating window and returns popup bufnr and winnr if current line contains diagnostics', function()
      -- Two lines:
      --    Diagnostic:
      --    1. <msg>
      eq(2, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics()
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('only reports diagnostics from the current buffer when bufnr is omitted #15710', function()
      eq(2, exec_lua [[
        local other_bufnr = vim.api.nvim_create_buf(true, false)
        local buf_1_diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        local buf_2_diagnostics = {
          make_warning("Some warning", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, buf_1_diagnostics)
        vim.diagnostic.set(other_ns, other_bufnr, buf_2_diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics()
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('allows filtering by namespace', function()
      eq(2, exec_lua [[
        local ns_1_diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        local ns_2_diagnostics = {
          make_warning("Some warning", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diagnostics)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics({namespace = diagnostic_ns})
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('creates floating window and returns popup bufnr and winnr without header, if requested', function()
      -- One line (since no header):
      --    1. <msg>
      eq(1, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics {show_header = false}
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('clamps diagnostic line numbers within the valid range', function()
      eq(1, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 6, 0, 6, 0),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics({show_header = false}, diagnostic_bufnr, 5)
        return #vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      ]])
    end)

    it('can show diagnostic source', function()
      exec_lua [[vim.api.nvim_win_set_buf(0, diagnostic_bufnr)]]

      eq({"1. Syntax error"}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, "source x"),
        }
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics {
          show_header = false,
          source = "if_many",
        }
        local lines = vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. source x: Syntax error"}, exec_lua [[
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics {
          show_header = false,
          source = "always",
        }
        local lines = vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. source x: Syntax error", "2. source y: Another error"}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, "source x"),
          make_error("Another error", 0, 1, 0, 3, "source y"),
        }
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local popup_bufnr, winnr = vim.diagnostic.show_line_diagnostics {
          show_header = false,
          source = "if_many",
        }
        local lines = vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)
  end)

  describe('setloclist()', function()
    it('sets diagnostics in lnum order', function()
      local loc_list = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Farther Diagnostic', 4, 4, 4, 4),
          make_error('Lower Diagnostic', 1, 1, 1, 1),
        })

        vim.diagnostic.setloclist()

        return vim.fn.getloclist(0)
      ]]

      assert(loc_list[1].lnum < loc_list[2].lnum)
    end)

    it('sets diagnostics in lnum order, regardless of namespace', function()
      local loc_list = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Lower Diagnostic', 1, 1, 1, 1),
        })

        vim.diagnostic.set(other_ns, diagnostic_bufnr, {
          make_warning('Farther Diagnostic', 4, 4, 4, 4),
        })

        vim.diagnostic.setloclist()

        return vim.fn.getloclist(0)
      ]]

      assert(loc_list[1].lnum < loc_list[2].lnum)
    end)
  end)

  describe('match()', function()
    it('matches a string', function()
      local msg = "ERROR: george.txt:19:84:Two plus two equals five"
      local diagnostic = {
        severity = exec_lua [[return vim.diagnostic.severity.ERROR]],
        lnum = 18,
        col = 83,
        end_lnum = 18,
        end_col = 83,
        message = "Two plus two equals five",
      }
      eq(diagnostic, exec_lua([[
        return vim.diagnostic.match(..., "^(%w+): [^:]+:(%d+):(%d+):(.+)$", {"severity", "lnum", "col", "message"})
      ]], msg))
    end)

    it('returns nil if the pattern fails to match', function()
      eq(NIL, exec_lua [[
        local msg = "The answer to life, the universe, and everything is"
        return vim.diagnostic.match(msg, "This definitely will not match", {})
      ]])
    end)

    it('respects default values', function()
      local msg = "anna.txt:1:Happy families are all alike"
      local diagnostic = {
        severity = exec_lua [[return vim.diagnostic.severity.INFO]],
        lnum = 0,
        col = 0,
        end_lnum = 0,
        end_col = 0,
        message = "Happy families are all alike",
      }
      eq(diagnostic, exec_lua([[
        return vim.diagnostic.match(..., "^[^:]+:(%d+):(.+)$", {"lnum", "message"}, nil, {severity = vim.diagnostic.severity.INFO})
      ]], msg))
    end)

    it('accepts a severity map', function()
      local msg = "46:FATAL:Et tu, Brute?"
      local diagnostic = {
        severity = exec_lua [[return vim.diagnostic.severity.ERROR]],
        lnum = 45,
        col = 0,
        end_lnum = 45,
        end_col = 0,
        message = "Et tu, Brute?",
      }
      eq(diagnostic, exec_lua([[
        return vim.diagnostic.match(..., "^(%d+):(%w+):(.+)$", {"lnum", "severity", "message"}, {FATAL = vim.diagnostic.severity.ERROR})
      ]], msg))
    end)
  end)

  describe('toqflist() and fromqflist()', function()
    it('works', function()
      local result = exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Error 1', 0, 1, 0, 1),
        make_error('Error 2', 1, 1, 1, 1),
        make_warning('Warning', 2, 2, 2, 2),
      })

      local diagnostics = vim.diagnostic.get(diagnostic_bufnr)
      vim.fn.setqflist(vim.diagnostic.toqflist(diagnostics))
      local list = vim.fn.getqflist()
      local new_diagnostics = vim.diagnostic.fromqflist(list)

      -- Remove namespace since it isn't present in the return value of
      -- fromlist()
      for _, v in ipairs(diagnostics) do
        v.namespace = nil
      end

      return {diagnostics, new_diagnostics}
      ]]
      eq(result[1], result[2])
    end)
  end)
end)
