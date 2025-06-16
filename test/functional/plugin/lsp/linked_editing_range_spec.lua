local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local dedent = t.dedent
local exec_lua = n.exec_lua
local insert = n.insert
local feed = n.feed

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp.linked_editing_range', function()
  local text = dedent([[
  hello
  hello]])

  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)
    exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          linkedEditingRangeProvider = true,
        },
        handlers = {
          ['textDocument/linkedEditingRange'] = function(_, _, callback)
            callback(nil, {
              ranges = {
                { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 5 } },
                { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 5 } },
              },
            })
          end,
        },
      })

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)

    insert(text)
  end)

  describe('enable()', function()
    it('validation', function()
      t.matches(
        'enable: expected boolean, got table',
        t.pcall_err(exec_lua, function()
          --- @diagnostic disable-next-line:param-type-mismatch
          vim.lsp.linked_editing_range.enable({})
        end)
      )
    end)
  end)

  describe('when enabled', function()
    it('initiates linked editing', function()
      exec_lua(function()
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        vim.lsp.linked_editing_range.enable()
      end)
      -- Deletion
      feed('ldw')
      eq(
        {
          'h',
          'h',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      -- Insertion
      feed('Apt<Esc>')
      eq(
        {
          'hpt',
          'hpt',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      -- Undo/redo
      feed('0xx')
      eq(
        {
          't',
          't',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      feed('u')
      eq(
        {
          'pt',
          'pt',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      feed('u')
      eq(
        {
          'hpt',
          'hpt',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      feed('<C-r><C-r>')
      eq(
        {
          't',
          't',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
      -- Disabling
      exec_lua(function()
        vim.lsp.linked_editing_range.enable(false)
      end)
      feed('Ipp<Esc>')
      eq(
        {
          'ppt',
          't',
        },
        exec_lua(function()
          return vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end)
      )
    end)
  end)
end)
