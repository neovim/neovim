local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local feed_command = helpers.feed_command
local insert = helpers.insert
local meths = helpers.meths

describe("folded lines", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(45, 8)
    screen:attach({rgb=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {reverse = true},
      [3] = {bold = true, reverse = true},
      [4] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [5] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [6] = {background = Screen.colors.Yellow},
      [7] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
    })
  end)

  after_each(function()
    screen:detach()
  end)

  it("works with multibyte text", function()
    -- Currently the only allowed value of 'maxcombine'
    eq(6, meths.get_option('maxcombine'))
    eq(true, meths.get_option('arabicshape'))
    insert([[
      å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢͟ العَرَبِيَّة
      möre text]])
    screen:expect([[
      å 语 x̎͂̀̂͛͛ ﺎﻠﻋَﺮَﺒِﻳَّﺓ                               |
      möre tex^t                                    |
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
                                                   |
    ]])

    feed('vkzf')
    screen:expect([[
      {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ ﺎﻠﻋَﺮَﺒِﻳَّﺓ·················}|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
                                                   |
    ]])

    feed_command("set noarabicshape")
    screen:expect([[
      {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      :set noarabicshape                           |
    ]])

    feed_command("set number foldcolumn=2")
    screen:expect([[
      {7:+ }{5:  1 ^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة···········}|
      {7:  }{1:~                                          }|
      {7:  }{1:~                                          }|
      {7:  }{1:~                                          }|
      {7:  }{1:~                                          }|
      {7:  }{1:~                                          }|
      {7:  }{1:~                                          }|
      :set number foldcolumn=2                     |
    ]])

    -- Note: too much of the folded line gets cut off.This is a vim bug.
    feed_command("set rightleft")
    screen:expect([[
      {5:+--  2 lines: å ······················^·  1 }{7: +}|
      {1:                                          ~}{7:  }|
      {1:                                          ~}{7:  }|
      {1:                                          ~}{7:  }|
      {1:                                          ~}{7:  }|
      {1:                                          ~}{7:  }|
      {1:                                          ~}{7:  }|
      :set rightleft                               |
    ]])

    feed_command("set nonumber foldcolumn=0")
    screen:expect([[
      {5:+--  2 lines: å 语 x̎͂̀̂͛͛ ال·····················^·}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      :set nonumber foldcolumn=0                   |
    ]])

    feed_command("set arabicshape")
    screen:expect([[
      {5:+--  2 lines: å 语 x̎͂̀̂͛͛ ﺍﻟ·····················^·}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      :set arabicshape                             |
    ]])

    feed('zo')
    screen:expect([[
                                     ﺔﻴَّﺑِﺮَﻌَ^ﻟﺍ x̎͂̀̂͛͛ 语 å|
                                          txet eröm|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      :set arabicshape                             |
    ]])

    feed_command('set noarabicshape')
    screen:expect([[
                                     ةيَّبِرَعَ^لا x̎͂̀̂͛͛ 语 å|
                                          txet eröm|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      {1:                                            ~}|
      :set noarabicshape                           |
    ]])

  end)

  it("work in cmdline window", function()
    feed_command("set foldmethod=manual")
    feed_command("let x = 1")
    feed_command("/alpha")
    feed_command("/omega")

    feed("<cr>q:")
    screen:expect([[
                                                   |
      {2:[No Name]                                    }|
      {1::}set foldmethod=manual                       |
      {1::}let x = 1                                   |
      {1::}^                                            |
      {1::~                                           }|
      {3:[Command Line]                               }|
      :                                            |
    ]])

    feed("kzfk")
    screen:expect([[
                                                   |
      {2:[No Name]                                    }|
      {1::}{5:^+--  2 lines: set foldmethod=manual·········}|
      {1::}                                            |
      {1::~                                           }|
      {1::~                                           }|
      {3:[Command Line]                               }|
      :                                            |
    ]])

    feed("<cr>")
    screen:expect([[
      ^                                             |
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      :                                            |
    ]])

    feed("/<c-f>")
    screen:expect([[
                                                   |
      {2:[No Name]                                    }|
      {1:/}alpha                                       |
      {1:/}{6:omega}                                       |
      {1:/}^                                            |
      {1:/~                                           }|
      {3:[Command Line]                               }|
      /                                            |
    ]])

    feed("ggzfG")
    screen:expect([[
                                                   |
      {2:[No Name]                                    }|
      {1:/}{5:^+--  3 lines: alpha·························}|
      {1:/~                                           }|
      {1:/~                                           }|
      {1:/~                                           }|
      {3:[Command Line]                               }|
      /                                            |
    ]])

  end)
end)
