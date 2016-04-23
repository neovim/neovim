local helpers = require('test.functional.helpers')
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

  describe('split horizontally', function()
    before_each(function()
      nvim('command', 'sp')
    end)

    local function reduce_height()
      screen:expect([[
        tty ready                                         |
        rows: 3, cols: 50                                 |
        {1: }                                                 |
        ~                                                 |
        ==========                                        |
        tty ready                                         |
        rows: 3, cols: 50                                 |
        {2: }                                                 |
        ==========                                        |
        -- TERMINAL --                                    |
      ]])
    end

    it('uses the minimum height of all window displaying it', reduce_height)

    describe('and then vertically', function()
      before_each(function()
        reduce_height()
        nvim('command', 'vsp')
      end)

      local function reduce_width()
        screen:expect([[
          rows: 3, cols: 50        |rows: 3, cols: 50       |
          rows: 3, cols: 24        |rows: 3, cols: 24       |
          {1: }                        |{2: }                       |
          ~                        |~                       |
          ==========                ==========              |
          rows: 3, cols: 50                                 |
          rows: 3, cols: 24                                 |
          {2: }                                                 |
          ==========                                        |
          -- TERMINAL --                                    |
        ]])
        feed('<c-\\><c-n>gg')
        screen:expect([[
          ^tty ready                |rows: 3, cols: 50       |
          rows: 3, cols: 50        |rows: 3, cols: 24       |
          rows: 3, cols: 24        |{2: }                       |
          {2: }                        |~                       |
          ==========                ==========              |
          rows: 3, cols: 50                                 |
          rows: 3, cols: 24                                 |
          {2: }                                                 |
          ==========                                        |
                                                            |
        ]])
      end

      it('uses the minimum width of all window displaying it', reduce_width)

      describe('and then closes one of the vertical splits with q:', function()
        before_each(function()
          reduce_width()
          nvim('command', 'q')
          feed('<c-w>ja')
        end)

        it('will restore the width', function()
          screen:expect([[
            rows: 3, cols: 24                                 |
            rows: 3, cols: 50                                 |
            {2: }                                                 |
            ~                                                 |
            ==========                                        |
            rows: 3, cols: 24                                 |
            rows: 3, cols: 50                                 |
            {1: }                                                 |
            ==========                                        |
            -- TERMINAL --                                    |
          ]])
        end)
      end)
    end)
  end)
end)
