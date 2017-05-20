
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim = helpers.clear, helpers.nvim
local Screen = require('test.functional.ui.screen')
local eq, eval = helpers.eq, helpers.eval
local command = helpers.command
local ok = helpers.ok
local meths = helpers.meths


describe('highlight api', function()

  before_each(clear)

  it("from_id", function()
    local expected_hl = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red,
                          special = Screen.colors.Blue
                        }

    command('hi NewHighlight guifg=red guibg=yellow guisp=blue')

    local hl_id = eval("hlID('NewHighlight')")
    eq(nvim("hl_from_id", hl_id), expected_hl)

    -- 'Normal' group must be id 0
    eq(nvim("hl_from_id", 0), {})

    -- assume there is no hl with 30000
    local err, emsg = pcall(meths.hl_from_id, 30000)
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight id') ~= nil)
  end)

  it("from_name", function()
    local expected_hl = { background = Screen.colors.Yellow,
                          foreground = Screen.colors.Red }

    command('hi NewHighlight guifg=red guibg=yellow')
    eq(nvim("hl_from_name", 'NewHighlight'), expected_hl)

    eq(nvim("hl_from_name", 'Normal'), {})
    local err, emsg = pcall(meths.hl_from_name , 'unknown_highlight')
    eq(false, err)
    ok(string.find(emsg, 'Invalid highlight name') ~= nil)
  end)

end)

