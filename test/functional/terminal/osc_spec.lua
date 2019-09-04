local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local nvim_dir = helpers.nvim_dir
local command = helpers.command
local clear = helpers.clear
local eq = helpers.eq
local feed = helpers.feed
local meths = helpers.meths
local write_file = helpers.write_file

describe('osc handling', function()
  function emit_osc(osc)
    command("term " .. osc)
  end

  before_each(function()
    clear()

    meths.set_option('shell', nvim_dir .. '/shell-test')
    meths.set_option('shellcmdflag', '-t')
  end)

  describe('osc-51', function()
    describe('containing a drop command', function()
      it('opens the specified file in a split', function()
        local fname = 'drop_target'
        write_file(fname, 'drop target contents', false)

        local screen = Screen.new(25, 10)
        screen:attach()

        local osc = '\x1b]51;["drop", "' .. fname .. '"]\a'
        emit_osc(osc)

        screen:expect([[
          ^drop target contents     |
          ~                        |
          ~                        |
          ~                        |
          drop_target              |
           $                       |
          [Process exited 0]       |
                                   |
          <drop", "drop_target"]^G |
                                   |
        ]])

        os.remove(fname)
      end)

      it('handles missing argument', function()
        local screen = Screen.new(25, 10)
        screen:attach()

        local osc = '\x1b]51;["drop"]\a'
        emit_osc(osc)

        screen:expect([[
          ^ $                       |
          [Process exited 0]       |
                                   |
                                   |
                                   |
                                   |
                                   |
                                   |
                                   |
                                   |
        ]])
      end)
    end)

    it('handles empty list', function()
      local screen = Screen.new(25, 10)
      screen:attach()

      local osc = '\x1b]51;[]\a'
      emit_osc(osc)

      screen:expect([[
        ^ $                       |
        [Process exited 0]       |
                                 |
                                 |
                                 |
                                 |
                                 |
                                 |
                                 |
        E474: Invalid argument   |
      ]])
    end)
  end)
end)
