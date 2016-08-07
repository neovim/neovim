local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')

describe('health.vim', function()
  before_each(function()
    plugin_helpers.reset()
  end)

  it('reports results', function()
    helpers.execute("call health#report_start('Foo')")
    local report = helpers.redir_exec([[call health#report_start('Check Bar')]])
      .. helpers.redir_exec([[call health#report_ok('Bar status')]])
      .. helpers.redir_exec([[call health#report_ok('Other Bar status')]])
      .. helpers.redir_exec([[call health#report_warn('Zub')]])
      .. helpers.redir_exec([[call health#report_start('Baz')]])
      .. helpers.redir_exec([[call health#report_warn('Zim', ['suggestion 1', 'suggestion 2'])]])

    local expected_contents = {
      'Checking: Check Bar',
      'SUCCESS: Bar status',
      'WARNING: Zub',
      'SUGGESTIONS:',
      '- suggestion 1',
      '- suggestion 2'
    }

    for _, content in ipairs(expected_contents) do
      assert(string.find(report, content))
    end
  end)


  describe(':CheckHealth', function()
    -- Run it here because it may be slow, depending on the system.
    helpers.execute([[CheckHealth!]])
    local report = helpers.curbuf_contents()
    local health_checkers = helpers.redir_exec("echo g:health_checkers")

    it('finds the default checker', function()
      assert(string.find(health_checkers, "'health#nvim#check': v:true"))
    end)

    it('prints a header with the name of the checker', function()
      assert(string.find(report, 'health#nvim#check'))
    end)
  end)

  it('allows users to disable checkers', function()
    helpers.execute("call health#disable_checker('health#nvim#check')")
    helpers.execute("CheckHealth!")
    local health_checkers = helpers.redir_exec("echo g:health_checkers")

    assert(string.find(health_checkers, "'health#nvim#check': v:false"))
  end)
end)
