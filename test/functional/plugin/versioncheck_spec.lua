local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local pathsep = helpers.get_pathsep()
local write_file = helpers.write_file
local mkdir_p = helpers.mkdir_p
local rmdir = helpers.rmdir
local is_os = helpers.is_os
local meths = helpers.meths

-- local testdir = 'Xtest-versioncheck'
-- local vc = require('versioncheck')

-- luacheck: push ignore
local old_news = [[
*news.txt*    Nvim


                            NVIM REFERENCE MANUAL


Notable changes in Nvim 0.10 from 0.9                                    *news*

For changes in Nvim 0.9, see |news-0.9|.

                                       Type |gO| to see the table of contents.

==============================================================================
BREAKING CHANGES                                                *news-breaking*

The following changes may require adaptations in user config or plugins.

• 

==============================================================================
ADDED FEATURES                                                     *news-added*

The following new APIs or features were added.

• 

==============================================================================
CHANGED FEATURES                                                 *news-changed*

The following changes to existing APIs or features add new behavior.

• 

==============================================================================
REMOVED FEATURES                                                 *news-removed*

The following deprecated functions or APIs were removed.

• 

==============================================================================
DEPRECATIONS                                                *news-deprecations*

The following functions are now deprecated and will be removed in the next
release.

• ...


 vim:tw=78:ts=8:sw=2:et:ft=help:norl:
]]
-- luacheck: pop

describe('versioncheck', function()
  local xstate = 'Xstate'

  setup(function()
    local dir = xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim')
    mkdir_p(dir)
  end)

  teardown(function()
    rmdir(xstate)
  end)

  before_each(function()
    write_file('news.txt', old_news)
    clear({
      -- remove -u NONE so runtime/plugin/versioncheck.lua runs
      args_rm = { '-u' },
      env = { XDG_STATE_HOME = xstate },
    })
  end)

  after_each(function()
    os.remove('news.txt')
    rmdir(xstate)
  end)

  it('loads', function()
    eq(true, meths.get_var('loaded_versioncheck'))
  end)

  -- it('can be disabled globally', function()
  --   meths.set_var('loaded_versioncheck', false)
  --   eq(false, meths.get_var('loaded_versioncheck'))
  -- end)

  it('does not run when nvim run non-interactively', function()
    pending()
  end)

  it('is disabled when vim.version() is not pre-release', function()
    pending()
  end)
end)
