local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('Rename', function()
  local builtin_input, bufnr, fake_uri

  before_each(function()
    clear()
    fake_uri = 'file://fake/uri'

    bufnr = exec_lua([[
      fake_uri = ...
      bufnr = vim.uri_to_bufnr(fake_uri)
      local lines = {'line 1'; 'line 2'; 'what'; 'else'; 'do'; 'you'; 'want'}
      vim.fn.bufload(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)

      -- place the cursor at the beginning of 'else'
      vim.fn.cursor(4, 1)
      return bufnr
    ]], fake_uri)
  end)

  after_each(function()
    if builtin_input ~= nil then
      exec_lua([[
        vim.fn.input = ...
      ]], builtin_input)
    end
    exec_lua('vim.stubs = nil')
  end)

  describe('vim.lsp.buf.rename', function()
    it('should use <cword> in input if server doesnt support prepareRename', function()
      builtin_input = exec_lua([[
        local builtin_input = vim.fn.input
        vim._stubs = {}
        vim.fn.input = function(prompt)
          vim._stubs.input_prompt = prompt
          return prompt
        end
        return bultin_input
      ]])

      exec_lua('vim.lsp.buf.rename(...)', 'new_name')
      local provided_prompt = exec_lua('return vim._stubs.input_prompt')
      eq('else', provided_prompt)
    end)
  end)
end)
