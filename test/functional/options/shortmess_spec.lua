local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed

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
        ~                                         |
        ~                                         |
        ~                                         |
        "foo" [New File]                          |
      ]])
      eq(1, eval('bufnr("%")'))

      command('set shortmess+=F')
      feed(':edit bar<CR>')
      screen:expect([[
        ^                                          |
        ~                                         |
        ~                                         |
        ~                                         |
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
        ~                                         |
        ~                                         |
        ~                                         |
        "foo" [New File]                          |
      ]])
      eq(1, eval('bufnr("%")'))
      feed(':edit bar<CR>')
      screen:expect([[
        ^                                          |
        ~                                         |
        ~                                         |
        ~                                         |
        "bar" [New File]                          |
      ]])
      eq(2, eval('bufnr("%")'))
      feed(':bprevious<CR>')
      screen:expect([[
        ^                                          |
        ~                                         |
        ~                                         |
        ~                                         |
        "foo" [New file] --No lines in buffer--   |
      ]])
      eq(1, eval('bufnr("%")'))

      command('set shortmess+=F')
      feed(':bnext<CR>')
      screen:expect([[
        ^                                          |
        ~                                         |
        ~                                         |
        ~                                         |
        :bnext                                    |
      ]])
      eq(2, eval('bufnr("%")'))
      feed(':bprevious<CR>')
      screen:expect([[
        ^                                          |
        ~                                         |
        ~                                         |
        ~                                         |
        :bprevious                                |
      ]])
      eq(1, eval('bufnr("%")'))
    end)
  end)
end)
