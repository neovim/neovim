local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eq = n.clear, t.eq
local command = n.command
local exec_capture = n.exec_capture
local api = n.api
local fn = n.fn
local pcall_err = t.pcall_err
local ok = t.ok
local assert_alive = n.assert_alive

describe('API: set highlight', function()
  local highlight_color = {
    fg = tonumber('0xff0000'),
    bg = tonumber('0x0032aa'),
    ctermfg = 8,
    ctermbg = 15,
  }
  local highlight1 = {
    bg = highlight_color.bg,
    fg = highlight_color.fg,
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
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    underline = true,
    reverse = true,
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
  local highlight3_result_gui = {
    bg = highlight_color.bg,
    fg = highlight_color.fg,
    bold = true,
    italic = true,
    reverse = true,
    underdashed = true,
    strikethrough = true,
    altfont = true,
  }
  local highlight3_result_cterm = {
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    italic = true,
    reverse = true,
    strikethrough = true,
    altfont = true,
    nocombine = true,
  }

  local function get_ns()
    local ns = api.nvim_create_namespace('Test_set_hl')
    api.nvim_set_hl_ns(ns)
    return ns
  end

  ---@param expect table<string, any>
  ---@param result table<string, any>
  ---@param cterm? boolean
  local function match(expect, result, cterm)
    for k, v in pairs(expect) do
      eq(v, cterm and result.cterm[k] or result[k])
    end
  end

  before_each(clear)

  it('validation', function()
    eq(
      "Invalid 'blend': out of range",
      pcall_err(api.nvim_set_hl, 0, 'Test_hl3', { fg = '#FF00FF', blend = 999 })
    )
    eq(
      "Invalid 'blend': expected Integer, got Array",
      pcall_err(api.nvim_set_hl, 0, 'Test_hl3', { fg = '#FF00FF', blend = {} })
    )
  end)

  it('can set gui highlight', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight1)
    match(highlight1, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can set cterm highlight', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight2_config)
    match(highlight2_result, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can set empty cterm attr', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', { cterm = {} })
    eq({}, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('cterm attr defaults to gui attr', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight1)
    match({
      bold = true,
      italic = true,
    }, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can overwrite attr for cterm #test', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight3_config)
    match(highlight3_result_gui, api.nvim_get_hl(ns, { name = 'Test_hl' }))
    match(highlight3_result_cterm, api.nvim_get_hl(ns, { name = 'Test_hl' }), true)
  end)

  it('only allows one underline attribute #22371', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', {
      underdouble = true,
      underdotted = true,
      cterm = {
        underline = true,
        undercurl = true,
      },
    })
    local result = api.nvim_get_hl(ns, { name = 'Test_hl' })
    match({ undercurl = true }, result, true)
    match({ underdotted = true }, result)
  end)

  it('can set all underline cterm attributes #31385', function()
    local ns = get_ns()
    local attrs = { 'underline', 'undercurl', 'underdouble', 'underdotted', 'underdashed' }
    for _, attr in ipairs(attrs) do
      api.nvim_set_hl(ns, 'Test_' .. attr, { cterm = { [attr] = true } })
      match({ [attr] = true }, api.nvim_get_hl(ns, { name = 'Test_' .. attr }), true)
    end
  end)

  it('can set a highlight in the global namespace', function()
    api.nvim_set_hl(0, 'Test_hl', highlight2_config)
    eq(
      'Test_hl        xxx cterm=underline,reverse ctermfg=8 ctermbg=15 gui=underline,reverse',
      exec_capture('highlight Test_hl')
    )

    api.nvim_set_hl(0, 'Test_hl', { background = highlight_color.bg })
    eq('Test_hl        xxx guibg=#0032aa', exec_capture('highlight Test_hl'))

    api.nvim_set_hl(0, 'Test_hl2', highlight3_config)
    eq(
      'Test_hl2       xxx cterm=italic,reverse,strikethrough,altfont,nocombine ctermfg=8 ctermbg=15 gui=bold,underdashed,italic,reverse,strikethrough,altfont guifg=#ff0000 guibg=#0032aa',
      exec_capture('highlight Test_hl2')
    )

    -- Colors are stored with the name they are defined, but
    -- with canonical casing
    api.nvim_set_hl(0, 'Test_hl3', { bg = 'reD', fg = 'bLue' })
    eq('Test_hl3       xxx guifg=Blue guibg=Red', exec_capture('highlight Test_hl3'))
  end)

  it('can modify a highlight in the global namespace', function()
    api.nvim_set_hl(0, 'Test_hl3', { bg = 'red', fg = 'blue' })
    eq('Test_hl3       xxx guifg=Blue guibg=Red', exec_capture('highlight Test_hl3'))

    api.nvim_set_hl(0, 'Test_hl3', { bg = 'red' })
    eq('Test_hl3       xxx guibg=Red', exec_capture('highlight Test_hl3'))

    api.nvim_set_hl(0, 'Test_hl3', { ctermbg = 9, ctermfg = 12 })
    eq('Test_hl3       xxx ctermfg=12 ctermbg=9', exec_capture('highlight Test_hl3'))

    api.nvim_set_hl(0, 'Test_hl3', { ctermbg = 'red', ctermfg = 'blue' })
    eq('Test_hl3       xxx ctermfg=12 ctermbg=9', exec_capture('highlight Test_hl3'))

    api.nvim_set_hl(0, 'Test_hl3', { ctermbg = 9 })
    eq('Test_hl3       xxx ctermbg=9', exec_capture('highlight Test_hl3'))

    eq(
      "Invalid highlight color: 'redd'",
      pcall_err(api.nvim_set_hl, 0, 'Test_hl3', { fg = 'redd' })
    )

    eq(
      "Invalid highlight color: 'bleu'",
      pcall_err(api.nvim_set_hl, 0, 'Test_hl3', { ctermfg = 'bleu' })
    )

    api.nvim_set_hl(0, 'Test_hl3', { fg = '#FF00FF' })
    eq('Test_hl3       xxx guifg=#ff00ff', exec_capture('highlight Test_hl3'))

    eq(
      "Invalid highlight color: '#FF00FF'",
      pcall_err(api.nvim_set_hl, 0, 'Test_hl3', { ctermfg = '#FF00FF' })
    )

    for _, fg_val in ipairs { nil, 'NONE', 'nOnE', '', -1 } do
      api.nvim_set_hl(0, 'Test_hl3', { fg = fg_val })
      eq('Test_hl3       xxx cleared', exec_capture('highlight Test_hl3'))
    end

    api.nvim_set_hl(0, 'Test_hl3', { fg = '#FF00FF', blend = 50 })
    eq('Test_hl3       xxx guifg=#ff00ff blend=50', exec_capture('highlight Test_hl3'))
  end)

  it("correctly sets 'Normal' internal properties", function()
    -- Normal has some special handling internally. #18024
    api.nvim_set_hl(0, 'Normal', { fg = '#000083', bg = '#0000F3' })
    eq({ fg = 131, bg = 243 }, api.nvim_get_hl(0, { name = 'Normal' }))
  end)

  it('does not segfault on invalid group name #20009', function()
    eq(
      "Invalid highlight name: 'foo bar'",
      pcall_err(api.nvim_set_hl, 0, 'foo bar', { bold = true })
    )
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
    bold = true,
    italic = true,
    cterm = { bold = true, italic = true },
  }
  local highlight2 = {
    ctermbg = highlight_color.ctermbg,
    ctermfg = highlight_color.ctermfg,
    underline = true,
    reverse = true,
    cterm = { underline = true, reverse = true },
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
    bold = true,
    italic = true,
    reverse = true,
    underdashed = true,
    strikethrough = true,
    altfont = true,
    cterm = {
      italic = true,
      nocombine = true,
      reverse = true,
      strikethrough = true,
      altfont = true,
    },
  }

  local function get_ns()
    -- Test namespace filtering behavior
    local ns2 = api.nvim_create_namespace('Another_namespace')
    api.nvim_set_hl(ns2, 'Test_hl', { ctermfg = 23 })
    api.nvim_set_hl(ns2, 'Test_another_hl', { link = 'Test_hl' })
    api.nvim_set_hl(ns2, 'Test_hl_link', { link = 'Test_another_hl' })
    api.nvim_set_hl(ns2, 'Test_another_hl_link', { link = 'Test_hl_link' })

    local ns = api.nvim_create_namespace('Test_set_hl')
    api.nvim_set_hl_ns(ns)

    return ns
  end

  before_each(clear)

  it('validation', function()
    eq(
      "Invalid 'name': expected String, got Integer",
      pcall_err(api.nvim_get_hl, 0, { name = 177 })
    )
    eq('Highlight id out of bounds', pcall_err(api.nvim_get_hl, 0, { name = 'Test set hl' }))
  end)

  it('nvim_get_hl with create flag', function()
    eq({}, api.nvim_get_hl(0, { name = 'Foo', create = false }))
    eq(0, fn.hlexists('Foo'))
    api.nvim_get_hl(0, { name = 'Bar', create = true })
    eq(1, fn.hlexists('Bar'))
    api.nvim_get_hl(0, { name = 'FooBar' })
    eq(1, fn.hlexists('FooBar'))
  end)

  it('can get all highlights in current namespace', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', { bg = '#B4BEFE' })
    api.nvim_set_hl(ns, 'Test_hl_link', { link = 'Test_hl' })
    eq({
      Test_hl = {
        bg = 11845374,
      },
      Test_hl_link = {
        link = 'Test_hl',
      },
    }, api.nvim_get_hl(ns, {}))
  end)

  it('can get gui highlight', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can get cterm highlight', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight2)
    eq(highlight2, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can get empty cterm attr', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', { cterm = {} })
    eq({}, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('cterm attr defaults to gui attr', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('can overwrite attr for cterm', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', highlight3_config)
    eq(highlight3_result, api.nvim_get_hl(ns, { name = 'Test_hl' }))
  end)

  it('only allows one underline attribute #22371', function()
    local ns = get_ns()
    api.nvim_set_hl(ns, 'Test_hl', {
      underdouble = true,
      underdotted = true,
      cterm = {
        underline = true,
        undercurl = true,
      },
    })
    eq(
      { underdotted = true, cterm = { undercurl = true } },
      api.nvim_get_hl(ns, { name = 'Test_hl' })
    )
  end)

  it('can get a highlight in the global namespace', function()
    api.nvim_set_hl(0, 'Test_hl', highlight2)
    eq(highlight2, api.nvim_get_hl(0, { name = 'Test_hl' }))

    api.nvim_set_hl(0, 'Test_hl', { background = highlight_color.bg })
    eq({
      bg = 12970,
    }, api.nvim_get_hl(0, { name = 'Test_hl' }))

    api.nvim_set_hl(0, 'Test_hl2', highlight3_config)
    eq(highlight3_result, api.nvim_get_hl(0, { name = 'Test_hl2' }))

    -- Colors are stored with the name they are defined, but
    -- with canonical casing
    api.nvim_set_hl(0, 'Test_hl3', { bg = 'reD', fg = 'bLue' })
    eq({
      bg = 16711680,
      fg = 255,
    }, api.nvim_get_hl(0, { name = 'Test_hl3' }))
  end)

  it('nvim_get_hl by id', function()
    local hl_id = api.nvim_get_hl_id_by_name('NewHighlight')

    command(
      'hi NewHighlight cterm=underline ctermbg=green guifg=red guibg=yellow guisp=blue gui=bold'
    )
    eq({
      fg = 16711680,
      bg = 16776960,
      sp = 255,
      bold = true,
      ctermbg = 10,
      cterm = { underline = true },
    }, api.nvim_get_hl(0, { id = hl_id }))

    -- Test 0 argument
    eq('Highlight id out of bounds', pcall_err(api.nvim_get_hl, 0, { id = 0 }))

    eq(
      "Invalid 'id': expected Integer, got String",
      pcall_err(api.nvim_get_hl, 0, { id = 'Test_set_hl' })
    )

    -- Test all highlight properties.
    command('hi NewHighlight gui=underline,bold,italic,reverse,strikethrough,altfont,nocombine')
    eq({
      fg = 16711680,
      bg = 16776960,
      sp = 255,
      altfont = true,
      bold = true,
      italic = true,
      nocombine = true,
      reverse = true,
      strikethrough = true,
      underline = true,
      ctermbg = 10,
      cterm = { underline = true },
    }, api.nvim_get_hl(0, { id = hl_id }))

    -- Test undercurl
    command('hi NewHighlight gui=undercurl')
    eq({
      fg = 16711680,
      bg = 16776960,
      sp = 255,
      undercurl = true,
      ctermbg = 10,
      cterm = { underline = true },
    }, api.nvim_get_hl(0, { id = hl_id }))
  end)

  it('can correctly detect links', function()
    command('hi String guifg=#a6e3a1 ctermfg=NONE')
    command('hi link @string string')
    command('hi link @string.cpp @string')
    eq({ fg = 10937249 }, api.nvim_get_hl(0, { name = 'String' }))
    eq({ link = 'String' }, api.nvim_get_hl(0, { name = '@string' }))
    eq({ fg = 10937249 }, api.nvim_get_hl(0, { name = '@string.cpp', link = false }))
  end)

  it('can get all attributes for a linked group', function()
    command('hi Bar guifg=red')
    command('hi Foo guifg=#00ff00 gui=bold,underline')
    command('hi! link Foo Bar')
    eq(
      { link = 'Bar', fg = tonumber('00ff00', 16), bold = true, underline = true },
      api.nvim_get_hl(0, { name = 'Foo', link = true })
    )
  end)

  it('can set link as well as other attributes', function()
    command('hi Bar guifg=red')
    local hl = { link = 'Bar', fg = tonumber('00ff00', 16), bold = true, cterm = { bold = true } }
    api.nvim_set_hl(0, 'Foo', hl)
    eq(hl, api.nvim_get_hl(0, { name = 'Foo', link = true }))
  end)

  it("doesn't contain unset groups", function()
    local id = api.nvim_get_hl_id_by_name '@foobar.hubbabubba'
    ok(id > 0)

    local data = api.nvim_get_hl(0, {})
    eq(nil, data['@foobar.hubbabubba'])
    eq(nil, data['@foobar'])

    command 'hi @foobar.hubbabubba gui=bold'
    data = api.nvim_get_hl(0, {})
    eq({ bold = true }, data['@foobar.hubbabubba'])
    eq(nil, data['@foobar'])

    -- @foobar.hubbabubba was explicitly cleared and thus shows up
    -- but @foobar was never touched, and thus doesn't
    command 'hi clear @foobar.hubbabubba'
    data = api.nvim_get_hl(0, {})
    eq({}, data['@foobar.hubbabubba'])
    eq(nil, data['@foobar'])
  end)

  it('should return default flag', function()
    api.nvim_set_hl(0, 'Tried', { fg = '#00ff00', default = true })
    eq({ fg = tonumber('00ff00', 16), default = true }, api.nvim_get_hl(0, { name = 'Tried' }))
  end)

  it('should not output empty gui and cterm #23474', function()
    api.nvim_set_hl(0, 'Foo', { default = true })
    api.nvim_set_hl(0, 'Bar', { default = true, fg = '#ffffff' })
    api.nvim_set_hl(0, 'FooBar', { default = true, fg = '#ffffff', cterm = { bold = true } })
    api.nvim_set_hl(
      0,
      'FooBarA',
      { default = true, fg = '#ffffff', cterm = { bold = true, italic = true } }
    )

    eq('Foo            xxx cleared', exec_capture('highlight Foo'))
    eq({ default = true }, api.nvim_get_hl(0, { name = 'Foo' }))
    eq('Bar            xxx guifg=#ffffff', exec_capture('highlight Bar'))
    eq('FooBar         xxx cterm=bold guifg=#ffffff', exec_capture('highlight FooBar'))
    eq('FooBarA        xxx cterm=bold,italic guifg=#ffffff', exec_capture('highlight FooBarA'))
  end)

  it('can override exist highlight group by force #20323', function()
    local white = tonumber('ffffff', 16)
    local green = tonumber('00ff00', 16)
    api.nvim_set_hl(0, 'Foo', { fg = white })
    api.nvim_set_hl(0, 'Foo', { fg = green, force = true })
    eq({ fg = green }, api.nvim_get_hl(0, { name = 'Foo' }))
    api.nvim_set_hl(0, 'Bar', { link = 'Comment', default = true })
    api.nvim_set_hl(0, 'Bar', { link = 'Foo', default = true, force = true })
    eq({ link = 'Foo', default = true }, api.nvim_get_hl(0, { name = 'Bar' }))
  end)
end)

describe('API: set/get highlight namespace', function()
  it('set/get highlight namespace', function()
    eq(0, api.nvim_get_hl_ns({}))
    local ns = api.nvim_create_namespace('')
    api.nvim_set_hl_ns(ns)
    eq(ns, api.nvim_get_hl_ns({}))
  end)

  it('set/get window highlight namespace', function()
    eq(-1, api.nvim_get_hl_ns({ winid = 0 }))
    local ns = api.nvim_create_namespace('')
    api.nvim_win_set_hl_ns(0, ns)
    eq(ns, api.nvim_get_hl_ns({ winid = 0 }))
  end)

  it('setting namespace takes priority over &winhighlight', function()
    command('set winhighlight=Visual:Search')
    n.insert('foobar')
    local ns = api.nvim_create_namespace('')
    api.nvim_win_set_hl_ns(0, ns)
    eq(ns, api.nvim_get_hl_ns({ winid = 0 }))
    command('enew') -- switching buffer keeps namespace #30904
    eq(ns, api.nvim_get_hl_ns({ winid = 0 }))
    command('set winhighlight=')
    eq(ns, api.nvim_get_hl_ns({ winid = 0 }))
    command('set winhighlight=Visual:Search')
    eq(ns, api.nvim_get_hl_ns({ winid = 0 }))
  end)
end)
