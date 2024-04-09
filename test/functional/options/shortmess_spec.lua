local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval
local feed = t.feed

describe("'shortmess'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
    screen:attach()
  end)

  describe('"F" flag', function()
    it('hides :edit fileinfo messages', function()
      command('set hidden')
      command('set shortmess-=F')
      feed(':edit foo<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        "foo" [New]                               |
      ]])
      eq(1, eval('bufnr("%")'))

      command('set shortmess+=F')
      feed(':edit bar<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        :edit bar                                 |
      ]])
      eq(2, eval('bufnr("%")'))
    end)

    it('hides :bnext, :bprevious fileinfo messages', function()
      command('set hidden')
      command('set shortmess-=F')
      feed(':edit foo<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        "foo" [New]                               |
      ]])
      eq(1, eval('bufnr("%")'))
      feed(':edit bar<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        "bar" [New]                               |
      ]])
      eq(2, eval('bufnr("%")'))
      feed(':bprevious<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        "foo" [New] --No lines in buffer--        |
      ]])
      eq(1, eval('bufnr("%")'))

      command('set shortmess+=F')
      feed(':bnext<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        :bnext                                    |
      ]])
      eq(2, eval('bufnr("%")'))
      feed(':bprevious<CR>')
      screen:expect([[
        ^                                          |
        {1:~                                         }|*3
        :bprevious                                |
      ]])
      eq(1, eval('bufnr("%")'))
    end)
  end)
end)
