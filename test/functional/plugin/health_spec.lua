local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local curbuf_contents = helpers.curbuf_contents
local command = helpers.command
local eq, neq, matches = helpers.eq, helpers.neq, helpers.matches
local getcompletion = helpers.funcs.getcompletion

describe(':checkhealth', function()
  it("detects invalid $VIMRUNTIME", function()
    clear({
      env={ VIMRUNTIME='bogus', },
    })
    local status, err = pcall(command, 'checkhealth')
    eq(false, status)
    eq('Invalid $VIMRUNTIME: bogus', string.match(err, 'Invalid.*'))
  end)
  it("detects invalid 'runtimepath'", function()
    clear()
    command('set runtimepath=bogus')
    local status, err = pcall(command, 'checkhealth')
    eq(false, status)
    eq("Invalid 'runtimepath'", string.match(err, 'Invalid.*'))
  end)
  it("detects invalid $VIM", function()
    clear()
    -- Do this after startup, otherwise it just breaks $VIMRUNTIME.
    command("let $VIM='zub'")
    command("checkhealth nvim")
    matches('ERROR $VIM .* zub', curbuf_contents())
  end)
  it('completions can be listed via getcompletion()', function()
    clear()
    eq('nvim', getcompletion('nvim', 'checkhealth')[1])
    eq('provider', getcompletion('prov', 'checkhealth')[1])
    eq('vim.lsp', getcompletion('vim.ls', 'checkhealth')[1])
    neq('vim', getcompletion('^vim', 'checkhealth')[1])  -- should not complete vim.health
  end)
end)

describe('health.vim', function()
  before_each(function()
    clear{args={'-u', 'NORC'}}
    -- Provides healthcheck functions
    command("set runtimepath+=test/functional/fixtures")
  end)

  describe(":checkhealth", function()
    it("functions report_*() render correctly", function()
      command("checkhealth full_render")
      helpers.expect([[

      ==============================================================================
      test_plug.full_render: require("test_plug.full_render.health").check()

      report 1 ~
      - OK life is fine
      - WARNING no what installed
        - ADVICE:
          - pip what
          - make what

      report 2 ~
      - stuff is stable
      - ERROR why no hardcopy
        - ADVICE:
          - :help |:hardcopy|
          - :help |:TOhtml|
      ]])
    end)

    it("concatenates multiple reports", function()
      command("checkhealth success1 success2 test_plug")
      helpers.expect([[

        ==============================================================================
        test_plug: require("test_plug.health").check()

        report 1 ~
        - OK everything is fine

        report 2 ~
        - OK nothing to see here

        ==============================================================================
        test_plug.success1: require("test_plug.success1.health").check()

        report 1 ~
        - OK everything is fine

        report 2 ~
        - OK nothing to see here

        ==============================================================================
        test_plug.success2: require("test_plug.success2.health").check()

        another 1 ~
        - OK ok
        ]])
    end)

    it("lua plugins submodules", function()
      command("checkhealth test_plug.submodule")
      helpers.expect([[

        ==============================================================================
        test_plug.submodule: require("test_plug.submodule.health").check()

        report 1 ~
        - OK everything is fine

        report 2 ~
        - OK nothing to see here
        ]])
    end)

    it("... including empty reports", function()
      command("checkhealth test_plug.submodule_empty")
      helpers.expect([[

      ==============================================================================
      test_plug.submodule_empty: require("test_plug.submodule_empty.health").check()

      - ERROR The healthcheck report for "test_plug.submodule_empty" plugin is empty.
      ]])
    end)

    it("highlights OK, ERROR", function()
      local screen = Screen.new(50, 12)
      screen:attach()
      screen:set_default_attr_ids({
        Ok = { foreground = Screen.colors.LightGreen },
        Error = { foreground = Screen.colors.Red },
        Heading = { foreground = tonumber('0x6a0dad') },
        Bar = { foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGrey },
      })
      command("checkhealth foo success1")
      command("set nofoldenable nowrap laststatus=0")
      screen:expect{grid=[[
        ^                                                  |
        {Bar:──────────────────────────────────────────────────}|
        {Heading:foo: }                                             |
                                                          |
        - {Error:ERROR} No healthcheck found for "foo" plugin.    |
                                                          |
        {Bar:──────────────────────────────────────────────────}|
        {Heading:test_plug.success1: require("test_plug.success1.he}|
                                                          |
        {Heading:report 1}                                          |
        - {Ok:OK} everything is fine                           |
                                                          |
      ]]}
    end)

    it("fold healthchecks", function()
      local screen = Screen.new(50, 7)
      screen:attach()
      command("checkhealth foo success1")
      command("set nowrap laststatus=0")
      screen:expect{grid=[[
        ^                                                  |
        ──────────────────────────────────────────────────|
        +WE  4 lines: foo: ·······························|
        ──────────────────────────────────────────────────|
        +--  8 lines: test_plug.success1: require("test_pl|
        ~                                                 |
                                                          |
      ]]}
    end)

    it("gracefully handles invalid healthcheck", function()
      command("checkhealth non_existent_healthcheck")
      -- luacheck: ignore 613
      helpers.expect([[

        ==============================================================================
        non_existent_healthcheck: 

        - ERROR No healthcheck found for "non_existent_healthcheck" plugin.
        ]])
    end)

    it("does not use vim.health as a healtcheck", function()
      -- vim.health is not a healthcheck
      command("checkhealth vim")
      helpers.expect([[
      ERROR: No healthchecks found.]])
    end)
  end)
end)

describe(':checkhealth provider', function()
  it("works correctly with a wrongly configured 'shell'", function()
    clear()
    command([[set shell=echo\ WRONG!!!]])
    command('let g:loaded_perl_provider = 0')
    command('let g:loaded_python3_provider = 0')
    command('checkhealth provider')
    eq(nil, string.match(curbuf_contents(), 'WRONG!!!'))
  end)
end)
