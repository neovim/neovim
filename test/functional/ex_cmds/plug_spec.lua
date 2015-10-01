local helpers = require('test.functional.helpers')
local clear, execute, nvim = helpers.clear, helpers.execute, helpers.nvim
local eq, eval = helpers.eq, helpers.eval
local feed = helpers.feed
local command = helpers.command

describe(':plug', function()

  before_each(function()
    clear()
    execute('set runtimepath=')
  end)

  it('adds a full path to the runtime', function()
    execute('plug /tmp')
    eq('/tmp', eval('&runtimepath'))
  end)

  it('adds a relative path to the runtime', function()
      execute('plug plugin')
      eq('bundle/plugin', eval('&runtimepath'))
  end)

  it('reacts to the value of "plugindir"', function()
      execute('set plugindir=bundles')
      execute('plug plugin')
      execute('set plugindir=/tmp')
      execute('plug plugin')
      eq('bundles/plugin,/tmp/plugin', eval('&runtimepath'))
  end)

  it('allows a prefix in the spec', function()
      execute('plug neovim/plugin')
      eq('bundle/plugin', eval('&runtimepath'))
  end)

end)
