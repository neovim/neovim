local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed
local is_os = t.is_os

describe(':Tutor', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear({ args = { '--clean' } })
    command('set cmdheight=0')
    command('Tutor')
    screen = Screen.new(81, 30)
    screen:set_default_attr_ids({
      [0] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
      [1] = { bold = true },
      [2] = { underline = true, foreground = tonumber('0x0088ff') },
      [3] = { foreground = Screen.colors.SlateBlue },
      [4] = { bold = true, foreground = Screen.colors.Brown },
      [5] = { bold = true, foreground = Screen.colors.Magenta1 },
      [6] = { italic = true },
    })
  end)

  it('applies {unix:…,win:…} transform', function()
    local expected = is_os('win')
        and [[
      {0:  }^                                                                               |
      {0:  } 3. To verify that a file was retrieved, cursor back and notice that there     |
      {0:  }    are now two copies of Lesson 5.3, the original and the retrieved version.  |
      {0:  }                                                                               |
      {0:  }{1:NOTE}: You can also read the output of an external command. For example,        |
      {0:  }                                                                               |
      {0:  }        :r {4:!}dir                                                                |
      {0:  }                                                                               |
      {0:  }      reads the output of the ls command and puts it below the cursor.         |
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 5 SUMMARY}                                                             |
      {0:  }                                                                               |
      {0:  } 1. {2::!command} executes an external command.                                    |
      {0:  }                                                                               |
      {0:  }     Some useful examples are:                                                 |
      {0:  }     :{4:!}dir                   - shows a directory listing                       |
      {0:  }     :{4:!}del FILENAME          - removes file FILENAME                           |
      {0:  }                                                                               |
      {0:  } 2. {2::w} FILENAME              writes the current Neovim file to disk with       |
      {0:  }                             name FILENAME.                                    |
      {0:  }                                                                               |
      {0:  } 3. {2:v}  motion  :w FILENAME   saves the Visually selected lines in file         |
      {0:  }                             FILENAME.                                         |
      {0:  }                                                                               |
      {0:  } 4. {2::r} FILENAME              retrieves disk file FILENAME and puts it          |
      {0:  }                             below the cursor position.                        |
      {0:  }                                                                               |
      {0:  } 5. {2::r !dir}                  reads the output of the dir command and           |
      {0:  }                             puts it below the cursor position.                |
      {0:  }                                                                               |
    ]]
      or [[
      {0:  }^                                                                               |
      {0:  } 3. To verify that a file was retrieved, cursor back and notice that there     |
      {0:  }    are now two copies of Lesson 5.3, the original and the retrieved version.  |
      {0:  }                                                                               |
      {0:  }{1:NOTE}: You can also read the output of an external command. For example,        |
      {0:  }                                                                               |
      {0:  }        :r {4:!}ls                                                                 |
      {0:  }                                                                               |
      {0:  }      reads the output of the ls command and puts it below the cursor.         |
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 5 SUMMARY}                                                             |
      {0:  }                                                                               |
      {0:  } 1. {2::!command} executes an external command.                                    |
      {0:  }                                                                               |
      {0:  }     Some useful examples are:                                                 |
      {0:  }     :{4:!}ls                    - shows a directory listing                       |
      {0:  }     :{4:!}rm  FILENAME          - removes file FILENAME                           |
      {0:  }                                                                               |
      {0:  } 2. {2::w} FILENAME              writes the current Neovim file to disk with       |
      {0:  }                             name FILENAME.                                    |
      {0:  }                                                                               |
      {0:  } 3. {2:v}  motion  :w FILENAME   saves the Visually selected lines in file         |
      {0:  }                             FILENAME.                                         |
      {0:  }                                                                               |
      {0:  } 4. {2::r} FILENAME              retrieves disk file FILENAME and puts it          |
      {0:  }                             below the cursor position.                        |
      {0:  }                                                                               |
      {0:  } 5. {2::r !ls}                   reads the output of the ls command and            |
      {0:  }                             puts it below the cursor position.                |
      {0:  }                                                                               |
    ]]

    feed(':702<CR>zt')
    screen:expect(expected)
  end)

  it('applies hyperlink highlighting', function()
    local expected = [[
      {0:  }^This concludes Chapter 1 of the Vim Tutor.  Consider continuing with           |
      {0:  }{2:Chapter 2}.                                                                     |
      {0:  }                                                                               |
      {0:  }This was intended to give a brief overview of the Neovim editor, just enough to|
      {0:  }allow you to use it fairly easily. It is far from complete as Neovim has       |
      {0:  }many many more commands. Consult the help often.                               |
      {0:  }There are also countless great tutorials and videos to be found online.        |
      {0:  }Here's a bunch of them:                                                        |
      {0:  }                                                                               |
      {0:  }- {6:Learn Vim Progressively}:                                                     |
      {0:  }  {2:https://yannesposito.com/Scratch/en/blog/Learn-Vim-Progressively/}            |
      {0:  }- {6:Learning Vim in 2014}:                                                        |
      {0:  }  {2:https://benmccormick.org/learning-vim-in-2014/}                               |
      {0:  }- {6:Vimcasts}:                                                                    |
      {0:  }  {2:http://vimcasts.org/}                                                         |
      {0:  }- {6:Vim Video-Tutorials by Derek Wyatt}:                                          |
      {0:  }  {2:http://derekwyatt.org/vim/tutorials/}                                         |
      {0:  }- {6:Learn Vimscript the Hard Way}:                                                |
      {0:  }  {2:https://learnvimscriptthehardway.stevelosh.com/}                              |
      {0:  }- {6:7 Habits of Effective Text Editing}:                                          |
      {0:  }  {2:https://www.moolenaar.net/habits.html}                                        |
      {0:  }- {6:vim-galore}:                                                                  |
      {0:  }  {2:https://github.com/mhinz/vim-galore}                                          |
      {0:  }                                                                               |
      {0:  }If you prefer a book, {6:Practical Vim} by Drew Neil is recommended often          |
      {0:  }(the sequel, {6:Modern Vim}, includes material specific to Neovim).                |
      {0:  }                                                                               |
      {0:  }This tutorial was written by Michael C. Pierce and Robert K. Ware, Colorado    |
      {0:  }School of Mines using ideas supplied by Charles Smith, Colorado State          |
      {0:  }University. E-mail: {2:bware@mines.colorado.edu}.                                  |
    ]]

    feed(':983<CR>zt')
    screen:expect(expected)
  end)
end)

describe(':Tutor tutor', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear({ args = { '--clean' } })
    command('set cmdheight=0')
    command('Tutor tutor')
    screen = Screen.new(81, 30)
    screen:set_default_attr_ids({
      [0] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
      [1] = { bold = true },
      [2] = { underline = true, foreground = tonumber('0x0088ff') },
      [3] = { foreground = Screen.colors.SlateBlue },
      [4] = { bold = true, foreground = Screen.colors.Brown },
      [5] = { bold = true, foreground = Screen.colors.Magenta1 },
      [6] = { italic = true },
      [7] = { foreground = tonumber('0x00ff88'), bold = true, background = Screen.colors.Grey },
      [8] = { bold = true, foreground = Screen.colors.Blue1 },
    })
  end)

  it('applies interactive marks', function()
    feed(':216<CR>zt')
    screen:expect([[
  {0:  }{3:^###}{5: expect }                                                                    |
  {0:  }                                                                               |
  {0:  }"expect" lines check that the contents of the line are identical to some preset|
  {0:  } text                                                                          |
  {0:  }(like in the exercises above).                                                 |
  {0:  }                                                                               |
  {0:  }These elements are specified in separate JSON files like this                  |
  {0:  }                                                                               |
  {0:  }{3:~~~ json}                                                                       |
  {0:  }{                                                                              |
  {0:  }  "expect": {                                                                  |
  {0:  }    "1": "This is how this line should look.",                                 |
  {0:  }    "2": "This is how this line should look.",                                 |
  {0:  }    "3": -1                                                                    |
  {0:  }  }                                                                            |
  {0:  }}                                                                              |
  {0:  }{3:~~~}                                                                            |
  {0:  }                                                                               |
  {0:  }These files contain an "expect" dictionary, for which the keys are line numbers|
  {0:  } and                                                                           |
  {0:  }the values are the expected text. A value of -1 means that the condition for th|
  {0:  }e line                                                                         |
  {0:  }will always be satisfied, no matter what (this is useful for letting the user p|
  {0:  }lay a bit).                                                                    |
  {0:  }                                                                               |
  {7:✓ }{3:This is an "expect" line that is always satisfied. Try changing it.}            |
  {0:  }                                                                               |
  {0:  }These files conventionally have the same name as the tutorial document with the|
  {0:  } .json                                                                         |
  {0:  }extension appended (for a full example, see the file that corresponds to thi{8:@@@}|
]])
  end)
end)
