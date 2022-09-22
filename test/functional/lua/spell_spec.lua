local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local command = helpers.command
local eq = helpers.eq
local pcall_err = helpers.pcall_err

describe('vim.spell', function()
  before_each(function()
    clear()
  end)

  describe('.check', function()
    local check = function(x, exp)
        return eq(exp, exec_lua("return vim.spell.check(...)", x))
    end

    it('can handle nil', function()
      eq([[Error executing lua: [string "<nvim>"]:0: bad argument #1 to 'check' (expected string)]],
        pcall_err(exec_lua, [[vim.spell.check(nil)]]))
    end)

    it('can check spellings', function()
      check('hello', {})

      check(
        'helloi',
        {{"helloi", "bad", 1}}
      )

      check(
        'hello therei',
        {{"therei", "bad", 7}}
      )

      check(
        'hello. there',
        {{"there", "caps", 8}}
      )

      check(
        'neovim cna chkc spellins. okay?',
        {
          {"neovim"  , "bad" ,  1},
          {"cna"     , "bad" ,  8},
          {"chkc"    , "bad" , 12},
          {"spellins", "bad" , 17},
          {"okay"    , "caps", 27}
        }
      )
    end)

    it('does not report too many spellcap errors', function()
      check('Hello. 72th', {})
    end)

    describe('with spelloptions=camel', function()

      it('works', function()
        check('TheCamelWord asdf', {
          { 'TheCamelWord', 'bad', 1 },
          { 'asdf', 'bad', 14 },
        })

        command [[set spelloptions=camel]]

        check('TheCamelWord asdf', {
          { 'asdf', 'bad', 14 },
        })
      end)
    end)
  end)
end)
