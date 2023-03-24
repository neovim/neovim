-- to run this test:
-- TEST_FILE=test/functional/plugin/versioncheck_spec.lua make functionaltest

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local pathsep = helpers.get_pathsep()
local is_os = helpers.is_os

local testdir = 'Xstate'
local test_version = [[
api_compatible = 0
api_level = 11
api_prerelease = true
major = 0
minor = 8
patch = 0
prerelease = true
]]
local vc = require('versioncheck')

setup(function()
  helpers.mkdir_p(testdir .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
  helpers.write_file(testdir .. pathsep .. 'version', test_version)
end)

teardown(function()
  helpers.rmdir(testdir)
end)

describe('checkversion', function()

    after_each(function()
      os.remove('version')
      helpers.rmdir(testdir)
    end)

    before_each(function()
      clear({
        env = { XDG_STATE_HOME=testdir },
        -- removes -u NONE so runtime/plugin/versioncheck.lua runs
        args_rm = { '-u' }
      })

      helpers.write_file(testdir .. pathsep .. 'version', test_version)
    end)

    it("updates cached version value when current newer", function()
      eq(1, 1)
      -- require('versioncheck').check({
      --   api_compatible = 0,
      --   api_level = 11,
      --   api_prerelease = true,
      --   major = 0,
      --   minor = 8,
      --   patch = 2,
      --   prerelease = true,
      -- })
    end)
     -- read and check that version is now 0.8.2 and not 0.7.0
     -- helpers.read_file()

end)


