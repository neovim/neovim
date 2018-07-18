local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local meths = helpers.meths

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
    command('hi NewHighlight gui=underline,bold,undercurl,italic,reverse')
    eq(expected_rgb2, nvim("get_hl_by_id", hl_id, true))

    -- Test nil argument.
    err, emsg = pcall(meths.get_hl_by_id, { nil }, false)
    eq(false, err)
    eq('Wrong type for argument 1, expecting Integer',
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
    eq('Wrong type for argument 1, expecting String',
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
end)
