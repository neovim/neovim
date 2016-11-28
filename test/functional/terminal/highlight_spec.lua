local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local nvim_dir, execute = helpers.nvim_dir, helpers.execute
local eq, eval = helpers.eq, helpers.eval

if helpers.pending_win32(pending) then return end

describe('terminal window highlighting', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = {foreground = 45},
      [2] = {background = 46},
      [3] = {foreground = 45, background = 46},
      [4] = {bold = true, italic = true, underline = true},
      [5] = {bold = true},
      [6] = {foreground = 12},
      [7] = {bold = true, reverse = true},
      [8] = {background = 11},
      [9] = {foreground = 130},
      [10] = {reverse = true},
      [11] = {background = 11},
    })
    screen:attach({rgb=false})
    execute('enew | call termopen(["'..nvim_dir..'/tty-test"]) | startinsert')
    screen:expect([[
      tty ready                                         |
      {10: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {5:-- TERMINAL --}                                    |
    ]])
  end)

  local function descr(title, attr_num, set_attrs_fn)
    local function sub(s)
      local str = s:gsub('NUM', attr_num)
      return str
    end

    describe(title, function()
      before_each(function()
        set_attrs_fn()
        thelpers.feed_data('text')
        thelpers.clear_attrs()
        thelpers.feed_data('text')
      end)

      local function pass_attrs()
        screen:expect(sub([[
          tty ready                                         |
          {NUM:text}text{10: }                                         |
                                                            |
                                                            |
                                                            |
                                                            |
          {5:-- TERMINAL --}                                    |
        ]]))
      end

      it('will pass the corresponding attributes', pass_attrs)

      it('will pass the corresponding attributes on scrollback', function()
        pass_attrs()
        local lines = {}
        for i = 1, 8 do
          table.insert(lines, 'line'..tostring(i))
        end
        table.insert(lines, '')
        thelpers.feed_data(lines)
        screen:expect([[
          line4                                             |
          line5                                             |
          line6                                             |
          line7                                             |
          line8                                             |
          {10: }                                                 |
          {5:-- TERMINAL --}                                    |
        ]])
        feed('<c-\\><c-n>gg')
        screen:expect(sub([[
          ^tty ready                                         |
          {NUM:text}textline1                                     |
          line2                                             |
          line3                                             |
          line4                                             |
          line5                                             |
                                                            |
        ]]))
      end)
    end)
  end

  descr('foreground', 1, function() thelpers.set_fg(45) end)
  descr('background', 2, function() thelpers.set_bg(46) end)
  descr('foreground and background', 3, function()
    thelpers.set_fg(45)
    thelpers.set_bg(46)
  end)
  descr('bold, italics and underline', 4, function()
    thelpers.set_bold()
    thelpers.set_italic()
    thelpers.set_underline()
  end)
end)


describe('terminal window highlighting with custom palette', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = {foreground = 1193046, special = Screen.colors.Black},
      [2] = {foreground = 12},
      [3] = {bold = true, reverse = true},
      [5] = {background = 11},
      [6] = {foreground = 130},
      [7] = {reverse = true},
      [8] = {background = 11},
      [9] = {bold = true},
    })
    screen:attach({rgb=true})
    nvim('set_var', 'terminal_color_3', '#123456')
    execute('enew | call termopen(["'..nvim_dir..'/tty-test"]) | startinsert')
    screen:expect([[
      tty ready                                         |
      {7: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {9:-- TERMINAL --}                                    |
    ]])
  end)

  it('will use the custom color', function()
    thelpers.set_fg(3)
    thelpers.feed_data('text')
    thelpers.clear_attrs()
    thelpers.feed_data('text')
    screen:expect([[
      tty ready                                         |
      {1:text}text{7: }                                         |
                                                        |
                                                        |
                                                        |
                                                        |
      {9:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe('synIDattr()', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    execute('highlight Normal ctermfg=252 guifg=#ff0000 guibg=Black')
    -- Salmon #fa8072 Maroon #800000
    execute('highlight Keyword ctermfg=79 guifg=Salmon guisp=Maroon')
  end)

  it('returns cterm-color if RGB-capable UI is _not_ attached', function()
    eq('252', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('252', eval('synIDattr(hlID("Normal"),  "fg#")'))
    eq('',    eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('',    eval('synIDattr(hlID("Normal"),  "bg#")'))
    eq('79',  eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('79',  eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('',    eval('synIDattr(hlID("Keyword"), "sp")'))
    eq('',    eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns gui-color if "gui" arg is passed', function()
    eq('Black',  eval('synIDattr(hlID("Normal"),  "bg", "gui")'))
    eq('Maroon', eval('synIDattr(hlID("Keyword"), "sp", "gui")'))
  end)

  it('returns gui-color if RGB-capable UI is attached', function()
    screen:attach({rgb=true})
    eq('#ff0000', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('Black',   eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('Salmon',  eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('Maroon',  eval('synIDattr(hlID("Keyword"), "sp")'))
  end)

  it('returns #RRGGBB value for fg#/bg#/sp#', function()
    screen:attach({rgb=true})
    eq('#ff0000', eval('synIDattr(hlID("Normal"),  "fg#")'))
    eq('#000000', eval('synIDattr(hlID("Normal"),  "bg#")'))
    eq('#fa8072', eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('#800000', eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns color number if non-GUI', function()
    screen:attach({rgb=false})
    eq('252', eval('synIDattr(hlID("Normal"), "fg")'))
    eq('79', eval('synIDattr(hlID("Keyword"), "fg")'))
  end)
end)

describe('fg/bg special colors', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    execute('highlight Normal ctermfg=145 ctermbg=16 guifg=#ff0000 guibg=Black')
    execute('highlight Visual ctermfg=bg ctermbg=fg guifg=bg guibg=fg guisp=bg')
  end)

  it('resolve to "Normal" values', function()
    eq(eval('synIDattr(hlID("Normal"), "bg")'),
       eval('synIDattr(hlID("Visual"), "fg")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'),
       eval('synIDattr(hlID("Visual"), "fg#")'))
    eq(eval('synIDattr(hlID("Normal"), "fg")'),
       eval('synIDattr(hlID("Visual"), "bg")'))
    eq(eval('synIDattr(hlID("Normal"), "fg#")'),
       eval('synIDattr(hlID("Visual"), "bg#")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "fg", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "fg#", "gui")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg", "gui")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg#", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp#", "gui")'))
  end)

  it('resolve to "Normal" values in RGB-capable UI', function()
    screen:attach({rgb=true})
    eq('bg', eval('synIDattr(hlID("Visual"), "fg")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'),
       eval('synIDattr(hlID("Visual"), "fg#")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg")'))
    eq(eval('synIDattr(hlID("Normal"), "fg#")'),
       eval('synIDattr(hlID("Visual"), "bg#")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'),
       eval('synIDattr(hlID("Visual"), "sp#")'))
  end)

  it('resolve after the "Normal" group is modified', function()
    screen:attach({rgb=true})
    local new_guibg = '#282c34'
    local new_guifg = '#abb2bf'
    execute('highlight Normal guifg='..new_guifg..' guibg='..new_guibg)
    eq(new_guibg, eval('synIDattr(hlID("Visual"), "fg#")'))
    eq(new_guifg, eval('synIDattr(hlID("Visual"), "bg#")'))
    eq(new_guibg, eval('synIDattr(hlID("Visual"), "sp#")'))
  end)
end)
