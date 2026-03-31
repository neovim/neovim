local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local pcall_err = t.pcall_err

describe('vim.spell', function()
  before_each(function()
    clear()
  end)

  describe('.check', function()
    local check = function(x, exp)
      return eq(exp, exec_lua('return vim.spell.check(...)', x))
    end

    it('can handle nil', function()
      eq(
        [[bad argument #1 to 'check' (expected string)]],
        pcall_err(exec_lua, [[vim.spell.check(nil)]])
      )
    end)

    it('can check spellings', function()
      check('hello', {})

      check('helloi', { { 'helloi', 'bad', 1 } })

      check('hello therei', { { 'therei', 'bad', 7 } })

      check('hello. there', { { 'there', 'caps', 8 } })

      check('neovim cna chkc spellins. okay?', {
        { 'neovim', 'bad', 1 },
        { 'cna', 'bad', 8 },
        { 'chkc', 'bad', 12 },
        { 'spellins', 'bad', 17 },
        { 'okay', 'caps', 27 },
      })
    end)
  end)
end)
