local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local is_os = helpers.is_os

describe(':Tutor', function()
  local screen

  before_each(function()
    clear({ args = { '--clean' } })
    command('set cmdheight=0')
    command('Tutor')
    screen = Screen.new(80, 30)
    screen:set_default_attr_ids({
      [0] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
      [1] = { bold = true },
      [2] = { underline = true, foreground = tonumber('0x0088ff') },
      [3] = { foreground = Screen.colors.SlateBlue },
      [4] = { bold = true, foreground = Screen.colors.Brown },
      [5] = { bold = true, foreground = Screen.colors.Magenta1 },
    })
    screen:attach()
  end)

  it('applies {unix:…,win:…} transform', function()
    local expected = is_os('win') and [[
      {0:  }^                                                                              |
      {0:  } 3. To verify that a file was retrieved, cursor back and notice that there    |
      {0:  }    are now two copies of Lesson 5.3, the original and the retrieved version. |
      {0:  }                                                                              |
      {0:  }{1:NOTE}: You can also read the output of an external command. For example,       |
      {0:  }                                                                              |
      {0:  }        :r {4:!}dir                                                               |
      {0:  }                                                                              |
      {0:  }      reads the output of the ls command and puts it below the cursor.        |
      {0:  }                                                                              |
      {0:  }{3:#}{5: Lesson 5 SUMMARY}                                                            |
      {0:  }                                                                              |
      {0:  } 1. {2::!command} executes an external command.                                   |
      {0:  }                                                                              |
      {0:  }     Some useful examples are:                                                |
      {0:  }     :{4:!}dir                   - shows a directory listing                      |
      {0:  }     :{4:!}del FILENAME          - removes file FILENAME                          |
      {0:  }                                                                              |
      {0:  } 2. {2::w} FILENAME              writes the current Neovim file to disk with      |
      {0:  }                             name FILENAME.                                   |
      {0:  }                                                                              |
      {0:  } 3. {2:v}  motion  :w FILENAME   saves the Visually selected lines in file        |
      {0:  }                             FILENAME.                                        |
      {0:  }                                                                              |
      {0:  } 4. {2::r} FILENAME              retrieves disk file FILENAME and puts it         |
      {0:  }                             below the cursor position.                       |
      {0:  }                                                                              |
      {0:  } 5. {2::r !dir}                  reads the output of the dir command and          |
      {0:  }                             puts it below the cursor position.               |
      {0:  }                                                                              |
    ]] or [[
      {0:  }^                                                                              |
      {0:  } 3. To verify that a file was retrieved, cursor back and notice that there    |
      {0:  }    are now two copies of Lesson 5.3, the original and the retrieved version. |
      {0:  }                                                                              |
      {0:  }{1:NOTE}: You can also read the output of an external command. For example,       |
      {0:  }                                                                              |
      {0:  }        :r {4:!}ls                                                                |
      {0:  }                                                                              |
      {0:  }      reads the output of the ls command and puts it below the cursor.        |
      {0:  }                                                                              |
      {0:  }{3:#}{5: Lesson 5 SUMMARY}                                                            |
      {0:  }                                                                              |
      {0:  } 1. {2::!command} executes an external command.                                   |
      {0:  }                                                                              |
      {0:  }     Some useful examples are:                                                |
      {0:  }     :{4:!}ls                    - shows a directory listing                      |
      {0:  }     :{4:!}rm  FILENAME          - removes file FILENAME                          |
      {0:  }                                                                              |
      {0:  } 2. {2::w} FILENAME              writes the current Neovim file to disk with      |
      {0:  }                             name FILENAME.                                   |
      {0:  }                                                                              |
      {0:  } 3. {2:v}  motion  :w FILENAME   saves the Visually selected lines in file        |
      {0:  }                             FILENAME.                                        |
      {0:  }                                                                              |
      {0:  } 4. {2::r} FILENAME              retrieves disk file FILENAME and puts it         |
      {0:  }                             below the cursor position.                       |
      {0:  }                                                                              |
      {0:  } 5. {2::r !ls}                   reads the output of the ls command and           |
      {0:  }                             puts it below the cursor position.               |
      {0:  }                                                                              |
    ]]

    feed(':700<CR>zt')
    screen:expect(expected)
  end)
end)
