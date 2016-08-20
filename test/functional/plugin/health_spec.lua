local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')

describe('health.vim', function()
  before_each(function()
    plugin_helpers.reset()
    -- Provides functions:
    --    health#broken#check()
    --    health#success1#check()
    --    health#success2#check()
    helpers.execute("set runtimepath+=test/functional/fixtures")
  end)

  it("reports", function()
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
        - SUCCESS: Bar status
        - SUCCESS: Other Bar status
        - WARNING: Zub

      ## Baz
        - WARNING: Zim
            - SUGGESTIONS:
              - suggestion 1
              - suggestion 2]]),
      result)
  end)


  describe(":CheckHealth", function()
    it("concatenates multiple reports", function()
      helpers.execute("CheckHealth success1 success2")
      helpers.expect([[
        health#success1#check
        ================================================================================

        ## report 1
          - SUCCESS: everything is fine

        ## report 2
          - SUCCESS: nothing to see here

        health#success2#check
        ================================================================================

        ## another 1
          - SUCCESS: ok]])
    end)

    it("gracefully handles broken healthcheck", function()
      helpers.execute("CheckHealth broken")
      helpers.expect([[
        health#broken#check
        ================================================================================
          - ERROR: Failed to run healthcheck for "broken" plugin. Exception:
            caused an error]])
    end)

    it("gracefully handles invalid healthcheck", function()
      helpers.execute("CheckHealth non_existent_healthcheck")
      helpers.expect([[
        health#non_existent_healthcheck#check
        ================================================================================
          - ERROR: No healthcheck found for "non_existent_healthcheck" plugin.]])
    end)
  end)
end)
