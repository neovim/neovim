local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local eq = helpers.eq
local insert = helpers.insert
local meths = helpers.meths

describe('redraw perf', function()
  before_each(function()
    clear()
    command('set redrawdebug+=nodelta')
    screen = Screen.new(40,10)
    screen:set_default_attr_ids {
      [0] = {bold=true, foreground=Screen.colors.Blue};
    }
    screen:track_redraws()
    screen:attach()
    screen:expect{grid=[[
      + ^                                        |
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      +                                         |
    ]]}
  end)
  it('when editing lines', function()
    meths.buf_set_lines(0, 0, -1, true, {'aa', 'bb', 'cc'})
    -- TODO: too many EOB lines!
    screen:expect{grid=[[
      + ^aa                                      |
      + bb                                      |
      + cc                                      |
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      -                                         |
    ]]}

    feed'rx'
    screen:expect{grid=[[
      + ^xa                                      |
      - bb                                      |
      - cc                                      |
      - {0:~                                       }|
      - {0:~                                       }|
      - {0:~                                       }|
      - {0:~                                       }|
      - {0:~                                       }|
      - {0:~                                       }|
      -                                         |
    ]]}

    feed 'yyp'
    -- TODO: too much!
    screen:expect{grid=[[
      - xa                                      |
      + ^xa                                      |
      + bb                                      |
      + cc                                      |
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      + {0:~                                       }|
      -                                         |
    ]]}

    feed 'dd'
    screen:expect{grid=[[
      - xa                                      |
      + ^bb                                      |
      s cc                                      |
      s {0:~                                       }|
      s {0:~                                       }|
      s {0:~                                       }|
      s {0:~                                       }|
      s {0:~                                       }|
      + {0:~                                       }|
      -                                         |
    ]]}
  end)
end)
