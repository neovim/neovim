local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local exec_capture = helpers.exec_capture
local meths = helpers.meths
local funcs = helpers.funcs
local pcall_err = helpers.pcall_err
local ok = helpers.ok
local assert_alive = helpers.assert_alive

describe('API: highlight',function()
  clear()
  Screen.new() -- initialize Screen.colors

  local expected_rgb = {
    background = Screen.colors.Yellow,
    foreground = Screen.colors.Red,
    special = Screen.colors.Blue,
    bold = true,
  }
  local expected_cterm = {
    background = 10,
    underline = true,
  }
  local expected_rgb2 = {
    background = Screen.colors.Yellow,
    foreground = Screen.colors.Red,
    special = Screen.colors.Blue,
    bold = true,
    italic = true,
    reverse = true,
    underline = true,
    strikethrough = true,
    altfont = true,
    nocombine = true,
  }
  local expected_undercurl = {
    background = Screen.colors.Yellow,
    foreground = Screen.colors.Red,
    special = Screen.colors.Blue,
    undercurl = true,
  }

  before_each(function()
    clear()
    command("hi NewHighlight cterm=underline ctermbg=green guifg=red guibg=yellow guisp=blue gui=bold")
  end)

  it("nvim_get_hl_by_id", function()
    local hl_id = eval("hlID('NewHighlight')")
    eq(expected_cterm, nvim("get_hl_by_id", hl_id, false))

    hl_id = eval("hlID('NewHighlight')")
    -- Test valid id.
    eq(expected_rgb, nvim("get_hl_by_id", hl_id, true))

    -- Test invalid id.
    eq('Invalid highlight id: 30000', pcall_err(meths.get_hl_by_id, 30000, false))

    -- Test all highlight properties.
    command('hi NewHighlight gui=underline,bold,italic,reverse,strikethrough,altfont,nocombine')
    eq(expected_rgb2, nvim("get_hl_by_id", hl_id, true))

    -- Test undercurl
    command('hi NewHighlight gui=undercurl')
    eq(expected_undercurl, nvim("get_hl_by_id", hl_id, true))

    -- Test nil argument.
    eq('Wrong type for argument 1 when calling nvim_get_hl_by_id, expecting Integer',
       pcall_err(meths.get_hl_by_id, { nil }, false))

    -- Test 0 argument.
    eq('Invalid highlight id: 0', pcall_err(meths.get_hl_by_id, 0, false))

    -- Test -1 argument.
    eq('Invalid highlight id: -1', pcall_err(meths.get_hl_by_id, -1, false))

    -- Test highlight group without ctermbg value.
    command('hi Normal ctermfg=red ctermbg=yellow')
    command('hi NewConstant ctermfg=green guifg=white guibg=blue')
    hl_id = eval("hlID('NewConstant')")
    eq({foreground = 10,}, meths.get_hl_by_id(hl_id, false))

    -- Test highlight group without ctermfg value.
    command('hi clear NewConstant')
    command('hi NewConstant ctermbg=Magenta guifg=white guibg=blue')
    eq({background = 13,}, meths.get_hl_by_id(hl_id, false))

    -- Test highlight group with ctermfg and ctermbg values.
    command('hi clear NewConstant')
    command('hi NewConstant ctermfg=green ctermbg=Magenta guifg=white guibg=blue')
    eq({foreground = 10, background = 13,}, meths.get_hl_by_id(hl_id, false))
  end)

  it("nvim_get_hl_by_name", function()
    local expected_normal = { background = Screen.colors.Yellow,
                              foreground = Screen.colors.Red }

    -- Test `Normal` default values.
    eq({}, nvim("get_hl_by_name", 'Normal', true))

    eq(expected_cterm, nvim("get_hl_by_name", 'NewHighlight', false))
    eq(expected_rgb, nvim("get_hl_by_name", 'NewHighlight', true))

    -- Test `Normal` modified values.
    command('hi Normal guifg=red guibg=yellow')
    eq(expected_normal, nvim("get_hl_by_name", 'Normal', true))

    -- Test invalid name.
    eq("Invalid highlight name: 'unknown_highlight'",
       pcall_err(meths.get_hl_by_name , 'unknown_highlight', false))

    -- Test nil argument.
    eq('Wrong type for argument 1 when calling nvim_get_hl_by_name, expecting String',
       pcall_err(meths.get_hl_by_name , { nil }, false))

    -- Test empty string argument.
    eq('Invalid highlight name',
       pcall_err(meths.get_hl_by_name , '', false))

    -- Test "standout" attribute. #8054
    eq({ underline = true, },
       meths.get_hl_by_name('cursorline', 0));
    command('hi CursorLine cterm=standout,underline term=standout,underline gui=standout,underline')
    command('set cursorline')
    eq({ underline = true, standout = true, },
       meths.get_hl_by_name('cursorline', 0));

    -- Test cterm & Normal values. #18024 (tail) & #18980
    -- Ensure Normal, and groups that match Normal return their fg & bg cterm values
    meths.set_hl(0, 'Normal', {ctermfg = 17, ctermbg = 213})
    meths.set_hl(0, 'NotNormal', {ctermfg = 17, ctermbg = 213, nocombine = true})
    -- Note colors are "cterm" values, not rgb-as-ints
    eq({foreground = 17, background = 213}, nvim("get_hl_by_name", 'Normal', false))
    eq({foreground = 17, background = 213, nocombine = true}, nvim("get_hl_by_name", 'NotNormal', false))
  end)

  it('nvim_get_hl_id_by_name', function()
    -- precondition: use a hl group that does not yet exist
    eq("Invalid highlight name: 'Shrubbery'", pcall_err(meths.get_hl_by_name, "Shrubbery", true))
    eq(0, funcs.hlID("Shrubbery"))

    local hl_id = meths.get_hl_id_by_name("Shrubbery")
    ok(hl_id > 0)
    eq(hl_id, funcs.hlID("Shrubbery"))

    command('hi Shrubbery guifg=#888888 guibg=#888888')
    eq({foreground=tonumber("0x888888"), background=tonumber("0x888888")},
       meths.get_hl_by_id(hl_id, true))
    eq({foreground=tonumber("0x888888"), background=tonumber("0x888888")},
       meths.get_hl_by_name("Shrubbery", true))
  end)

  it("nvim_buf_add_highlight to other buffer doesn't crash if undo is disabled #12873", function()
    command('vsplit file')
    local err, _ = pcall(meths.set_option_value, 'undofile', false, { buf = 1 })
    eq(true, err)
    err, _ = pcall(meths.set_option_value, 'undolevels', -1, { buf = 1 })
    eq(true, err)
    err, _ = pcall(meths.buf_add_highlight, 1, -1, 'Question', 0, 0, -1)
    eq(true, err)
    assert_alive()
  end)
end)

