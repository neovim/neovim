local helpers = require('test.functional.helpers')(after_each)
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

  it("health#report_*()", function()
    helpers.source([[
      let g:health_report = execute([
        \ "call health#report_start('Check Bar')",
        \ "call health#report_ok('Bar status')",
        \ "call health#report_ok('Other Bar status')",
        \ "call health#report_warn('Zub')",
        \ "call health#report_start('Baz')",
        \ "call health#report_warn('Zim', ['suggestion 1', 'suggestion 2'])"
        \ ])
    ]])
    local result = helpers.eval("g:health_report")

    helpers.eq(helpers.dedent([[


      ## Check Bar
        - OK: Bar status
        - OK: Other Bar status
        - WARNING: Zub

      ## Baz
        - WARNING: Zim
          - ADVICE:
            - suggestion 1
            - suggestion 2]]),
      result)
  end)


  describe(":checkhealth", function()
    it("concatenates multiple reports", function()
      command("checkhealth success1 success2")
      helpers.expect([[

        health#success1#check
        ========================================================================
        ## report 1
          - OK: everything is fine

        ## report 2
          - OK: nothing to see here

        health#success2#check
        ========================================================================
        ## another 1
          - OK: ok
        ]])
    end)

    it("gracefully handles broken healthcheck", function()
      command("checkhealth broken")
      helpers.expect([[

        health#broken#check
        ========================================================================
          - ERROR: Failed to run healthcheck for "broken" plugin. Exception:
            function health#check[21]..health#broken#check, line 1
            caused an error
        ]])
    end)

    it("highlights OK, ERROR", function()
      local screen = Screen.new(72, 10)
      screen:attach()
      screen:set_default_attr_ids({
        Ok = { foreground = Screen.colors.Grey3, background = 6291200 },
        Error = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
        Heading = { bold=true, foreground=Screen.colors.Magenta },
        Heading2 = { foreground = Screen.colors.SlateBlue },
        Bar = { foreground=Screen.colors.Purple },
        Bullet = { bold=true, foreground=Screen.colors.Brown },
      })
      command("checkhealth foo success1")
      command("1tabclose")
      command("set laststatus=0")
      screen:expect{grid=[[
        ^                                                                        |
        {Heading:health#foo#check}                                                        |
        {Bar:========================================================================}|
        {Bullet:  -} {Error:ERROR:} No healthcheck found for "foo" plugin.                       |
                                                                                |
        {Heading:health#success1#check}                                                   |
        {Bar:========================================================================}|
        {Heading2:##}{Heading: report 1}                                                             |
        {Bullet:  -} {Ok:OK:} everything is fine                                              |
                                                                                |
      ]]}
    end)

    it("gracefully handles invalid healthcheck", function()
      command("checkhealth non_existent_healthcheck")
      helpers.expect([[

        health#non_existent_healthcheck#check
        ========================================================================
          - ERROR: No healthcheck found for "non_existent_healthcheck" plugin.
        ]])
    end)
  end)
end)
