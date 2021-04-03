local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local meths = helpers.meths
local funcs = helpers.funcs
local pcall_err = helpers.pcall_err
local ok = helpers.ok
local assert_alive = helpers.assert_alive

describe('API: highlight',function()
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
    undercurl = true,
    underline = true,
    strikethrough = true,
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
    local err, emsg = pcall(meths.get_hl_by_id, 30000, false)
    eq(false, err)
    eq('Invalid highlight id: 30000', string.match(emsg, 'Invalid.*'))

    -- Test all highlight properties.
    command('hi NewHighlight gui=underline,bold,undercurl,italic,reverse,strikethrough')
    eq(expected_rgb2, nvim("get_hl_by_id", hl_id, true))

    -- Test nil argument.
    err, emsg = pcall(meths.get_hl_by_id, { nil }, false)
    eq(false, err)
    eq('Wrong type for argument 1 when calling nvim_get_hl_by_id, expecting Integer',
       string.match(emsg, 'Wrong.*'))

    -- Test 0 argument.
    err, emsg = pcall(meths.get_hl_by_id, 0, false)
    eq(false, err)
    eq('Invalid highlight id: 0',
       string.match(emsg, 'Invalid.*'))

    -- Test -1 argument.
    err, emsg = pcall(meths.get_hl_by_id, -1, false)
    eq(false, err)
    eq('Invalid highlight id: -1',
       string.match(emsg, 'Invalid.*'))

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
    local err, emsg = pcall(meths.get_hl_by_name , 'unknown_highlight', false)
    eq(false, err)
    eq('Invalid highlight name: unknown_highlight',
       string.match(emsg, 'Invalid.*'))

    -- Test nil argument.
    err, emsg = pcall(meths.get_hl_by_name , { nil }, false)
    eq(false, err)
    eq('Wrong type for argument 1 when calling nvim_get_hl_by_name, expecting String',
       string.match(emsg, 'Wrong.*'))

    -- Test empty string argument.
    err, emsg = pcall(meths.get_hl_by_name , '', false)
    eq(false, err)
    eq('Invalid highlight name: ',
       string.match(emsg, 'Invalid.*'))

    -- Test "standout" attribute. #8054
    eq({ underline = true, },
       meths.get_hl_by_name('cursorline', 0));
    command('hi CursorLine cterm=standout,underline term=standout,underline gui=standout,underline')
    command('set cursorline')
    eq({ underline = true, standout = true, },
       meths.get_hl_by_name('cursorline', 0));

  end)

  it('nvim_get_hl_id_by_name', function()
    -- precondition: use a hl group that does not yet exist
    eq('Invalid highlight name: Shrubbery', pcall_err(meths.get_hl_by_name, "Shrubbery", true))
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
    local err, _ = pcall(meths.buf_set_option, 1, 'undofile', false)
    eq(true, err)
    err, _ = pcall(meths.buf_set_option, 1, 'undolevels', -1)
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
    undercurl = true,
    underline = true,
    cterm = {
      italic = true,
      reverse = true,
      undercurl = true,
    }
  }
  local highlight3_result_gui = {
    background = highlight_color.bg,
    foreground = highlight_color.fg,
    bold = true,
    italic = true,
    reverse = true,
    undercurl = true,
    underline = true,
  }
  local highlight3_result_cterm = {
    background = highlight_color.ctermbg,
    foreground = highlight_color.ctermfg,
    italic = true,
    reverse = true,
    undercurl = true,
  }

  local function get_ns()
    local ns = meths.create_namespace('Test_set_hl')
    meths._set_hl_ns(ns)
    return ns
  end

  before_each(clear)

  it ("can set gui highlight", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq(highlight1, meths.get_hl_by_name('Test_hl', true))
  end)

  it ("can set cterm highlight", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight2_config)
    eq(highlight2_result, meths.get_hl_by_name('Test_hl', false))
  end)

  it ("cterm attr defaults to gui attr", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight1)
    eq({
      bold = true,
      italic = true,
    }, meths.get_hl_by_name('Test_hl', false))
  end)

  it ("can overwrite attr for cterm", function()
    local ns = get_ns()
    meths.set_hl(ns, 'Test_hl', highlight3_config)
    eq(highlight3_result_gui, meths.get_hl_by_name('Test_hl', true))
    eq(highlight3_result_cterm, meths.get_hl_by_name('Test_hl', false))
  end)
end)