describe("API: set highlight", function()
  local highlight_color = {
    fg = tonumber('0xff0000'),
    bg = tonumber('0x0032aa'),
    ctermfg = 8,
    ctermbg = 15,
  }
  local highlight1 = {
    background = highlight_color.bg,
    foreground = highlight_color.fg,
    bold = true,
    italic = true,
  }
  local highlight2_config = {
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    underline = true,
    reverse = true,
  }
  local highlight2_result = {
    background = highlight_color.ctermbg,
    foreground = highlight_color.ctermfg,
    underline = true,
    reverse = true,
  }
  local highlight3_config = {
    background = highlight_color.bg,
    foreground = highlight_color.fg,
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    bold = true,
    italic = true,
    reverse = true,
    underdashed = true,
    strikethrough = true,
    altfont = true,
    cterm = {
      italic = true,
      reverse = true,
      strikethrough = true,
      altfont = true,
      nocombine = true,
    }
  }
  local highlight3_result_gui = {
    background = highlight_color.bg,
    foreground = highlight_color.fg,
    bold = true,
    italic = true,
    reverse = true,
    underdashed = true,
    strikethrough = true,
    altfont = true,
  }
  local highlight3_result_cterm = {
    background = highlight_color.ctermbg,
    foreground = highlight_color.ctermfg,
    italic = true,
    reverse = true,
    strikethrough = true,
    altfont = true,
    nocombine = true,
  }

  local function get_ns()
    local ns = meths.create_namespace('Test_set_hl')
    meths.set_hl_ns(ns)
    return ns
  end

  before_each(clear)

  it('validation', function()
    eq("Invalid 'blend': out of range",
      pcall_err(meths.set_hl, 0, 'Test_hl3', {fg='#FF00FF', blend=999}))
    eq("Invalid 'blend': expected Integer, got Array",
      pcall_err(meths.set_hl, 0, 'Test_hl3', {fg='#FF00FF', blend={}}))
  end)

  it("can set gui highlight", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, meths.get_hl_by_name('Test_hl', true))
  end)

  it("can set cterm highlight", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight2_config)
    eq(highlight2_result, meths.get_hl_by_name('Test_hl', false))
  end)

  it("can set empty cterm attr", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', { cterm = {} })
    eq({}, meths.get_hl_by_name('Test_hl', false))
  end)

  it("cterm attr defaults to gui attr", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq({
      bold = true,
      italic = true,
    }, meths.get_hl_by_name('Test_hl', false))
  end)

  it("can overwrite attr for cterm", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight3_config)
    eq(highlight3_result_gui, meths.get_hl_by_name('Test_hl', true))
    eq(highlight3_result_cterm, meths.get_hl_by_name('Test_hl', false))
  end)

  it("only allows one underline attribute #22371", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', {
      underdouble = true,
      underdotted = true,
      cterm = {
        underline = true,
        undercurl = true,
      },
    })
    eq({ undercurl = true }, meths.get_hl_by_name('Test_hl', false))
    eq({ underdotted = true }, meths.get_hl_by_name('Test_hl', true))
  end)

  it("can set a highlight in the global namespace", function()
    meths.set_hl(0, 'Test_hl', highlight2_config)
    eq('Test_hl        xxx cterm=underline,reverse ctermfg=8 ctermbg=15 gui=underline,reverse',
      exec_capture('highlight Test_hl'))

    meths.set_hl(0, 'Test_hl', { background = highlight_color.bg })
    eq('Test_hl        xxx guibg=#0032aa',
      exec_capture('highlight Test_hl'))

    meths.set_hl(0, 'Test_hl2', highlight3_config)
    eq('Test_hl2       xxx cterm=italic,reverse,strikethrough,altfont,nocombine ctermfg=8 ctermbg=15 gui=bold,underdashed,italic,reverse,strikethrough,altfont guifg=#ff0000 guibg=#0032aa',
      exec_capture('highlight Test_hl2'))

    -- Colors are stored with the name they are defined, but
    -- with canonical casing
    meths.set_hl(0, 'Test_hl3', { bg = 'reD', fg = 'bLue'})
    eq('Test_hl3       xxx guifg=Blue guibg=Red',
      exec_capture('highlight Test_hl3'))
  end)

  it("can modify a highlight in the global namespace", function()
    meths.set_hl(0, 'Test_hl3', { bg = 'red', fg = 'blue'})
    eq('Test_hl3       xxx guifg=Blue guibg=Red',
      exec_capture('highlight Test_hl3'))

    meths.set_hl(0, 'Test_hl3', { bg = 'red' })
    eq('Test_hl3       xxx guibg=Red',
      exec_capture('highlight Test_hl3'))

    meths.set_hl(0, 'Test_hl3', { ctermbg = 9, ctermfg = 12})
    eq('Test_hl3       xxx ctermfg=12 ctermbg=9',
      exec_capture('highlight Test_hl3'))

    meths.set_hl(0, 'Test_hl3', { ctermbg = 'red' , ctermfg = 'blue'})
    eq('Test_hl3       xxx ctermfg=12 ctermbg=9',
      exec_capture('highlight Test_hl3'))

    meths.set_hl(0, 'Test_hl3', { ctermbg = 9 })
    eq('Test_hl3       xxx ctermbg=9',
      exec_capture('highlight Test_hl3'))

    eq("Invalid highlight color: 'redd'",
      pcall_err(meths.set_hl, 0, 'Test_hl3', {fg='redd'}))

    eq("Invalid highlight color: 'bleu'",
      pcall_err(meths.set_hl, 0, 'Test_hl3', {ctermfg='bleu'}))

    meths.set_hl(0, 'Test_hl3', {fg='#FF00FF'})
    eq('Test_hl3       xxx guifg=#ff00ff',
      exec_capture('highlight Test_hl3'))

    eq("Invalid highlight color: '#FF00FF'",
      pcall_err(meths.set_hl, 0, 'Test_hl3', {ctermfg='#FF00FF'}))

    for _, fg_val in ipairs{ nil, 'NONE', 'nOnE', '', -1 } do
      meths.set_hl(0, 'Test_hl3', {fg = fg_val})
      eq('Test_hl3       xxx cleared',
        exec_capture('highlight Test_hl3'))
    end

    meths.set_hl(0, 'Test_hl3', {fg='#FF00FF', blend=50})
    eq('Test_hl3       xxx guifg=#ff00ff blend=50',
      exec_capture('highlight Test_hl3'))

  end)

  it("correctly sets 'Normal' internal properties", function()
    -- Normal has some special handling internally. #18024
    meths.set_hl(0, 'Normal', {fg='#000083', bg='#0000F3'})
    eq({foreground = 131, background = 243}, nvim("get_hl_by_name", 'Normal', true))
  end)

  it('does not segfault on invalid group name #20009', function()
    eq("Invalid highlight name: 'foo bar'", pcall_err(meths.set_hl, 0, 'foo bar', {bold = true}))
    assert_alive()
  end)
