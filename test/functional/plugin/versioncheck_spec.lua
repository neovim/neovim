local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local pathsep = helpers.get_pathsep()
local write_file = helpers.write_file
local mkdir_p = helpers.mkdir_p
local read_file = helpers.read_file
local meths = helpers.meths

local testdir = 'Xtest-versioncheck'
local old_news = read_file('test/functional/fixtures/news.txt')

setup(function()
  mkdir_p(testdir)
  write_file(testdir .. pathsep .. 'news.txt', old_news)
end)

teardown(function()
  helpers.rmdir(testdir)
end)

describe('versioncheck module', function()
  before_each(function()
    -- remove -u NONE so runtime/plugin/versioncheck.lua runs
    clear({ args_rm = { '-u' } })
    write_file(testdir .. pathsep .. 'news.txt', old_news)
  end)

  after_each(function()
    os.remove(testdir .. pathsep .. 'news.txt')
  end)

  it('loads', function()
    eq(true, meths.get_var('loaded_versioncheck'))
  end)

  it('can be disabled globally', function()
    meths.set_var('loaded_versioncheck', false)
    eq(false, meths.get_var('loaded_versioncheck'))
  end)

  it('does not run when nvim run non-interactively', function()
    pending()
  end)

  it('is disabled when vim.version() is not pre-release', function()
    pending()
  end)
end)
