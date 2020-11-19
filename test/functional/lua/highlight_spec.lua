local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local exec_lua = helpers.exec_lua
local feed = helpers.feed

before_each(function()
    clear()
end)

describe('vim.highlight.on_yank()', function()
  local screen
  local HL_TIMEOUT = 30
  local enable_hl_on_yank = function(args)
    local higroup = args['higroup'] or 'IncSearch'
    local timeout = args['timeout'] or 150
    local on_macro = args['on_macro'] == nil and 'true' or 'false'
    local on_visual = args['on_visual'] == nil and 'true' or 'false'

    command('au TextYankPost * '
      ..'silent! lua vim.highlight.on_yank {higroup="'..higroup
      ..'", timeout='..timeout..', on_macro='..on_macro
      ..', on_visual='..on_visual..'}')
  end

  describe('arguments', function()
    before_each(function()
      clear()
      screen = Screen.new(20, 1)
      screen:attach()
      screen:set_default_attr_ids( {
        [0] = {reverse=true},
        [1] = {italic=true}
      } )
      feed('iuna línea solamente<esc>')
    end)

    it('works with non-default higroup', function()
      command('hi ItGroup gui=italic cterm=italic')
      enable_hl_on_yank {higroup='ItGroup'}
      feed('yy')
      screen:expect{grid=[[
        {1:una línea solament^e} |
                            |
      ]]}
    end)

    it('works with non-default timeout', function()
      enable_hl_on_yank {timeout=HL_TIMEOUT}
      feed('yy')
      screen:expect{grid=[[
        {0:una línea solament^e} |
                            |
      ]]}

      feed('yy')
      screen:expect{grid=[[
        una línea solament^e |
                            |
      ]], timeout=3*HL_TIMEOUT}
    end)

    it('ignores visual yanks when on_visual=false', function()
      enable_hl_on_yank {on_visual=false, timeout=HL_TIMEOUT}
      -- sanity check
      feed('yy')
      screen:expect{grid=[[
        {0:una línea solament^e} |
                            |
      ]]}

      -- wait for sanity check to clear
      screen:expect{grid=[[
        una línea solament^e |
                            |
      ]], timeout=3*HL_TIMEOUT}

      feed('Vy')
      screen:expect{grid=[[
        ^una línea solamente |
                            |
      ]]}
    end)

    it('ignores in-macro yanks when on_macro=false', function()
      enable_hl_on_yank {on_macro=false, timeout=HL_TIMEOUT}
      -- sanity check
      feed('yy')
      screen:expect{grid=[[
        {0:una línea solament^e} |
                            |
      ]]}

      -- create macro
      feed('0qqyiwwq')

      -- wait for macro to clear
      screen:expect{grid=[[
        una ^línea solamente |
                            |
      ]], timeout=3*HL_TIMEOUT}

      feed('@qv4lp')
      screen:expect{grid=[[
        una línea líne^aente |
                            |
      ]]}
    end)
  end)

  describe('when virtualedit=all', function()
    before_each(function()
      clear()
      screen = Screen.new(25, 5)
      screen:attach()
      screen:set_default_attr_ids( {
        [0] = {reverse=true},
        [1] = {bold=true, foreground=Screen.colors.Blue},
      } )
      command('set virtualedit=all')
      feed('ishórt<cr>hint: a loonger line<cr>galỉłeö<esc>')
      enable_hl_on_yank {timeout=HL_TIMEOUT}
    end)

    it('block region is highlighted correctly', function()
      feed('gg0<c-v>ljy')
      screen:expect{grid=[[
        {0:^sh}órt                    |
        {0:hi}nt: a loonger line     |
        galỉłeö                  |
        {1:~                        }|
                                 |
      ]]}

      feed('2l<c-v>3j12ly')
      screen:expect{grid=[[
        sh{0:^órt}                    |
        hi{0:nt: a loonger} line     |
        ga{0:lỉłeö}                  |
        {1:~                        }|
        block of 3 lines yanked  |
      ]]}

      feed('5l<c-v>2j6ly')
      screen:expect{grid=[[
        shórt  ^                  |
        hint: a {0:loonger} line     |
        galỉłeö                  |
        {1:~                        }|
        block of 3 lines yanked  |
      ]]}
    end)

    it('yy highlights whole lines', function()
      feed('yy')
      screen:expect{grid=[[
        shórt                    |
        hint: a loonger line     |
        {0:galỉłe^ö}                  |
        {1:~                        }|
                                 |
      ]]}

      feed('5lyy')
      screen:expect{grid=[[
        shórt                    |
        hint: a loonger line     |
        {0:galỉłeö}    ^              |
        {1:~                        }|
                                 |
      ]]}

      feed('gg20|3yy')
      screen:expect{grid=[[
        {0:shórt}              ^      |
        {0:hint: a loonger line}     |
        {0:galỉłeö}                  |
        {1:~                        }|
        3 lines yanked           |
      ]]}
    end)
  end)

  it('does not show errors even if buffer is wiped before timeout', function()
    command('new')
    exec_lua[[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y", regtype = "v"}})
      vim.cmd('bwipeout!')
    ]]
    helpers.sleep(10)
    helpers.feed('<cr>') -- avoid hang if error message exists
    eq('', eval('v:errmsg'))
  end)

end)
