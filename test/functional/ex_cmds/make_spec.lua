local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eval = helpers.eval
local has_powershell = helpers.has_powershell
local matches = helpers.matches
local nvim = helpers.nvim
local nvim_dir = helpers.nvim_dir

describe(':make', function()
  clear()
  before_each(function ()
    clear()
  end)

  describe('with powershell', function()
    if not has_powershell() then
      pending("not tested; powershell was not found", function() end)
      return
    end
    before_each(function ()
      helpers.set_shell_powershell()
    end)

    it('captures stderr & non zero exit code #14349', function ()
      nvim('set_option', 'makeprg', nvim_dir..'/shell-test foo')
      local out = eval('execute("make")')
      -- Make program exit code correctly captured
      matches('\nshell returned 3', out)
      -- Error message is captured in the file and printed in the footer
      matches('\n.*%: Unknown first argument%: foo', out)
    end)

    it('captures stderr & zero exit code #14349', function ()
      nvim('set_option', 'makeprg', nvim_dir..'/shell-test')
      local out = eval('execute("make")')
      -- Ensure there are no "shell returned X" messages between
	  -- command and last line (indicating zero exit)
      matches('LastExitCode%s+[(]', out)
      matches('\n.*%: ready [$]', out)
    end)

  end)

end)
