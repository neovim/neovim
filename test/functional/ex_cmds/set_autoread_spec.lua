local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, nvim, eq, neq = helpers.clear, helpers.nvim, helpers.eq, helpers.neq
local ok, feed, execute = helpers.ok, helpers.feed, helpers.execute


describe('autoread option', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.White, background = Screen.colors.Red},
      [2] = {bold = true, foreground = Screen.colors.SeaGreen}
    })
    screen:set_default_attr_ignore( {{bold=true, foreground=Screen.colors.Blue}} )
  end)

  it('is unset locally by default', function()
    execute('setl autoread?')
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      --autoread                    |
    ]])
  end)

  it('acts as a global option per default', function()
    execute('set autoread?')
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
        autoread                    |
    ]])
    execute('new')
    execute('set noautoread')
    execute('quit')
    execute('set autoread?')
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      noautoread                    |
    ]])
  end)

  it('can be set locally', function()
    execute('setl autoread')
    execute('new')
    execute('set noautoread')
    execute('setl noautoread')
    execute('quit')
    execute('setl autoread?')
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
        autoread                    |
    ]])

    -- revert back to global
    execute('setl autoread<')
    execute('setl autoread?')
    screen:expect([[
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      --autoread                    |
    ]])
  end)

end)

