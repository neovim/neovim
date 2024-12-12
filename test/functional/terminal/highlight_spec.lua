local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local feed, clear = n.feed, n.clear
local api = n.api
local testprg, command = n.testprg, n.command
local nvim_prog_abs = n.nvim_prog_abs
local fn = n.fn
local nvim_set = n.nvim_set
local is_os = t.is_os
local skip = t.skip

describe(':terminal highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7, { rgb = false })
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
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
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
          {NUM:text}text^                                          |
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
          ^                                                  |
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
  local screen = Screen.new(30, 4, { rgb = true })
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
    [2] = { reverse = true },
    [3] = { bold = true }, -- ModeMsg
    [4] = { background = Screen.colors.Grey90, reverse = true },
    [5] = { background = Screen.colors.Red },
  })
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
    bar foobar^                                        |
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

  -- Skip the rest of these tests on Windows #31587
  if is_os('win') then
    return
  end

  -- CursorLine and CursorColumn are combined with terminal colors.
  tt.set_reverse()
  tt.feed_data(' foobar')
  tt.clear_attrs()
  screen:expect([[
    tty ready{1: }                                        |
     foobar f{1:o}obar foobar foobar foobar foobar foobar |
    foobar fo{1:o}bar foobar foobar foobar foobar foobar f|
    oobar foo{1:b}ar foobar foobar foobar foobar foobar fo|
    obar foob{1:a}r foobar foobar foobar foobar foobar foo|
    {1:bar fooba^r}{4: foobar}{1:                                 }|
                                                      |
  ]])
  feed('2gg15|')
  screen:expect([[
    tty ready     {1: }                                   |
    {1: foobar foobar^ foobar foobar foobar foobar foobar }|
    foobar foobar {1:f}oobar foobar foobar foobar foobar f|
    oobar foobar f{1:o}obar foobar foobar foobar foobar fo|
    obar foobar fo{1:o}bar foobar foobar foobar foobar foo|
    bar foobar{2: foo}{4:b}{2:ar}                                 |
                                                      |
  ]])

  -- Set bg color to red
  tt.feed_csi('48;2;255:0:0m')
  tt.feed_data(' foobar')
  tt.clear_attrs()
  feed('2gg20|')

  -- Terminal color has higher precedence
  screen:expect([[
    tty ready          {1: }                              |
    {1: foobar foobar foob^ar foobar foobar foobar foobar }|
    foobar foobar fooba{1:r} foobar foobar foobar foobar f|
    oobar foobar foobar{1: }foobar foobar foobar foobar fo|
    obar foobar foobar {1:f}oobar foobar foobar foobar foo|
    bar foobar{2: foobar}{5: foobar}                          |
                                                      |
  ]])
  feed('G$')
  screen:expect([[
    tty ready              {1: }                          |
     foobar foobar foobar f{1:o}obar foobar foobar foobar |
    foobar foobar foobar fo{1:o}bar foobar foobar foobar f|
    oobar foobar foobar foo{1:b}ar foobar foobar foobar fo|
    obar foobar foobar foob{1:a}r foobar foobar foobar foo|
    {1:bar foobar}{4: foobar}{5: fooba^r}{1:                          }|
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
      [1] = { { bold = true }, { bold = true } },
      [2] = { { fg_indexed = true, foreground = tonumber('0xe0e000') }, { foreground = 3 } },
      [3] = { { foreground = tonumber('0xff8000') }, {} },
    })
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {1:-- TERMINAL --}                                    |
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
      {2:text}{3:color}text^                                     |
                                                        |*4
      {1:-- TERMINAL --}                                    |
    ]],
    }
  end)
end)

describe(':terminal highlight with custom palette', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7, { rgb = true })
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
    api.nvim_set_var('terminal_color_3', '#123456')
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    feed('i')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
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
      {1:text}text^                                          |
                                                        |*4
      {9:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe(':terminal', function()
  before_each(clear)

  it('can display URLs', function()
    local screen = Screen.new(50, 7)
    screen:add_extra_attr_ids {
      [100] = { url = 'https://example.com' },
    }
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '\027]8;;https://example.com\027\\Example\027]8;;\027\\')
    screen:expect({
      grid = [[
        {100:^Example}                                           |
                                                          |*6
      ]],
    })
  end)
end)
