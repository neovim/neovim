local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local clear = helpers.clear
local feed, nvim = helpers.feed, helpers.nvim
local feed_data = thelpers.feed_data

describe('terminal mouse', function()
  local screen

  before_each(function()
    clear()
    nvim('set_option', 'statusline', '==========')
    nvim('command', 'highlight StatusLine cterm=NONE')
    nvim('command', 'highlight StatusLineNC cterm=NONE')
    nvim('command', 'highlight VertSplit cterm=NONE')
    screen = thelpers.screen_setup()
    local lines = {}
    for i = 1, 30 do
      table.insert(lines, 'line'..tostring(i))
    end
    table.insert(lines, '')
    feed_data(lines)
    screen:expect([[
      line26                                            |
      line27                                            |
      line28                                            |
      line29                                            |
      line30                                            |
      {1: }                                                 |
      -- TERMINAL --                                    |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  describe('when the terminal has focus', function()
    it('will exit focus when scrolled', function()
      feed('<MouseDown><0,0>')
      screen:expect([[
        line23                                            |
        line24                                            |
        line25                                            |
        line26                                            |
        line27                                            |
        ^line28                                            |
                                                          |
      ]])
    end)

    it('will exit focus after <C-\\>, then scrolled', function()
      feed('<C-\\>')
      feed('<MouseDown><0,0>')
      screen:expect([[
        line23                                            |
        line24                                            |
        line25                                            |
        line26                                            |
        line27                                            |
        ^line28                                            |
                                                          |
      ]])
    end)

    describe('with mouse events enabled by the program', function()
      before_each(function()
        thelpers.enable_mouse()
        thelpers.feed_data('mouse enabled\n')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          {1: }                                                 |
          -- TERMINAL --                                    |
        ]])
      end)

      it('will forward mouse clicks to the program', function()
        feed('<LeftMouse><1,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
           "#{1: }                                              |
          -- TERMINAL --                                    |
        ]])
      end)

      it('will forward mouse scroll to the program', function()
        feed('<MouseDown><0,0>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          `!!{1: }                                              |
          -- TERMINAL --                                    |
        ]])
      end)
    end)

    describe('with a split window and other buffer', function()
      before_each(function()
        feed('<c-\\><c-n>:vsp<cr>')
        screen:expect([[
          line28                   |line28                  |
          line29                   |line29                  |
          line30                   |line30                  |
          rows: 5, cols: 24        |rows: 5, cols: 24       |
          {2:^ }                        |{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
        feed(':enew | set number<cr>')
        screen:expect([[
            1 ^                     |line28                  |
          ~                        |line29                  |
          ~                        |line30                  |
          ~                        |rows: 5, cols: 24       |
          ~                        |{2: }                       |
          ==========                ==========              |
          :enew | set number                                |
        ]])
        feed('30iline\n<esc>')
        screen:expect([[
           27 line                 |line28                  |
           28 line                 |line29                  |
           29 line                 |line30                  |
           30 line                 |rows: 5, cols: 24       |
           31 ^                     |{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
        feed('<c-w>li')
        screen:expect([[
           27 line                 |line28                  |
           28 line                 |line29                  |
           29 line                 |line30                  |
           30 line                 |rows: 5, cols: 24       |
           31                      |{1: }                       |
          ==========                ==========              |
          -- TERMINAL --                                    |
        ]])
        -- enabling mouse won't affect interaction with other windows
        thelpers.enable_mouse()
        thelpers.feed_data('mouse enabled\n')
        screen:expect([[
           27 line                 |line29                  |
           28 line                 |line30                  |
           29 line                 |rows: 5, cols: 24       |
           30 line                 |mouse enabled           |
           31                      |{1: }                       |
          ==========                ==========              |
          -- TERMINAL --                                    |
        ]])
      end)

      it('wont lose focus if another window is scrolled', function()
        feed('<MouseDown><0,0><MouseDown><0,0>')
        screen:expect([[
           21 line                 |line29                  |
           22 line                 |line30                  |
           23 line                 |rows: 5, cols: 24       |
           24 line                 |mouse enabled           |
           25 line                 |{1: }                       |
          ==========                ==========              |
          -- TERMINAL --                                    |
        ]])
        feed('<S-MouseUp><0,0>')
        screen:expect([[
           26 line                 |line29                  |
           27 line                 |line30                  |
           28 line                 |rows: 5, cols: 24       |
           29 line                 |mouse enabled           |
           30 line                 |{1: }                       |
          ==========                ==========              |
          -- TERMINAL --                                    |
        ]])
      end)

      it('will lose focus if another window is clicked', function()
        feed('<LeftMouse><5,1>')
        screen:expect([[
           27 line                 |line29                  |
           28 l^ine                 |line30                  |
           29 line                 |rows: 5, cols: 24       |
           30 line                 |mouse enabled           |
           31                      |{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
      end)
    end)
  end)
end)
