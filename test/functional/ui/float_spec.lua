local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local os = require('os')
local clear, feed = helpers.clear, helpers.feed
local command, feed_command = helpers.command, helpers.feed_command
local eval = helpers.eval
local eq = helpers.eq
local meths = helpers.meths
local curbufmeths = helpers.curbufmeths
local funcs = helpers.funcs
local run = helpers.run
local meth_pcall = helpers.meth_pcall

describe('floating windows', function()
  before_each(function()
    clear()
  end)
  local attrs = {
    [0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {background = Screen.colors.LightMagenta},
    [2] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
    [3] = {bold = true},
    [4] = {bold = true, reverse = true},
    [5] = {reverse = true},
    [6] = {background = Screen.colors.LightMagenta, bold = true, reverse = true},
    [7] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    [8] = {bold = true, foreground = Screen.colors.SeaGreen4},
    [9] = {background = Screen.colors.LightGrey, underline = true},
    [10] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Magenta},
    [11] = {bold = true, foreground = Screen.colors.Magenta},
    [12] = {background = Screen.colors.Red, bold = true, foreground = Screen.colors.Blue1},
    [13] = {background = Screen.colors.WebGray}
  }

  local function with_ext_multigrid(multigrid)
    local screen
    before_each(function()
      screen = Screen.new(40,7)
      screen:attach({ext_multigrid=multigrid})
      screen:set_default_attr_ids(attrs)
    end)

    it('can be created and reconfigured', function()
      local buf = meths.create_buf(false,false)
      local win = meths.open_win(buf, false, 20, 2, {relative='editor', row=2, col=5})
      meths.win_set_option(win , 'winhl', 'Normal:PMenu')
      local expected_pos = {
          [3]={{id=1001}, 'NW', 1, 2, 5, true},
      }


      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
          ]])
      end


      meths.win_config(win,0,0,{relative='editor', row=0, col=10})
      expected_pos[3][4] = 0
      expected_pos[3][5] = 10
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ]])
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('API has proper error messages', function()
      local buf = meths.create_buf(false,false)
      eq({false, "Invalid options key 'bork'"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {bork=true}))
      eq({false, "'win' option is only valid with relative='win'"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {relative='editor',row=0,col=0,win=0}))
      eq({false, "Only one of 'relative' and 'external' should be used"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {relative='editor',row=0,col=0,external=true}))
      eq({false, "Invalid value of 'relative' option"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {relative='shell',row=0,col=0}))
      eq({false, "Invalid value of 'anchor' option"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {relative='editor',row=0,col=0,anchor='bottom'}))
      eq({false, "All of 'relative', 'row', and 'col' has to be specified at once"},
         meth_pcall(meths.open_win,buf, false, 20, 2, {relative='editor'}))
    end)

    it('can be placed relative window or cursor', function()
      screen:try_resize(40,9)
      meths.buf_set_lines(0, 0, -1, true, {'just some', 'example text'})
      feed('gge')
      local oldwin = meths.get_current_win()
      command('below split')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ]])
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      local buf = meths.create_buf(false,false)
      -- no 'win' arg, relative default window
      local win = meths.open_win(buf, false, 20, 2, {relative='win', row=0, col=10})
      meths.win_set_option(win, 'winhl', 'Normal:PMenu')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "NW", 3, 0, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some {1:                    }          |
          example te{2:~                   }          |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_config(win, -1, -1, {relative='cursor', row=1, col=-2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "NW", 3, 1, 1, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          e{1:                    }                   |
          {0:~}{2:~                   }{0:                   }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_config(win, -1, -1, {relative='cursor', row=0, col=0, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "SW", 3, 0, 3, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~  }{1:                    }{0:                 }|
          {5:[No}{2:~                   }{5:                 }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end


      meths.win_config(win, -1, -1, {relative='win', win=oldwin, row=1, col=10, anchor='NW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "NW", 2, 1, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example te{1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_config(win, -1, -1, {relative='win', win=oldwin, row=3, col=39, anchor='SE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "SE", 2, 3, 39, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text       {1:                    } |
          {0:~                  }{2:~                   }{0: }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_config(win, -1, -1, {relative='win', win=0, row=0, col=50, anchor='NE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          [3:----------------------------------------]|
          {4:[No Name] [+]                           }|
                                                  |
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [4] = {{id = 1002}, "NE", 3, 0, 50, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some           {1:                    }|
          example text        {2:~                   }|
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end
    end)

    if multigrid then
      pending("supports second UI without multigrid", function()
        local session2 = helpers.connect(eval('v:servername'))
        print(session2:request("nvim_eval", "2+2"))
        local screen2 = Screen.new(40,7)
        screen2:attach(nil, session2)
        screen2:set_default_attr_ids(attrs)
        local buf = meths.create_buf(false,false)
        local win = meths.open_win(buf, true, 20, 2, {relative='editor', row=2, col=5})
        meths.win_set_option(win, 'winhl', 'Normal:PMenu')
        local expected_pos = {
          [2]={{id=1001}, 'NW', 1, 2, 5}
        }
        screen:expect{grid=[[
        ## grid 1
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ## grid 2
          {1:^                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
        screen2:expect([[
                                                  |
          {0:~                                       }|
          {0:~    }{1:^                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
          ]])
      end)
    end


    it('handles resized screen', function()
      local buf = meths.create_buf(false,false)
      meths.buf_set_lines(buf, 0, -1, true, {'such', 'very', 'float'})
      local win = meths.open_win(buf, false, 15, 4, {relative='editor', row=2, col=10})
      meths.win_set_option(win , 'winhl', 'Normal:PMenu')
      local expected_pos = {
          [3]={{id=1001}, 'NW', 1, 2, 10, true},
      }
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~         }{1:such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,5)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,4)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,3)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
          ^                                        |
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
                                                  |
        ]])
      end
      feed('<c-w>wjj')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
                                                  |
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                    {1:very           }               |
          {0:~         }{1:^float          }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:^float          }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_config(win, -1, 3, {})
      feed('gg')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~                                       }|
                                                  |
        ]])
      end

      screen:try_resize(26,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
                                    |
        ## grid 2
                                    |
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                    |
          {0:~                         }|
          {0:~         }{1:^such           }{0: }|
          {0:~         }{1:very           }{0: }|
          {0:~         }{1:float          }{0: }|
          {0:~                         }|
                                    |
        ]])
      end

      screen:try_resize(25,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
                                   |
        ## grid 2
                                   |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                   |
          {0:~                        }|
          {0:~         }{1:^such           }|
          {0:~         }{1:very           }|
          {0:~         }{1:float          }|
          {0:~                        }|
                                   |
        ]])
      end

      screen:try_resize(24,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
                                  |
        ## grid 2
                                  |
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                  |
          {0:~                       }|
          {0:~        }{1:^such           }|
          {0:~        }{1:very           }|
          {0:~        }{1:float          }|
          {0:~                       }|
                                  |
        ]])
      end

      screen:try_resize(16,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
                          |
        ## grid 2
                          |
          {0:~               }|
          {0:~               }|
          {0:~               }|
          {0:~               }|
          {0:~               }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                          |
          {0:~               }|
          {0:~}{1:^such           }|
          {0:~}{1:very           }|
          {0:~}{1:float          }|
          {0:~               }|
                          |
        ]])
      end

      screen:try_resize(15,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
                         |
        ## grid 2
                         |
          {0:~              }|
          {0:~              }|
          {0:~              }|
          {0:~              }|
          {0:~              }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                         |
          {0:~              }|
          {1:^such           }|
          {1:very           }|
          {1:float          }|
          {0:~              }|
                         |
        ]])
      end

      screen:try_resize(14,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
                        |
        ## grid 2
                        |
          {0:~             }|
          {0:~             }|
          {0:~             }|
          {0:~             }|
          {0:~             }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                        |
          {0:~             }|
          {1:^such          }|
          {1:very          }|
          {1:float         }|
          {0:~             }|
                        |
        ]])
      end

      screen:try_resize(12,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
                      |
        ## grid 2
                      |
          {0:~           }|
          {0:~           }|
          {0:~           }|
          {0:~           }|
          {0:~           }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                      |
          {0:~           }|
          {1:^such        }|
          {1:very        }|
          {1:float       }|
          {0:~           }|
                      |
        ]])
      end

      -- Doesn't make much sense, but check nvim doesn't crash
      screen:try_resize(1,1)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|
                      |
        ## grid 2
                      |
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          {1:^such        }|
                      |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
                                                  |
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such        }{0:                  }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    describe('and completion', function()
      before_each(function()
        local buf = meths.create_buf(false,false)
        local win = meths.open_win(buf, true, 12, 4, {relative='editor', row=2, col=5})
        meths.win_set_option(win , 'winhl', 'Normal:ErrorMsg')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:^            }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:^            }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end
      end)

      it('with builtin popupmenu', function()
        feed('ix ')
        funcs.complete(3, {'aa', 'word', 'longtext'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa^        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ## grid 4
            {13: aa             }|
            {1: word           }|
            {1: longtext       }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
            [4] = {{ id = -1 }, "NW", 3, 1, 1, false}
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~}{13: aa             }{0:                  }|
            {0:~    }{12:~}{1: word           }{0:                  }|
            {0:~    }{12:~}{1: longtext       }{0:                  }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x a^a        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}

        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end

        feed('<c-w>wi')
        funcs.complete(1, {'xx', 'yy', 'zz'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ## grid 4
            {13:xx             }|
            {1:yy             }|
            {1:zz             }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
            [4] = {{ id = -1 }, "NW", 2, 1, 0, false}
          }}
        else
          screen:expect([[
            xx^                                      |
            {13:xx             }{0:                         }|
            {1:yy             }{7:  }{0:                       }|
            {1:zz             }{12:  }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('with ext_popupmenu', function()
        screen:set_option('ext_popupmenu', true)
        feed('ix ')
        funcs.complete(3, {'aa', 'word', 'longtext'})
        local items = {{"aa", "", "", ""}, {"word", "", "", ""}, {"longtext", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa^        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {0, 2, 3}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {2, 7}, items = items, pos = 0
          }}
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x a^a        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end

        feed('<c-w>wi')
        funcs.complete(1, {'xx', 'yy', 'zz'})
        items = {{"xx", "", "", ""}, {"yy", "", "", ""}, {"zz", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {0, 0, 2}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {0, 0}, items = items, pos = 0
          }}
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [3] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

    end)


    describe("handles :wincmd", function()
      local win
      local expected_pos
      before_each(function()
        -- the default, but be explicit:
        command("set laststatus=1")
        command("set hidden")
        meths.buf_set_lines(0,0,-1,true,{"x"})
        local buf = meths.create_buf(false,false)
        win = meths.open_win(buf, false, 20, 2, {relative='editor', row=2, col=5})
        meths.buf_set_lines(buf,0,-1,true,{"y"})
        meths.win_set_option(win , 'winhl', 'Normal:PMenu')
        expected_pos = {
          [3]={{id=1001}, 'NW', 1, 2, 5, true}
        }
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("w", function()
        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("w with focusable=false", function()
        meths.win_config(win, -1, -1, {focusable=false})
        expected_pos[3][6] = false
        feed("<c-w>wi") -- i to provoke redraw
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("W", function()
        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("focus by mouse", function()
        if multigrid then
          meths.input_mouse('left', 'press', '', 3, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        if multigrid then
          meths.input_mouse('left', 'press', '', 1, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("focus by mouse (focusable=false)", function()
        meths.win_config(win, -1, -1, {focusable=false})
        meths.buf_set_lines(0, -1, -1, true, {"a"})
        expected_pos[3][6] = false
        if multigrid then
          meths.input_mouse('left', 'press', '', 3, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            ^a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        if multigrid then
          meths.input_mouse('left', 'press', '', 1, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos, unchanged=true}
        else
          meths.input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)


      it("j", function()
        feed("<c-w>ji") -- INSERT to trigger screen change
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {3:-- INSERT --}                            |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

      end)

      it("s :split (non-float)", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
          ## grid 4
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end


        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end
      end)

      it("s :split (float)", function()
        feed("<c-w>w<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            {1:^y                                       }|
            {2:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            {1:^y                                       }|
            {2:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed(":set winhighlight=<cr><c-l>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^y                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end


        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>ji")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            {3:-- INSERT --}                            |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it(":new (non-float)", function()
        feed(":new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name]                               }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            :new                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it(":new (float)", function()
        feed("<c-w>w:new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name]                               }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            :new                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it("v :vsplit (non-float)", function()
        feed("<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^x                   |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end
      end)

      it(":vnew (non-float)", function()
        feed(":vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                    |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
        screen:expect([[
          ^                    {5:│}x                  |
          {0:~                   }{5:│}{0:~                  }|
          {0:~    }{1:y                   }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                   }{5:│}{0:~                  }|
          {4:[No Name]            }{5:[No Name] [+]      }|
          :vnew                                   |
        ]])
        end
      end)

      it(":vnew (float)", function()
        feed("<c-w>w:vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            [4:--------------------]{5:│}[2:-------------------]|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                    |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                    {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ]])
        end
      end)

      it("q (:quit) last non-float exits nvim", function()
        command('autocmd VimLeave    * call rpcrequest(1, "exit")')
        -- avoid unsaved change in other buffer
        feed("<c-w><c-w>:w Xtest_written2<cr><c-w><c-w>")
        -- quit in last non-float
        feed(":wq Xtest_written<cr>")
        local exited = false
        local function on_request(name, args)
          eq("exit", name)
          eq({}, args)
          exited = true
          return 0
        end
        local function on_setup()
          feed(":wq Xtest_written<cr>")
        end
        run(on_request, nil, on_setup)
        os.remove('Xtest_written')
        os.remove('Xtest_written2')
        eq(exited, true)
      end)

      it("o (:only) non-float", function()
        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) float fails", function()
        feed("<c-w>w<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end

        -- test message clear
        feed('<cr>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) non-float with split", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
                                                    |
          ## grid 4
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) float with split", function()
        feed("<c-w>s<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:^y                   }|
            {2:~                   }|
          ## grid 4
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {5:[No Name] [+]                           }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end
      end)

      it("J (float)", function()
        feed("<c-w>w<c-w>J")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
            {4:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:^y                                       }|
            {2:~                                       }|
        ]]}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            {1:^y                                       }|
            {2:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        if multigrid then
          meths.win_config(0,-1,-1,{external=true})
          expected_pos = {[3]={external=true}}
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:^y                                       }|
            {2:~                                       }|
        ]], float_pos=expected_pos}
        else
          eq({false, "UI doesn't support external windows"},
             meth_pcall(meths.win_config, 0,-1,-1,{external=true}))
          return
        end

        feed("<c-w>J")
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
            {4:[No Name] [+]                           }|
                                                    |
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {1:^y                                       }|
            {2:~                                       }|
          ]])
        end

      end)

      it('movements with nested split layout', function()
        command("set hidden")
        feed("<c-w>s<c-w>v<c-w>b<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[4:-------------------]|
            [5:--------------------]{5:│}[4:-------------------]|
            {5:[No Name] [+]        [No Name] [+]      }|
            [6:--------------------]{5:│}[2:-------------------]|
            [6:--------------------]{5:│}[2:-------------------]|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ## grid 2
            x                  |
            {0:~                  }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            x                  |
            {0:~                  }|
          ## grid 5
            x                   |
            {0:~                   }|
          ## grid 6
            ^x                   |
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {5:[No N}{1:y                   }{5:Name] [+]      }|
            ^x    {2:~                   }               |
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end

        -- verify that N<c-w>w works
        for i = 1,5 do
          feed(i.."<c-w>w")
          feed_command("enew")
          curbufmeths.set_lines(0,-1,true,{tostring(i)})
        end

        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:-------------------]{5:│}[4:--------------------]|
            [5:-------------------]{5:│}[4:--------------------]|
            {5:[No Name] [+]       [No Name] [+]       }|
            [6:-------------------]{5:│}[2:--------------------]|
            [6:-------------------]{5:│}[2:--------------------]|
            {5:[No Name] [+]       [No Name] [+]       }|
            :enew                                   |
          ## grid 2
            4                   |
            {0:~                   }|
          ## grid 3
            ^5                   |
            {0:~                   }|
          ## grid 4
            2                   |
            {0:~                   }|
          ## grid 5
            1                  |
            {0:~                  }|
          ## grid 6
            3                  |
            {0:~                  }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            1                  {5:│}2                   |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No N}^5                   {5:ame] [+]       }|
            3    {0:~                   }               |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No Name] [+]       [No Name] [+]       }|
            :enew                                   |
          ]])
        end

        local movements = {
          w={2,3,4,5,1},
          W={5,1,2,3,4},
          h={1,1,3,3,3},
          j={3,3,3,4,4},
          k={1,2,1,1,1},
          l={2,2,4,4,4},
          t={1,1,1,1,1},
          b={4,4,4,4,4},
        }

        for k,v in pairs(movements) do
          for i = 1,5 do
            feed(i.."<c-w>w")
            feed('<c-w>'..k)
            local nr = funcs.winnr()
            eq(v[i],nr, "when using <c-w>"..k.." from window "..i)
          end
        end

        for i = 1,5 do
          feed(i.."<c-w>w")
          for j = 1,5 do
            if j ~= i then
              feed(j.."<c-w>w")
              feed('<c-w>p')
              local nr = funcs.winnr()
              eq(i,nr, "when using <c-w>p to window "..i.." from window "..j)
            end
          end
        end

      end)

      it(":tabnew and :tabnext", function()
        feed(":tabnew<cr>")
        if multigrid then
          -- grid is not freed, but float is marked as closed (should it rather be "invisible"?)
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            :tabnew                                 |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            :tabnew                                 |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            :tabnext                                |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            ^x                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {4:[No Name] [+]                           }|
            :tabnext                                |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            :tabnext                                |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            :tabnext                                |
          ]])
        end
      end)

      it(":tabnew and :tabnext (external)", function()
        if multigrid then
          meths.win_config(win,-1,-1,{external=true})
          expected_pos = {[3]={external=true}}
          feed(":tabnew<cr>")
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            :tabnew                                 |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          eq({false, "UI doesn't support external windows"},
             meth_pcall(meths.win_config, 0,-1,-1,{external=true}))
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            :tabnext                                |
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name]                               }|
            :tabnext                                |
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {1:y                   }|
            {2:~                   }|
          ## grid 4
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        end
      end)
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)
  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)

end)

