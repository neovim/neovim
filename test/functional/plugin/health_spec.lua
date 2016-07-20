local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')

describe('health.vim', function()
  before_each(function()
    plugin_helpers.reset()
  end)

  it('should echo the results when using the basic functions', function()
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


  describe('CheckHealth', function()
    -- Run the health check and store important results
    -- Run it here because it may take awhile to complete, depending on the system
    helpers.execute([[CheckHealth!]])
    local report = helpers.curbuf_contents()
    local health_checkers = helpers.redir_exec("echo g:health_checkers")

    it('should find the default checker upon execution', function()
      -- helpers.execute([[CheckHealth!]])
      assert(string.find(health_checkers, "'health#nvim#check': v:true"))
    end)

    it('should alert the user that health#nvim#check is running', function()
      assert(string.find(report, '# Checking health'))
      assert(string.find(report, 'Checker health#nvim#check says:'))
      assert(string.find(report, 'Checking:'))
    end)
  end)
end)
