local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed, nvim = helpers.feed, helpers.nvim

describe('terminal', function()
  local screen

  before_each(function()
    clear()
    -- set the statusline to a constant value because of variables like pid
    -- and current directory and to improve visibility of splits
    nvim('set_option', 'statusline', '==========')
    nvim('command', 'highlight StatusLine cterm=NONE')
    nvim('command', 'highlight StatusLineNC cterm=NONE')
    nvim('command', 'highlight VertSplit cterm=NONE')
    screen = thelpers.screen_setup(3)
  end)

  after_each(function()
    screen:detach()
  end)

  describe('when the screen is resized', function()
    it('will forward a resize request to the program', function()
      screen:try_resize(screen._width + 3, screen._height + 5)
      screen:expect([[
        tty ready                                            |
        rows: 14, cols: 53                                   |
        {1: }                                                    |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
                                                             |
        -- TERMINAL --                                       |
      ]])
      screen:try_resize(screen._width - 6, screen._height - 10)
      screen:expect([[
        tty ready                                      |
        rows: 14, cols: 53                             |
        rows: 4, cols: 47                              |
        {1: }                                              |
        -- TERMINAL --                                 |
      ]])
    end)
  end)
end)
