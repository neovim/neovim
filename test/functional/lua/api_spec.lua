-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local clear = helpers.clear
local NIL = helpers.NIL
local eq = helpers.eq

before_each(clear)

describe('luaeval(vim.api.…)', function()
  describe('with channel_id and buffer handle', function()
    describe('nvim_buf_get_lines', function()
      it('works', function()
        funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
        eq({{_TYPE={}, _VAL={'a\nb'}}},
           funcs.luaeval('vim.api.nvim_buf_get_lines(1, 2, 3, false)'))
      end)
    end)
    describe('nvim_buf_set_lines', function()
      it('works', function()
        funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
        eq(NIL, funcs.luaeval('vim.api.nvim_buf_set_lines(1, 1, 2, false, {"b\\0a"})'))
        eq({'abc', {_TYPE={}, _VAL={'b\na'}}, {_TYPE={}, _VAL={'a\nb'}}, 'ttt'},
           funcs.luaeval('vim.api.nvim_buf_get_lines(1, 0, 4, false)'))
      end)
    end)
  end)
  describe('with errors', function()
    it('transforms API errors into lua errors', function()
      funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
      eq({false, 'string cannot contain newlines'},
         funcs.luaeval('{pcall(vim.api.nvim_buf_set_lines, 1, 1, 2, false, {"b\\na"})}'))
    end)
  end)
end)
