
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local ok = helpers.ok
local meths = helpers.meths


describe('highlight api',function()
  local expected_rgb = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red,
                          special = Screen.colors.Blue,
                          bold = true,
                        }

  local expected_cterm = { background = 10,
                          underline = true,
                        }

  before_each(function()
    clear()
    command("hi NewHighlight cterm=underline ctermbg=green guifg=red guibg=yellow guisp=blue gui=bold")
  end)

  it("nvim_get_hl_by_id", function()
    local hl_id = eval("hlID('NewHighlight')")

    eq(expected_cterm, nvim("get_hl_by_id", hl_id))

    command('set termguicolors')
    hl_id = eval("hlID('NewHighlight')")
    eq(expected_rgb, nvim("get_hl_by_id", hl_id))

    -- assume there is no hl with id 30000
    local err, emsg = pcall(meths.get_hl_by_id, 30000)
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight id') ~= nil)
  end)

  it("nvim_get_hl_by_name", function()
    local expected_normal = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red }

    -- test "Normal" hl defaults
    eq({}, nvim("get_hl_by_name", 'Normal'))

    eq(expected_cterm, nvim("get_hl_by_name", 'NewHighlight'))
    command('set termguicolors')
    eq(expected_rgb, nvim("get_hl_by_name", 'NewHighlight'))

    command('hi Normal guifg=red guibg=yellow')
    eq(expected_normal, nvim("get_hl_by_name", 'Normal'))

    local err, emsg = pcall(meths.get_hl_by_name , 'unknown_highlight')
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight name') ~= nil)
  end)
end)
