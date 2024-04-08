local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.terminal.testutil')
local feed, clear = t.feed, t.clear
local api = t.api
local testprg, command = t.testprg, t.command
local nvim_prog_abs = t.nvim_prog_abs
local fn = t.fn
local nvim_set = t.nvim_set
local is_os = t.is_os
local skip = t.skip

describe(':terminal highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = { foreground = 45 },
      [2] = { background = 46 },
      [3] = { foreground = 45, background = 46 },
      [4] = { bold = true, italic = true, underline = true, strikethrough = true },
      [5] = { bold = true },
      [6] = { foreground = 12 },
      [7] = { bold = true, reverse = true },
      [8] = { background = 11 },
      [9] = { foreground = 130 },
      [10] = { reverse = true },
      [11] = { background = 11 },
      [12] = { bold = true, underdouble = true },
      [13] = { italic = true, undercurl = true },
    })
    screen:attach({ rgb = false })
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      {10: }                                                 |
                                                        |*4
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
        tt.feed_data('text')
        tt.clear_attrs()
        tt.feed_data('text')
      end)

      local function pass_attrs()
        skip(is_os('win'))
        screen:expect(sub([[
          tty ready                                         |
          {NUM:text}text{10: }                                         |
                                                            |*4
          {5:-- TERMINAL --}                                    |
        ]]))
      end

      it('will pass the corresponding attributes', pass_attrs)

      it('will pass the corresponding attributes on scrollback', function()
        skip(is_os('win'))
        pass_attrs()
        local lines = {}
        for i = 1, 8 do
          table.insert(lines, 'line' .. tostring(i))
        end
        table.insert(lines, '')
        tt.feed_data(lines)
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

  descr('foreground', 1, function()
    tt.set_fg(45)
  end)
  descr('background', 2, function()
    tt.set_bg(46)
  end)
  descr('foreground and background', 3, function()
    tt.set_fg(45)
    tt.set_bg(46)
  end)
  descr('bold, italics, underline and strikethrough', 4, function()
    tt.set_bold()
    tt.set_italic()
    tt.set_underline()
    tt.set_strikethrough()
  end)
  descr('bold and underdouble', 12, function()
    tt.set_bold()
    tt.set_underdouble()
  end)
  descr('italics and undercurl', 13, function()
    tt.set_italic()
    tt.set_undercurl()
  end)
end)

it(':terminal highlight has lower precedence than editor #9964', function()
  clear()
  local screen = Screen.new(30, 4)
  screen:set_default_attr_ids({
    -- "Normal" highlight emitted by the child nvim process.
    N_child = {
      foreground = tonumber('0x4040ff'),
      background = tonumber('0xffff40'),
      fg_indexed = true,
      bg_indexed = true,
    },
    -- "Search" highlight in the parent nvim process.
    S = { background = Screen.colors.Green, italic = true, foreground = Screen.colors.Red },
    -- "Question" highlight in the parent nvim process.
    -- note: bg is indexed as it comes from the (cterm) child, while fg isn't as it comes from (rgb) parent
    Q = {
      background = tonumber('0xffff40'),
      bold = true,
      foreground = Screen.colors.SeaGreen4,
      bg_indexed = true,
    },
  })
  screen:attach({ rgb = true })
  -- Child nvim process in :terminal (with cterm colors).
  fn.termopen({
    nvim_prog_abs(),
    '-n',
    '-u',
    'NORC',
    '-i',
    'NONE',
    '--cmd',
    nvim_set .. ' notermguicolors',
    '+hi Normal ctermfg=Blue ctermbg=Yellow',
    '+norm! ichild nvim',
    '+norm! oline 2',
  }, {
    env = {
      VIMRUNTIME = os.getenv('VIMRUNTIME'),
    },
  })
  screen:expect([[
    {N_child:^child nvim                    }|
    {N_child:line 2                        }|
    {N_child:                              }|
                                  |
  ]])
  command('hi Search gui=italic guifg=Red guibg=Green cterm=italic ctermfg=Red ctermbg=Green')
  feed('/nvim<cr>')
  screen:expect([[
    {N_child:child }{S:^nvim}{N_child:                    }|
    {N_child:line 2                        }|
    {N_child:                              }|
    /nvim                         |
  ]])
  command('syntax keyword Question line')
  screen:expect([[
    {N_child:child }{S:^nvim}{N_child:                    }|
    {Q:line}{N_child: 2                        }|
    {N_child:                              }|
    /nvim                         |
  ]])
end)

