-- FIXME: ideally we'll eventually have tests for the entire startup sequence
-- described at ":help initialization"
-- For now, I'm just adding tests to ensure an init.lua gets loaded correctly

local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')

local clear = helpers.clear
local set_session = helpers.set_session
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir

local cwd = lfs.currentdir()
local fakehome = cwd..'/tmp-test-fakehome'

before_each(function()
  -- create a fake home directory
  mkdir(fakehome)
  mkdir(fakehome..'/.config')
  mkdir(fakehome..'/.config/nvim')

  -- start a new session that points to our fake $HOME dir
  clear{env={HOME=fakehome}}
end)

after_each(function()
  -- clean up the fake home directory
  rmdir(fakehome)

  -- destroy any previous session
  set_session(nil, false)
end)

describe('init.lua rc file', function()
  it('is loaded instead of init.vim', function()
    -- TODO: prove that init.lua is loaded
  end)
end)
