local helpers = require('test.functional.helpers')(after_each)

local NIL = helpers.NIL
local command = helpers.command
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local nvim = helpers.nvim
local matches = helpers.matches
local pcall_err = helpers.pcall_err

describe('vim.diagnostic', function()
  before_each(function()
    clear()

    exec_lua [[
      require('vim.diagnostic')

      function make_diagnostic(msg, x1, y1, x2, y2, severity, source, code)
        return {
          lnum = x1,
          col = y1,
          end_lnum = x2,
          end_col = y2,
          message = msg,
          severity = severity,
          source = source,
          code = code,
        }
      end

      function make_error(msg, x1, y1, x2, y2, source, code)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.ERROR, source, code)
      end

      function make_warning(msg, x1, y1, x2, y2, source, code)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.WARN, source, code)
      end

      function make_info(msg, x1, y1, x2, y2, source, code)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.INFO, source, code)
      end

      function make_hint(msg, x1, y1, x2, y2, source, code)
        return make_diagnostic(msg, x1, y1, x2, y2, vim.diagnostic.severity.HINT, source, code)
      end

      function count_diagnostics(bufnr, severity, namespace)
        return #vim.diagnostic.get(bufnr, {severity = severity, namespace = namespace})
      end

      function count_extmarks(bufnr, namespace)
        local ns = vim.diagnostic.get_namespace(namespace)
        local extmarks = 0
        if ns.user_data.virt_text_ns then
          extmarks = extmarks + #vim.api.nvim_buf_get_extmarks(bufnr, ns.user_data.virt_text_ns, 0, -1, {})
        end
        if ns.user_data.underline_ns then
          extmarks = extmarks + #vim.api.nvim_buf_get_extmarks(bufnr, ns.user_data.underline_ns, 0, -1, {})
        end
        return extmarks
      end

      function get_virt_text_extmarks(ns)
        local ns = vim.diagnostic.get_namespace(ns)
        local virt_text_ns = ns.user_data.virt_text_ns
        return vim.api.nvim_buf_get_extmarks(diagnostic_bufnr, virt_text_ns, 0, -1, {details = true})
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

  it('creates highlight groups', function()
    command('runtime plugin/diagnostic.vim')
    eq({
      'DiagnosticDeprecated',
      'DiagnosticError',
      'DiagnosticFloatingError',
      'DiagnosticFloatingHint',
      'DiagnosticFloatingInfo',
      'DiagnosticFloatingOk',
      'DiagnosticFloatingWarn',
      'DiagnosticHint',
      'DiagnosticInfo',
      'DiagnosticOk',
      'DiagnosticSignError',
      'DiagnosticSignHint',
      'DiagnosticSignInfo',
      'DiagnosticSignOk',
      'DiagnosticSignWarn',
      'DiagnosticUnderlineError',
      'DiagnosticUnderlineHint',
      'DiagnosticUnderlineInfo',
      'DiagnosticUnderlineOk',
      'DiagnosticUnderlineWarn',
      'DiagnosticUnnecessary',
      'DiagnosticVirtualTextError',
      'DiagnosticVirtualTextHint',
      'DiagnosticVirtualTextInfo',
      'DiagnosticVirtualTextOk',
      'DiagnosticVirtualTextWarn',
      'DiagnosticWarn',
    }, exec_lua([[return vim.fn.getcompletion('Diagnostic', 'highlight')]]))
  end)

  it('retrieves diagnostics from all buffers and namespaces', function()
    local result = exec_lua [[
      local other_bufnr = vim.api.nvim_create_buf(true, false)
      local lines = vim.api.nvim_buf_get_lines(diagnostic_bufnr, 0, -1, true)
      vim.api.nvim_buf_set_lines(other_bufnr, 0, 1, false, lines)

      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      vim.diagnostic.set(other_ns, other_bufnr, {
        make_error('Diagnostic #3', 3, 1, 3, 1),
      })
      return vim.diagnostic.get()
    ]]
    eq(3, #result)
    eq(2, exec_lua([[return #vim.tbl_filter(function(d) return d.bufnr == diagnostic_bufnr end, ...)]], result))
    eq('Diagnostic #1', result[1].message)
  end)

  it('removes diagnostics from the cache when a buffer is removed', function()
    eq(2, exec_lua [[
      vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
      local other_bufnr = vim.fn.bufadd('test | test')
      local lines = vim.api.nvim_buf_get_lines(diagnostic_bufnr, 0, -1, true)
      vim.api.nvim_buf_set_lines(other_bufnr, 0, 1, false, lines)
      vim.cmd('bunload! ' .. other_bufnr)

      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      vim.diagnostic.set(diagnostic_ns, other_bufnr, {
        make_error('Diagnostic #3', 3, 1, 3, 1),
      })
      vim.api.nvim_set_current_buf(other_bufnr)
      vim.opt_local.buflisted = true
      vim.cmd('bwipeout!')
      return #vim.diagnostic.get()
    ]])
    eq(2, exec_lua [[
      vim.api.nvim_set_current_buf(diagnostic_bufnr)
      vim.opt_local.buflisted = false
      return #vim.diagnostic.get()
    ]])
    eq(0, exec_lua [[
      vim.cmd('bwipeout!')
      return #vim.diagnostic.get()
    ]])
  end)

  it('removes diagnostic from stale cache on reset', function()
    local diagnostics = exec_lua [[
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      local other_bufnr = vim.fn.bufadd('test | test')
      vim.cmd('noautocmd bwipeout! ' .. diagnostic_bufnr)
      return vim.diagnostic.get(diagnostic_bufnr)
    ]]
    eq(2, #diagnostics)
    diagnostics = exec_lua [[
      vim.diagnostic.reset()
      return vim.diagnostic.get()
    ]]
    eq(0, #diagnostics)
  end)

  it('resolves buffer number 0 to the current buffer', function()
    eq(2, exec_lua [[
      vim.api.nvim_set_current_buf(diagnostic_bufnr)
      vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 1, 1, 1, 1),
        make_error('Diagnostic #2', 2, 1, 2, 1),
      })
      return #vim.diagnostic.get(0)
    ]])
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
        make_warning("Warning on Server 1", 2, 1, 2, 3),
      }
      local ns_2_diags = {
        make_warning("Warning 1", 2, 1, 2, 3),
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
        make_warning("Warning on Server 1", 2, 1, 2, 3),
      }
      local ns_2_diags = {
        make_warning("Warning 1", 2, 1, 2, 3),
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

  describe('show() and hide()', function()
    it('works', function()
      local result = exec_lua [[
        local other_bufnr = vim.api.nvim_create_buf(true, false)

        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        local result = {}

        vim.diagnostic.config({ underline = false, virtual_text = true })

        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }
        local other_buffer_diags = {
          make_info("This is interesting", 0, 0, 0, 0)
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)
        vim.diagnostic.set(diagnostic_ns, other_bufnr, other_buffer_diags)

        -- All buffers and namespaces
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Hide one namespace
        vim.diagnostic.hide(diagnostic_ns)
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Show one namespace
        vim.diagnostic.show(diagnostic_ns)
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Hide one buffer
        vim.diagnostic.hide(nil, other_bufnr)
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Hide everything
        vim.diagnostic.hide()
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Show one buffer
        vim.diagnostic.show(nil, diagnostic_bufnr)
        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        return result
      ]]

      eq(4, result[1])
      eq(1, result[2])
      eq(4, result[3])
      eq(3, result[4])
      eq(0, result[5])
      eq(3, result[6])
    end)

    it("doesn't error after bwipeout on buffer", function()
      exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {{ lnum = 0, end_lnum = 0, col = 0, end_col = 0 }})
        vim.cmd("bwipeout! " .. diagnostic_bufnr)

        vim.diagnostic.show(diagnostic_ns)
        vim.diagnostic.hide(diagnostic_ns)
      ]]
    end)
  end)

  describe('enable() and disable()', function()
    it('works without arguments', function()
      local result = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        local result = {}

        vim.diagnostic.config({ underline = false, virtual_text = true })

        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        vim.diagnostic.disable()

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        -- Create a new buffer
        local other_bufnr = vim.api.nvim_create_buf(true, false)
        local other_buffer_diags = {
          make_info("This is interesting", 0, 0, 0, 0)
        }

        vim.diagnostic.set(diagnostic_ns, other_bufnr, other_buffer_diags)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.enable()

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        return result
      ]]

      eq(3, result[1])
      eq(0, result[2])
      eq(0, result[3])
      eq(4, result[4])
    end)

    it('works with only a buffer argument', function()
      local result = exec_lua [[
        local other_bufnr = vim.api.nvim_create_buf(true, false)

        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        local result = {}

        vim.diagnostic.config({ underline = false, virtual_text = true })

        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }
        local other_buffer_diags = {
          make_info("This is interesting", 0, 0, 0, 0)
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)
        vim.diagnostic.set(diagnostic_ns, other_bufnr, other_buffer_diags)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.disable(diagnostic_bufnr)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.enable(diagnostic_bufnr)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.disable(other_bufnr)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        return result
      ]]

      eq(4, result[1])
      eq(1, result[2])
      eq(4, result[3])
      eq(3, result[4])
    end)

    it('works with only a namespace argument', function()
      local result = exec_lua [[
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        local result = {}

        vim.diagnostic.config({ underline = false, virtual_text = true })

        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        vim.diagnostic.disable(nil, diagnostic_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        vim.diagnostic.enable(nil, diagnostic_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        vim.diagnostic.disable(nil, other_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns))

        return result
      ]]

      eq(3, result[1])
      eq(1, result[2])
      eq(3, result[3])
      eq(2, result[4])
    end)

    it('works with both a buffer and a namespace argument', function()
      local result = exec_lua [[
        local other_bufnr = vim.api.nvim_create_buf(true, false)

        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)

        local result = {}

        vim.diagnostic.config({ underline = false, virtual_text = true })

        local ns_1_diags = {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 2, 1, 2, 5),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 5),
        }
        local other_buffer_diags = {
          make_info("This is interesting", 0, 0, 0, 0)
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, ns_1_diags)
        vim.diagnostic.set(other_ns, diagnostic_bufnr, ns_2_diags)
        vim.diagnostic.set(diagnostic_ns, other_bufnr, other_buffer_diags)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.disable(diagnostic_bufnr, diagnostic_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.disable(diagnostic_bufnr, other_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        vim.diagnostic.enable(diagnostic_bufnr, diagnostic_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        -- Should have no effect
        vim.diagnostic.disable(other_bufnr, other_ns)

        table.insert(result, count_extmarks(diagnostic_bufnr, diagnostic_ns) +
                             count_extmarks(diagnostic_bufnr, other_ns) +
                             count_extmarks(other_bufnr, diagnostic_ns))

        return result
      ]]

      eq(4, result[1])
      eq(2, result[2])
      eq(1, result[3])
      eq(3, result[4])
      eq(3, result[5])
    end)
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
          make_warning("Warning on Server 1", 2, 1, 2, 3),
        }
        local ns_2_diags = {
          make_warning("Warning 1", 2, 1, 2, 3),
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

    it("doesn't error after bwipeout called on buffer", function()
      exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {{ lnum = 0, end_lnum = 0, col = 0, end_col = 0 }})
        vim.cmd("bwipeout! " .. diagnostic_bufnr)

        vim.diagnostic.reset(diagnostic_ns)
      ]]
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

    it('works with diagnostics past the end of the line #16349', function()
      eq({4, 0}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 3, 9001, 3, 9001),
          make_error('Diagnostic #2', 4, 0, 4, 0),
        })
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.api.nvim_win_set_cursor(0, {1, 1})
        vim.diagnostic.goto_next { float = false }
        return vim.diagnostic.get_next_pos { namespace = diagnostic_ns }
      ]])
    end)

    it('works with diagnostics before the start of the line', function()
    eq({4, 0}, exec_lua [[
    vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
        make_error('Diagnostic #1', 3, 9001, 3, 9001),
        make_error('Diagnostic #2', 4, -1, 4, -1),
    })
    vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 1})
    vim.diagnostic.goto_next { float = false }
    return vim.diagnostic.get_next_pos { namespace = diagnostic_ns }
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
          make_warning("Warning on Server 1", 1, 1, 2, 3),
        })

        return #vim.diagnostic.get(diagnostic_bufnr)
      ]])
    end)

    it('returns only requested diagnostics when severity is supplied', function()
      eq({2, 3, 2}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error("Error 1", 1, 1, 1, 5),
          make_warning("Warning on Server 1", 1, 1, 2, 3),
          make_info("Ignored information", 1, 1, 2, 3),
          make_hint("Here's a hint", 1, 1, 2, 3),
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
          make_warning("Warning on Server 1", 1, 1, 2, 3),
          make_info("Ignored information", 1, 1, 2, 3),
          make_error("Error On Other Line", 2, 1, 1, 5),
        })

        return #vim.diagnostic.get(diagnostic_bufnr, {lnum = 2})
      ]])
    end)
  end)

  describe('config()', function()
    it('works with global, namespace, and ephemeral options', function()
      eq(1, exec_lua [[
        vim.diagnostic.config({
          virtual_text = false,
        })

        vim.diagnostic.config({
          virtual_text = true,
          underline = false,
        }, diagnostic_ns)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Some Error', 4, 4, 4, 4),
        })

        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])

      eq(1, exec_lua [[
        vim.diagnostic.config({
          virtual_text = false,
        })

        vim.diagnostic.config({
          virtual_text = false,
          underline = false,
        }, diagnostic_ns)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Some Error', 4, 4, 4, 4),
        }, {virtual_text = true})

        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])

      eq(0, exec_lua [[
        vim.diagnostic.config({
          virtual_text = false,
        })

        vim.diagnostic.config({
          virtual_text = {severity=vim.diagnostic.severity.ERROR},
          underline = false,
        }, diagnostic_ns)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning('Some Warning', 4, 4, 4, 4),
        }, {virtual_text = true})

        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])

      eq(1, exec_lua [[
        vim.diagnostic.config({
          virtual_text = false,
        })

        vim.diagnostic.config({
          virtual_text = {severity=vim.diagnostic.severity.ERROR},
          underline = false,
        }, diagnostic_ns)

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning('Some Warning', 4, 4, 4, 4),
        }, {
          virtual_text = {} -- An empty table uses default values
        })

        return count_extmarks(diagnostic_bufnr, diagnostic_ns)
      ]])
    end)

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

          local virt_text = get_virt_text_extmarks(diagnostic_ns)[1][4].virt_text

          local virt_texts = {}
          for i = 2, #virt_text - 1 do
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

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local virt_text = extmarks[1][4].virt_text[3][1]
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

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local virt_text = extmarks[1][4].virt_text[3][1]
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

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local virt_text = {extmarks[1][4].virt_text[3][1], extmarks[2][4].virt_text[3][1]}
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

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        return {extmarks[1][4].virt_text, extmarks[2][4].virt_text}
      ]]
      eq(" 👀 Warning", result[1][3][1])
      eq(" 🔥 Error", result[2][3][1])
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

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        return {extmarks[1][4].virt_text, extmarks[2][4].virt_text}
      ]]
      eq(" some_linter: 👀 Warning", result[1][3][1])
      eq(" another_linter: 🔥 Error", result[2][3][1])
    end)

    it('can add a prefix to virtual text', function()
      eq('E Some error',  exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = 'E',
            suffix = '',
          }
        })

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local prefix = extmarks[1][4].virt_text[2][1]
        local message = extmarks[1][4].virt_text[3][1]
        return prefix .. message
      ]])

      eq('[err-code] Some error',  exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0, nil, 'err-code'),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = function(diag) return string.format('[%s]', diag.code) end,
            suffix = '',
          }
        })

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local prefix = extmarks[1][4].virt_text[2][1]
        local message = extmarks[1][4].virt_text[3][1]
        return prefix .. message
      ]])
    end)

    it('can add a suffix to virtual text', function()
      eq(' Some error ✘',  exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = '',
            suffix = ' ✘',
          }
        })

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local virt_text = extmarks[1][4].virt_text[3][1]
        return virt_text
      ]])

      eq(' Some error [err-code]',  exec_lua [[
        local diagnostics = {
          make_error('Some error', 0, 0, 0, 0, nil, 'err-code'),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics, {
          underline = false,
          virtual_text = {
            prefix = '',
            suffix = function(diag) return string.format(' [%s]', diag.code) end,
          }
        })

        local extmarks = get_virt_text_extmarks(diagnostic_ns)
        local virt_text = extmarks[1][4].virt_text[3][1]
        return virt_text
      ]])
    end)
  end)

  describe('set()', function()
    it('validates its arguments', function()
      matches("expected a list of diagnostics",
        pcall_err(exec_lua, [[vim.diagnostic.set(1, 0, {lnum = 1, col = 2})]]))
    end)

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

        DisplayCount = 0
        local set_virtual_text = vim.diagnostic.handlers.virtual_text.show
        vim.diagnostic.handlers.virtual_text.show = function(...)
          DisplayCount = DisplayCount + 1
          return set_virtual_text(...)
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


        DisplayCount = 0
        local set_virtual_text = vim.diagnostic.handlers.virtual_text.show
        vim.diagnostic.handlers.virtual_text.show = function(...)
          DisplayCount = DisplayCount + 1
          return set_virtual_text(...)
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

  describe('open_float()', function()
    it('can display a header', function()
      eq({'Diagnostics:', '1. Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float()
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"We're no strangers to love...", '1. Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = "We're no strangers to love..."})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({'You know the rules', '1. Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = {'You know the rules', 'Search'}})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('can show diagnostics from the whole buffer', function()
      eq({'1. Syntax error', '2. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 1, 1, 1, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope="buffer"})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('can show diagnostics from a single line', function()
      -- Using cursor position
      eq({'1. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 1, 1, 1, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        vim.api.nvim_win_set_cursor(0, {2, 1})
        local float_bufnr, winnr = vim.diagnostic.open_float({header=false})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      -- With specified position
      eq({'1. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 1, 1, 1, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        vim.api.nvim_win_set_cursor(0, {1, 1})
        local float_bufnr, winnr = vim.diagnostic.open_float({header=false, pos=1})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('can show diagnostics from a specific position', function()
      -- Using cursor position
      eq({'Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 1, 1, 1, 2),
          make_warning("Some warning", 1, 3, 1, 4),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        vim.api.nvim_win_set_cursor(0, {2, 2})
        local float_bufnr, winnr = vim.diagnostic.open_float({header=false, scope="cursor"})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      -- With specified position
      eq({'Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 1, 1, 1, 2),
          make_warning("Some warning", 1, 3, 1, 4),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        vim.api.nvim_win_set_cursor(0, {1, 1})
        local float_bufnr, winnr = vim.diagnostic.open_float({header=false, scope="cursor", pos={1,3}})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      -- With column position past the end of the line. #16062
      eq({'Syntax error'}, exec_lua [[
        local first_line_len = #vim.api.nvim_buf_get_lines(diagnostic_bufnr, 0, 1, true)[1]
        local diagnostics = {
          make_error("Syntax error", 0, first_line_len + 1, 1, 0),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        vim.api.nvim_win_set_cursor(0, {1, 1})
        local float_bufnr, winnr = vim.diagnostic.open_float({header=false, scope="cursor", pos={0,first_line_len}})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('creates floating window and returns float bufnr and winnr if current line contains diagnostics', function()
      -- Two lines:
      --    Diagnostic:
      --    1. <msg>
      eq(2, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr)
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return #lines
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
        local float_bufnr, winnr = vim.diagnostic.open_float()
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return #lines
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
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {namespace = diagnostic_ns})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return #lines
      ]])
    end)

    it('creates floating window and returns float bufnr and winnr without header, if requested', function()
      -- One line (since no header):
      --    1. <msg>
      eq(1, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {header = false})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return #lines
      ]])
    end)

    it('clamps diagnostic line numbers within the valid range', function()
      eq(1, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 6, 0, 6, 0),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {header = false, pos = 5})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return #lines
      ]])
    end)

    it('can show diagnostic source', function()
      exec_lua [[vim.api.nvim_win_set_buf(0, diagnostic_bufnr)]]

      eq({"1. Syntax error"}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, "source x"),
        }
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {
          header = false,
          source = "if_many",
        })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. source x: Syntax error"}, exec_lua [[
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {
          header = false,
          source = "always",
        })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. source x: Syntax error", "2. source y: Another error"}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, "source x"),
          make_error("Another error", 0, 1, 0, 3, "source y"),
        }
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, {
          header = false,
          source = "if_many",
        })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('respects severity_sort', function()
      exec_lua [[vim.api.nvim_win_set_buf(0, diagnostic_bufnr)]]

      eq({"1. Syntax error", "2. Info", "3. Error", "4. Warning"}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_info('Info', 0, 3, 0, 4),
          make_error('Error', 0, 2, 0, 2),
          make_warning('Warning', 0, 0, 0, 1),
        }

        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)

        vim.diagnostic.config({severity_sort = false})

        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, { header = false })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. Syntax error", "2. Error", "3. Warning", "4. Info"}, exec_lua [[
        vim.diagnostic.config({severity_sort = true})
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, { header = false })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({"1. Info", "2. Warning", "3. Error", "4. Syntax error"}, exec_lua [[
        vim.diagnostic.config({severity_sort = { reverse = true } })
        local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, { header = false })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])
    end)

    it('can filter by severity', function()
      local count_diagnostics_with_severity = function(min_severity, max_severity)
        return exec_lua([[
          local min_severity, max_severity = ...
          vim.diagnostic.config({
            float = {
              severity = {min=min_severity, max=max_severity},
            },
          })

          vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
            make_error("Syntax error", 0, 1, 0, 3),
            make_info('Info', 0, 3, 0, 4),
            make_error('Error', 0, 2, 0, 2),
            make_warning('Warning', 0, 0, 0, 1),
          })

          local float_bufnr, winnr = vim.diagnostic.open_float(diagnostic_bufnr, { header = false })
          if not float_bufnr then
            return 0
          end

          local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
          vim.api.nvim_win_close(winnr, true)
          return #lines
        ]], min_severity, max_severity)
      end

      eq(2, count_diagnostics_with_severity("ERROR"))
      eq(3, count_diagnostics_with_severity("WARN"))
      eq(1, count_diagnostics_with_severity("WARN", "WARN"))
      eq(4, count_diagnostics_with_severity("HINT"))
      eq(0, count_diagnostics_with_severity("HINT", "HINT"))
    end)

    it('can add a prefix to diagnostics', function()
      -- Default is to add a number
      eq({'1. Syntax error', '2. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 1, 1, 1, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope = "buffer"})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({'Syntax error', 'Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 1, 1, 1, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope = "buffer", prefix = ""})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({'1. Syntax error', '2. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
          make_warning("Some warning", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({
          header = false,
          prefix = function(_, i, total)
            -- Only show a number if there is more than one diagnostic
            if total > 1 then
              return string.format("%d. ", i)
            end
            return ""
          end,
        })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({'Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({
          header = false,
          prefix = function(_, i, total)
            -- Only show a number if there is more than one diagnostic
            if total > 1 then
              return string.format("%d. ", i)
            end
            return ""
          end,
        })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq(".../diagnostic.lua:0: prefix: expected string|table|function, got number",
        pcall_err(exec_lua, [[ vim.diagnostic.open_float({ prefix = 42 }) ]]))
    end)

    it('can add a suffix to diagnostics', function()
      -- Default is to render the diagnostic error code
      eq({'1. Syntax error [code-x]', '2. Some warning [code-y]'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, nil, "code-x"),
          make_warning("Some warning", 1, 1, 1, 3, nil, "code-y"),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope = "buffer"})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq({'1. Syntax error', '2. Some warning'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3, nil, "code-x"),
          make_warning("Some warning", 1, 1, 1, 3, nil, "code-y"),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope = "buffer", suffix = ""})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      -- Suffix is rendered on the last line of a multiline diagnostic
      eq({'1. Syntax error', '   More context [code-x]'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error\nMore context", 0, 1, 0, 3, nil, "code-x"),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float({header = false, scope = "buffer"})
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
        vim.api.nvim_win_close(winnr, true)
        return lines
      ]])

      eq(".../diagnostic.lua:0: suffix: expected string|table|function, got number",
        pcall_err(exec_lua, [[ vim.diagnostic.open_float({ suffix = 42 }) ]]))
    end)

    it('works with the old signature', function()
      eq({'1. Syntax error'}, exec_lua [[
        local diagnostics = {
          make_error("Syntax error", 0, 1, 0, 3),
        }
        vim.api.nvim_win_set_buf(0, diagnostic_bufnr)
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, diagnostics)
        local float_bufnr, winnr = vim.diagnostic.open_float(0, { header = false })
        local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, false)
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

  describe('handlers', function()
    it('checks that a new handler is a table', function()
      matches([[.*handler: expected table, got string.*]], pcall_err(exec_lua, [[ vim.diagnostic.handlers.foo = "bar" ]]))
      matches([[.*handler: expected table, got function.*]], pcall_err(exec_lua, [[ vim.diagnostic.handlers.foo = function() end ]]))
    end)

    it('can add new handlers', function()
      eq(true, exec_lua [[
        local handler_called = false
        vim.diagnostic.handlers.test = {
          show = function(namespace, bufnr, diagnostics, opts)
            assert(namespace == diagnostic_ns)
            assert(bufnr == diagnostic_bufnr)
            assert(#diagnostics == 1)
            assert(opts.test.some_opt == 42)
            handler_called = true
          end,
        }

        vim.diagnostic.config({test = {some_opt = 42}})
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning("Warning", 0, 0, 0, 0),
        })
        return handler_called
      ]])
    end)

    it('can disable handlers by setting the corresponding option to false', function()
      eq(false, exec_lua [[
        local handler_called = false
        vim.diagnostic.handlers.test = {
          show = function(namespace, bufnr, diagnostics, opts)
            handler_called = true
          end,
        }

        vim.diagnostic.config({test = false})
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning("Warning", 0, 0, 0, 0),
        })
        return handler_called
      ]])
    end)

    it('always calls a handler\'s hide function if defined', function()
      eq({false, true}, exec_lua [[
        local hide_called = false
        local show_called = false
        vim.diagnostic.handlers.test = {
          show = function(namespace, bufnr, diagnostics, opts)
            show_called = true
          end,
          hide = function(namespace, bufnr)
            assert(namespace == diagnostic_ns)
            assert(bufnr == diagnostic_bufnr)
            hide_called = true
          end,
        }

        vim.diagnostic.config({test = false})
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_warning("Warning", 0, 0, 0, 0),
        })
        vim.diagnostic.hide(diagnostic_ns, diagnostic_bufnr)
        return {show_called, hide_called}
      ]])
    end)

    it('triggers the autocommand when diagnostics are set', function()
      eq({true, true}, exec_lua [[
        -- Set a different buffer as current to test that <abuf> is being set properly in
        -- DiagnosticChanged callbacks
        local tmp = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(tmp)

        local triggered = {}
        vim.api.nvim_create_autocmd('DiagnosticChanged', {
          callback = function(args)
            triggered = {args.buf, #args.data.diagnostics}
          end,
        })
        vim.api.nvim_buf_set_name(diagnostic_bufnr, "test | test")
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic', 0, 0, 0, 0)
        })
        return {
          triggered[1] == diagnostic_bufnr,
          triggered[2] == 1,
        }
      ]])
      end)

    it('triggers the autocommand when diagnostics are cleared', function()
      eq(true, exec_lua [[
        local tmp = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(tmp)
        vim.g.diagnostic_autocmd_triggered = 0
        vim.cmd('autocmd DiagnosticChanged * let g:diagnostic_autocmd_triggered = +expand("<abuf>")')
        vim.api.nvim_buf_set_name(diagnostic_bufnr, "test | test")
        vim.diagnostic.reset(diagnostic_ns, diagnostic_bufnr)
        return vim.g.diagnostic_autocmd_triggered == diagnostic_bufnr
      ]])
      end)

    it("checks if diagnostics are disabled in a buffer", function()
      eq({true, true, true , true}, exec_lua [[
        vim.diagnostic.set(diagnostic_ns, diagnostic_bufnr, {
          make_error('Diagnostic #1', 1, 1, 1, 1),
        })
        vim.api.nvim_set_current_buf(diagnostic_bufnr)
        vim.diagnostic.disable()
        return {
          vim.diagnostic.is_disabled(),
          vim.diagnostic.is_disabled(diagnostic_bufnr),
          vim.diagnostic.is_disabled(diagnostic_bufnr, diagnostic_ns),
          vim.diagnostic.is_disabled(_, diagnostic_ns),
        }
      ]])

      eq({false, false, false , false}, exec_lua [[
        vim.diagnostic.enable()
        return {
          vim.diagnostic.is_disabled(),
          vim.diagnostic.is_disabled(diagnostic_bufnr),
          vim.diagnostic.is_disabled(diagnostic_bufnr, diagnostic_ns),
          vim.diagnostic.is_disabled(_, diagnostic_ns),
        }
      ]])
    end)
  end)
end)
