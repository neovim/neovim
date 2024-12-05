--
-- Tests for default autocmds, mappings, commands, and menus.
--
-- See options/defaults_spec.lua for default options and environment decisions.
--

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

describe('default', function()
  describe('key mappings', function()
    describe('Visual mode search mappings', function()
      it('handle various chars properly', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(60, 8)
        screen:attach()
        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGray4 },
          [2] = {
            foreground = Screen.colors.NvimDarkGray3,
            background = Screen.colors.NvimLightGray3,
          },
          [3] = {
            foreground = Screen.colors.NvimLightGrey1,
            background = Screen.colors.NvimDarkYellow,
          },
          [4] = {
            foreground = Screen.colors.NvimDarkGrey1,
            background = Screen.colors.NvimLightYellow,
          },
        })
        n.api.nvim_buf_set_lines(0, 0, -1, true, {
          [[testing <CR> /?\!1]],
          [[testing <CR> /?\!2]],
          [[testing <CR> /?\!3]],
          [[testing <CR> /?\!4]],
        })
        n.feed('gg0vf!o*')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          /\Vtesting <CR> \/?\\!                    [2/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          /\Vtesting <CR> \/?\\!                    [3/4]             |
        ]])
        n.feed('G0vf!o#')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          ?\Vtesting <CR> /?\\!                     [3/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          ?\Vtesting <CR> /?\\!                     [2/4]             |
        ]])
      end)
    end)
  end)
end)
