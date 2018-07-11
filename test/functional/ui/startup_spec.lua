-- FIXME: ideally we'll eventually have tests for the entire startup sequence
-- described at ":help initialization"
-- For now, I'm just adding tests to ensure an init.lua gets loaded correctly

local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
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

  -- NOTE: we can't just call clear() to start a new nvim session because the
  -- tests need to write out .nvimrc files and such before nvim starts up.
  -- See begin_session() for how nvim is spawned.
end)

after_each(function()
  -- clean up the fake home directory
  rmdir(fakehome)

  -- destroy any previous session
  set_session(nil, false)
end)

local function writefile(path, data)
  local f = io.open(fakehome..'/'..path, 'w')
  f:write(data)
  f:write('\n')
  f:close()
end

local function begin_session()
  -- invoke clear() with our newly crafted home dir
  clear{env={HOME=fakehome}}
end

describe('init.lua rc file', function()
  it('is loaded instead of init.vim', function()
    -- write out a bunch of init scripts that will each define a specific
    -- global variable we can look for
    writefile('.config/nvim/init.lua', [[
          vim.api.nvim_set_var('reached_init_lua', 1)
    ]])
    writefile('.config/nvim/init.vim', [[
          let g:reached_init_vim = 1
    ]])

    begin_session()

    -- prove that init.lua was executed
    eq(1, eval('get(g:, "reached_init_lua", 0)'))

    -- prove that we _didn't_ execute init.vim
    eq(0, eval('get(g:, "reached_init_vim", 0)'))

    -- $MYVIMRC should be set to the name of the init.lua
    eq(fakehome..'/.config/nvim/init.lua', eval('$MYVIMRC'))
  end)
end)
