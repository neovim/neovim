local helpers = require('test.functional.helpers')(after_each)
local global_helpers = require('test.helpers')
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local curbuf_contents = helpers.curbuf_contents
local command = helpers.command
local eq = helpers.eq
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
    eq("ERROR: $VIM is invalid: zub",
       string.match(curbuf_contents(), "ERROR: $VIM .* zub"))
  end)
  it('completions can be listed via getcompletion()', function()
    clear()
    eq('nvim', getcompletion('nvim', 'checkhealth')[1])
    eq('provider', getcompletion('prov', 'checkhealth')[1])
    eq('vim.lsp', getcompletion('vim.ls', 'checkhealth')[1])
  end)
end)

describe('health.vim', function()
  before_each(function()
    clear{args={'-u', 'NORC'}}
    -- Provides functions:
    --    health#broken#check()
    --    health#success1#check()
    --    health#success2#check()
    command("set runtimepath+=test/functional/fixtures")
  end)

  describe(":checkhealth", function()
    it("functions health#report_*() render correctly", function()
      command("checkhealth full_render")
      helpers.expect([[

      full_render: health#full_render#check
      ========================================================================
      ## report 1
        - OK: life is fine
        - WARNING: no what installed
          - ADVICE:
            - pip what
            - make what

      ## report 2
        - INFO: stuff is stable
        - ERROR: why no hardcopy
          - ADVICE:
            - :help |:hardcopy|
            - :help |:TOhtml|
      ]])
    end)

    it("concatenates multiple reports", function()
      command("checkhealth success1 success2 test_plug")
      helpers.expect([[

        success1: health#success1#check
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here

        success2: health#success2#check
        ========================================================================
        ## another 1
          - OK: ok

        test_plug: require("test_plug.health").check()
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here
        ]])
    end)

    it("lua plugins, skips vimscript healthchecks with the same name", function()
      command("checkhealth test_plug")
      -- Existing file in test/functional/fixtures/lua/test_plug/autoload/health/test_plug.vim
      -- and the Lua healthcheck is used instead.
      helpers.expect([[

        test_plug: require("test_plug.health").check()
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here
        ]])
    end)

    it("lua plugins submodules", function()
      command("checkhealth test_plug.submodule")
      helpers.expect([[

        test_plug.submodule: require("test_plug.submodule.health").check()
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here
        ]])
    end)

    it("lua plugins submodules with expression '*'", function()
      command("checkhealth test_plug*")
      local buf_lines = helpers.curbuf('get_lines', 0, -1, true)
      -- avoid dealing with path separators
      local received = table.concat(buf_lines, '\n', 1, #buf_lines - 2)
      local expected = helpers.dedent([[

        test_plug: require("test_plug.health").check()
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here

        test_plug.submodule: require("test_plug.submodule.health").check()
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here

        test_plug.submodule_failed: require("test_plug.submodule_failed.health").check()
        ========================================================================
          - ERROR: Failed to run healthcheck for "test_plug.submodule_failed" plugin. Exception:
            function health#check, line 24]])
      eq(expected, received)
    end)

    it("gracefully handles broken healthcheck", function()
      command("checkhealth broken")
      helpers.expect([[

        broken: health#broken#check
        ========================================================================
          - ERROR: Failed to run healthcheck for "broken" plugin. Exception:
            function health#check[24]..health#broken#check, line 1
            caused an error
        ]])
    end)

    it("gracefully handles broken lua healthcheck", function()
      command("checkhealth test_plug.submodule_failed")
      local buf_lines = helpers.curbuf('get_lines', 0, -1, true)
      local received = table.concat(buf_lines, '\n', 1, #buf_lines - 2)
      -- avoid dealing with path separators
      local lua_err = "attempt to perform arithmetic on a nil value"
      local last_line = buf_lines[#buf_lines - 1]
      assert(string.find(last_line, lua_err) ~= nil, "Lua error not present")

      local expected = global_helpers.dedent([[

        test_plug.submodule_failed: require("test_plug.submodule_failed.health").check()
        ========================================================================
          - ERROR: Failed to run healthcheck for "test_plug.submodule_failed" plugin. Exception:
            function health#check, line 24]])
      eq(expected, received)
    end)

    it("highlights OK, ERROR", function()
      local screen = Screen.new(72, 10)
      screen:attach()
      screen:set_default_attr_ids({
        Ok = { foreground = Screen.colors.Grey3, background = 6291200 },
        Error = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
        Heading = { bold=true, foreground=Screen.colors.Magenta },
        Heading2 = { foreground = Screen.colors.SlateBlue },
        Bar = { foreground = 0x6a0dad },
        Bullet = { bold=true, foreground=Screen.colors.Brown },
      })
      command("checkhealth foo success1")
      command("1tabclose")
      command("set laststatus=0")
      screen:expect{grid=[[
        ^                                                                        |
        {Heading:foo: }                                                                   |
        {Bar:========================================================================}|
        {Bullet:  -} {Error:ERROR:} No healthcheck found for "foo" plugin.                       |
                                                                                |
        {Heading:success1: health#success1#check}                                         |
        {Bar:========================================================================}|
        {Heading2:##}{Heading: report 1}                                                             |
        {Bullet:  -} {Ok:OK:} everything is fine                                              |
                                                                                |
      ]]}
    end)

    it("gracefully handles invalid healthcheck", function()
      command("checkhealth non_existent_healthcheck")
      -- luacheck: ignore 613
      helpers.expect([[

        non_existent_healthcheck: 
        ========================================================================
          - ERROR: No healthcheck found for "non_existent_healthcheck" plugin.
        ]])
    end)
  end)
end)
