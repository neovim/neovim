local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')
local Screen = require('test.functional.ui.screen')

local command = helpers.command
local meths = helpers.meths
local feed = helpers.feed
local eq = helpers.eq

local reset = plugin_helpers.reset

describe('matchparen', function()
  local screen

  before_each(function()
    reset()
    screen = Screen.new(20,5)
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true},
    } )
  end)

  it('uses correct column after i_<Up>. Vim patch 7.4.1296', function()
    command('set noautoindent nosmartindent nocindent laststatus=0')
    eq(1, meths.get_var('loaded_matchparen'))
    feed('ivoid f_test()<cr>')
    feed('{<cr>')
    feed('}')

    -- critical part: up + cr should result in an empty line inbetween the
    -- brackets... if the bug is there, the empty line will be before the '{'
    feed('<up>')
    feed('<cr>')

    screen:expect([[
      void f_test()       |
      {                   |
      ^                    |
      }                   |
      {1:-- INSERT --}        |
    ]])

  end)
end)