end)

describe('API: get highlight', function()
  local highlight_color = {
    fg = tonumber('0xff0000'),
    bg = tonumber('0x0032aa'),
    ctermfg = 8,
    ctermbg = 15,
  }
  local highlight1 = {
    bg = highlight_color.bg,
    fg = highlight_color.fg,
    bold = true, italic = true,
    cterm = {bold = true, italic = true},
  }
  local highlight2 = {
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    underline = true, reverse = true,
    cterm = {underline = true, reverse = true},
  }
  local highlight3_config = {
    bg = highlight_color.bg,
    fg = highlight_color.fg,
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    bold = true,
    italic = true,
    reverse = true,
    underdashed = true,
    strikethrough = true,
    altfont = true,
    cterm = {
      italic = true,
      reverse = true,
      strikethrough = true,
      altfont = true,
      nocombine = true,
    },
  }
  local highlight3_result = {
    bg = highlight_color.bg,
    fg = highlight_color.fg,
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    bold = true, italic = true, reverse = true, underdashed = true, strikethrough = true, altfont = true,
    cterm = {italic = true, nocombine = true, reverse = true, strikethrough = true, altfont = true}
  }

  local function get_ns()
    -- Test namespace filtering behavior
    local ns2 = meths.create_namespace('Another_namespace')
    meths.set_hl(ns2, 'Test_hl', { ctermfg = 23 })
    meths.set_hl(ns2, 'Test_another_hl', { link = 'Test_hl' })
    meths.set_hl(ns2, 'Test_hl_link', { link = 'Test_another_hl' })
    meths.set_hl(ns2, 'Test_another_hl_link', { link = 'Test_hl_link' })

    local ns = meths.create_namespace('Test_set_hl')
    meths.set_hl_ns(ns)

    return ns
  end

  before_each(clear)

  it('validation', function()
    eq("Invalid 'name': expected String, got Integer",
       pcall_err(meths.get_hl, 0, { name = 177 }))
    eq('Highlight id out of bounds', pcall_err(meths.get_hl, 0, { name = 'Test set hl' }))
  end)

  it('can get all highlights in current namespace', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', { bg = '#B4BEFE' })
    meths.set_hl(ns, 'Test_hl_link', { link = 'Test_hl' })
    eq({
      Test_hl = {
        bg = 11845374
      },
      Test_hl_link = {
        link = 'Test_hl'
      }
    }, meths.get_hl(ns, {}))
  end)

  it('can get gui highlight', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can get cterm highlight', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight2)
    eq(highlight2, meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can get empty cterm attr', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', { cterm = {} })
    eq({}, meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('cterm attr defaults to gui attr', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can overwrite attr for cterm', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight3_config)
    eq(highlight3_result, meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('only allows one underline attribute #22371', function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', {
      underdouble = true,
      underdotted = true,
      cterm = {
        underline = true,
        undercurl = true,
      },
    })
    eq({ underdotted = true, cterm = { undercurl = true} },
       meths.get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can get a highlight in the global namespace', function()
    meths.set_hl(0, 'Test_hl', highlight2)
    eq(highlight2, meths.get_hl(0, { name = 'Test_hl' }))

    meths.set_hl(0, 'Test_hl', { background = highlight_color.bg })
    eq({
      bg = 12970,
    }, meths.get_hl(0, { name = 'Test_hl' }))

    meths.set_hl(0, 'Test_hl2', highlight3_config)
    eq(highlight3_result, meths.get_hl(0, { name = 'Test_hl2' }))

    -- Colors are stored with the name they are defined, but
    -- with canonical casing
    meths.set_hl(0, 'Test_hl3', { bg = 'reD', fg = 'bLue' })
    eq({
      bg = 16711680,
      fg = 255,
    }, meths.get_hl(0, { name = 'Test_hl3' }))
  end)

  it('nvim_get_hl by id', function()
    local hl_id = meths.get_hl_id_by_name('NewHighlight')

    command(
      'hi NewHighlight cterm=underline ctermbg=green guifg=red guibg=yellow guisp=blue gui=bold'
    )
    eq({ fg = 16711680, bg = 16776960, sp = 255, bold = true,
         ctermbg = 10, cterm = { underline = true },
    }, meths.get_hl(0, { id = hl_id }))

    -- Test 0 argument
    eq('Highlight id out of bounds', pcall_err(meths.get_hl, 0, { id = 0 }))

    eq(
      "Invalid 'id': expected Integer, got String",
      pcall_err(meths.get_hl, 0, { id = 'Test_set_hl' })
    )

    -- Test all highlight properties.
    command('hi NewHighlight gui=underline,bold,italic,reverse,strikethrough,altfont,nocombine')
    eq({ fg = 16711680, bg = 16776960, sp = 255,
         altfont = true, bold = true, italic = true, nocombine = true, reverse = true, strikethrough = true, underline = true,
         ctermbg = 10, cterm = {underline = true},
    }, meths.get_hl(0, { id = hl_id }))

    -- Test undercurl
    command('hi NewHighlight gui=undercurl')
    eq({ fg = 16711680, bg = 16776960, sp = 255, undercurl = true,
         ctermbg = 10,
         cterm = {underline = true},
    }, meths.get_hl(0, { id = hl_id }))
  end)

  it('can correctly detect links', function()
    command('hi String guifg=#a6e3a1')
    command('hi link @string string')
    command('hi link @string.cpp @string')
    eq({ fg = 10937249 }, meths.get_hl(0, { name = 'String' }))
    eq({ link = 'String' }, meths.get_hl(0, { name = '@string' }))
    eq({ fg = 10937249 }, meths.get_hl(0, { name = '@string.cpp', link = false }))
  end)

  it('can get all attributes for a linked group', function()
    command('hi Bar guifg=red')
    command('hi Foo guifg=#00ff00 gui=bold,underline')
    command('hi! link Foo Bar')
    eq({ link = 'Bar', fg = tonumber('00ff00', 16), bold = true, underline = true }, meths.get_hl(0, { name = 'Foo', link = true }))
  end)

  it('can set link as well as other attributes', function()
    command('hi Bar guifg=red')
    local hl = { link = 'Bar', fg = tonumber('00ff00', 16), bold = true, cterm = { bold = true } }
    meths.set_hl(0, 'Foo', hl)
    eq(hl, meths.get_hl(0, { name = 'Foo', link = true }))
  end)

  it("doesn't contain unset groups", function()
    local id = meths.get_hl_id_by_name "@foobar.hubbabubba"
    ok(id > 0)

    local data = meths.get_hl(0, {})
    eq(nil, data["@foobar.hubbabubba"])
    eq(nil, data["@foobar"])

    command 'hi @foobar.hubbabubba gui=bold'
    data = meths.get_hl(0, {})
    eq({bold = true}, data["@foobar.hubbabubba"])
    eq(nil, data["@foobar"])

    -- @foobar.hubbabubba was explicitly cleared and thus shows up
    -- but @foobar was never touched, and thus doesn't
    command 'hi clear @foobar.hubbabubba'
    data = meths.get_hl(0, {})
    eq({}, data["@foobar.hubbabubba"])
    eq(nil, data["@foobar"])
  end)

  it('should return default flag', function()
    meths.set_hl(0, 'Tried', { fg = "#00ff00", default = true })
    eq({ fg = tonumber('00ff00', 16), default = true }, meths.get_hl(0, { name = 'Tried' }))
  end)
end)
