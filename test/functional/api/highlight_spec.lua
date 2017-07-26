
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local ok = helpers.ok
local meths = helpers.meths


describe('highlight api', function()

  before_each(function()
    clear('--cmd', 'set termguicolors')
  end)

  it("nvim_get_hl_by_id", function()
    local expected_hl = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red,
                          special = Screen.colors.Blue
                        }

    command('hi NewHighlight guifg=red guibg=yellow guisp=blue')

    local hl_id = eval("hlID('NewHighlight')")
    eq(expected_hl, nvim("get_hl_by_id", hl_id))

    -- assume there is no hl with 30000
    local err, emsg = pcall(meths.get_hl_by_id, 30000)
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight id') ~= nil)
  end)

  it("nvim_get_hl_by_name", function()
    local expected_hl = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red }

    -- test "Normal" hl defaults
    eq({}, nvim("get_hl_by_name", 'Normal'))

    command('hi NewHighlight guifg=red guibg=yellow')
    eq(expected_hl, nvim("get_hl_by_name", 'NewHighlight'))

    command('hi Normal guifg=red guibg=yellow')
    eq(expected_hl, nvim("get_hl_by_name", 'Normal'))
    local err, emsg = pcall(meths.get_hl_by_name , 'unknown_highlight')
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight name') ~= nil)
  end)



end)