it('CursorLine and CursorColumn work in :terminal buffer in Normal mode', function()
  clear()
  local screen = Screen.new(50, 7)
  screen:set_default_attr_ids({
    [1] = { background = Screen.colors.Grey90 }, -- CursorLine, CursorColumn
    [2] = { reverse = true }, -- TermCursor
    [3] = { bold = true }, -- ModeMsg
    [4] = { background = Screen.colors.Grey90, reverse = true },
    [5] = { background = Screen.colors.Red },
  })
  screen:attach()
  command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
  screen:expect([[
    ^tty ready                                         |
                                                      |*6
  ]])
  tt.feed_data((' foobar'):rep(30))
  screen:expect([[
    ^tty ready                                         |
     foobar foobar foobar foobar foobar foobar foobar |
    foobar foobar foobar foobar foobar foobar foobar f|
    oobar foobar foobar foobar foobar foobar foobar fo|
    obar foobar foobar foobar foobar foobar foobar foo|
    bar foobar                                        |
                                                      |
  ]])
  command('set cursorline cursorcolumn')
  feed('j10w')
  screen:expect([[
    tty ready     {1: }                                   |
     foobar foobar{1: }foobar foobar foobar foobar foobar |
    {1:foobar foobar ^foobar foobar foobar foobar foobar f}|
    oobar foobar f{1:o}obar foobar foobar foobar foobar fo|
    obar foobar fo{1:o}bar foobar foobar foobar foobar foo|
    bar foobar    {1: }                                   |
                                                      |
  ]])
  -- Entering terminal mode disables 'cursorline' and 'cursorcolumn'.
  feed('i')
  screen:expect([[
    tty ready                                         |
     foobar foobar foobar foobar foobar foobar foobar |
    foobar foobar foobar foobar foobar foobar foobar f|
    oobar foobar foobar foobar foobar foobar foobar fo|
    obar foobar foobar foobar foobar foobar foobar foo|
    bar foobar{2: }                                       |
    {3:-- TERMINAL --}                                    |
  ]])
  -- Leaving terminal mode restores old values.
  feed([[<C-\><C-N>]])
  screen:expect([[
    tty ready{1: }                                        |
     foobar f{1:o}obar foobar foobar foobar foobar foobar |
    foobar fo{1:o}bar foobar foobar foobar foobar foobar f|
    oobar foo{1:b}ar foobar foobar foobar foobar foobar fo|
    obar foob{1:a}r foobar foobar foobar foobar foobar foo|
    {1:bar fooba^r                                        }|
                                                      |
  ]])
  -- CursorLine and CursorColumn are combined with TermCursorNC.
  command('highlight TermCursorNC gui=reverse')
  screen:expect([[
    tty ready{1: }                                        |
     foobar f{1:o}obar foobar foobar foobar foobar foobar |
    foobar fo{1:o}bar foobar foobar foobar foobar foobar f|
    oobar foo{1:b}ar foobar foobar foobar foobar foobar fo|
    obar foob{1:a}r foobar foobar foobar foobar foobar foo|
    {1:bar fooba^r}{4: }{1:                                       }|
                                                      |
  ]])
  feed('2gg11|')
  screen:expect([[
    tty ready {1: }                                       |
    {1: foobar fo^obar foobar foobar foobar foobar foobar }|
    foobar foo{1:b}ar foobar foobar foobar foobar foobar f|
    oobar foob{1:a}r foobar foobar foobar foobar foobar fo|
    obar fooba{1:r} foobar foobar foobar foobar foobar foo|
    bar foobar{4: }                                       |
                                                      |
  ]])
  -- TermCursorNC has higher precedence.
  command('highlight TermCursorNC gui=NONE guibg=Red')
  screen:expect([[
    tty ready {1: }                                       |
    {1: foobar fo^obar foobar foobar foobar foobar foobar }|
    foobar foo{1:b}ar foobar foobar foobar foobar foobar f|
    oobar foob{1:a}r foobar foobar foobar foobar foobar fo|
    obar fooba{1:r} foobar foobar foobar foobar foobar foo|
    bar foobar{5: }                                       |
                                                      |
  ]])
  feed('G$')
  screen:expect([[
    tty ready{1: }                                        |
     foobar f{1:o}obar foobar foobar foobar foobar foobar |
    foobar fo{1:o}bar foobar foobar foobar foobar foobar f|
    oobar foo{1:b}ar foobar foobar foobar foobar foobar fo|
    obar foob{1:a}r foobar foobar foobar foobar foobar foo|
    {1:bar fooba^r}{5: }{1:                                       }|
                                                      |
  ]])
end)

describe(':terminal highlight forwarding', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_rgb_cterm(true)
    screen:set_default_attr_ids({
      [1] = { { reverse = true }, { reverse = true } },
      [2] = { { bold = true }, { bold = true } },
      [3] = { { fg_indexed = true, foreground = tonumber('0xe0e000') }, { foreground = 3 } },
      [4] = { { foreground = tonumber('0xff8000') }, {} },
    })
    screen:attach()
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      {1: }                                                 |
                                                        |*4
      {2:-- TERMINAL --}                                    |
    ]])
  end)

  it('will handle cterm and rgb attributes', function()
    skip(is_os('win'))
    tt.set_fg(3)
    tt.feed_data('text')
    tt.feed_termcode('[38:2:255:128:0m')
    tt.feed_data('color')
    tt.clear_attrs()
    tt.feed_data('text')
    screen:expect {
      grid = [[
      tty ready                                         |
      {3:text}{4:color}text{1: }                                    |
                                                        |*4
      {2:-- TERMINAL --}                                    |
    ]],
    }
  end)
end)

describe(':terminal highlight with custom palette', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = { foreground = tonumber('0x123456') }, -- no fg_indexed when overridden
      [2] = { foreground = 12 },
      [3] = { bold = true, reverse = true },
      [5] = { background = 11 },
      [6] = { foreground = 130 },
      [7] = { reverse = true },
      [8] = { background = 11 },
      [9] = { bold = true },
    })
    screen:attach({ rgb = true })
    api.nvim_set_var('terminal_color_3', '#123456')
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      {7: }                                                 |
                                                        |*4
      {9:-- TERMINAL --}                                    |
    ]])
  end)

  it('will use the custom color', function()
    skip(is_os('win'))
    tt.set_fg(3)
    tt.feed_data('text')
    tt.clear_attrs()
    tt.feed_data('text')
    screen:expect([[
      tty ready                                         |
      {1:text}text{7: }                                         |
                                                        |*4
      {9:-- TERMINAL --}                                    |
    ]])
  end)
end)
