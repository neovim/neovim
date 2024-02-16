local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local api = helpers.api

describe('Vimscript syntax highlighting', function()
  local screen

  before_each(function()
    clear()
    helpers.add_builddir_to_rtp()
    exec([[
      setfiletype vim
      syntax on
    ]])
    screen = Screen.new()
    screen:set_default_attr_ids({
      [0] = { foreground = Screen.colors.Blue, bold = true },
      [1] = { foreground = Screen.colors.Brown, bold = true },
      [2] = { foreground = tonumber('0x6a0dad') },
    })
    screen:attach()
  end)

  it('prefixed boolean options are highlighted properly', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'set number incsearch hlsearch',
      'set nonumber noincsearch nohlsearch',
      'set invnumber invincsearch invhlsearch',
    })
    screen:expect([[
      {1:^set} {2:number} {2:incsearch} {2:hlsearch}                        |
      {1:set} {2:nonumber} {2:noincsearch} {2:nohlsearch}                  |
      {1:set} {2:invnumber} {2:invincsearch} {2:invhlsearch}               |
      {0:~                                                    }|*10
                                                           |
    ]])
  end)
end)
