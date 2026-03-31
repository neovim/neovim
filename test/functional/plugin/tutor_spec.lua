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
      [0] = { foreground = Screen.colors.Blue4, background = Screen.colors.Grey },
      [1] = { bold = true },
      [2] = { underline = true, foreground = tonumber('0x0088ff') },
      [3] = { foreground = Screen.colors.SlateBlue },
      [4] = { bold = true, foreground = Screen.colors.Brown },
      [5] = { bold = true, foreground = Screen.colors.Magenta1 },
      [6] = { italic = true },
      [7] = { foreground = tonumber('0x00ff88'), bold = true, background = Screen.colors.Grey },
      [8] = { bold = true, foreground = Screen.colors.Blue },
      [9] = { foreground = Screen.colors.Magenta1 },
      [10] = { foreground = tonumber('0xff2000'), bold = true },
      [11] = { foreground = tonumber('0xff2000'), bold = true, background = Screen.colors.Grey },
      [12] = { foreground = tonumber('0x6a0dad') },
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

  it("removing a line doesn't affect highlight/mark of other lines", function()
    -- Do lesson 2.6
    feed(':294<CR>zt')
    screen:expect([[
      {0:  }{3:^#}{5: Lesson 2.6: OPERATING ON LINES}                                               |
      {0:  }                                                                               |
      {0:  }{1: Type }{4:dd}{1: to delete a whole line. }                                              |
      {0:  }                                                                               |
      {0:  }Due to the frequency of whole line deletion, the designers of Vi decided       |
      {0:  }it would be easier to simply type two d's to delete a line.                    |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the second line in the phrase below.                    |
      {0:  }                                                                               |
      {0:  } 2. Type {2:dd} to delete the line.                                                |
      {0:  }                                                                               |
      {0:  } 3. Now move to the fourth line.                                               |
      {0:  }                                                                               |
      {0:  } 4. Type {9:2}{4:dd} to delete two lines.                                              |
      {0:  }                                                                               |
      {7:✓ }{3:1)  Roses are red,                                                             }|
      {11:✗ }{3:2)  Mud is fun,                                                                }|
      {7:✓ }{3:3)  Violets are blue,                                                          }|
      {11:✗ }{3:4)  I have a car,                                                              }|
      {11:✗ }{3:5)  Clocks tell time,                                                          }|
      {7:✓ }{3:6)  Sugar is sweet                                                             }|
      {7:✓ }{3:7)  And so are you.                                                            }|
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 2.7: THE UNDO COMMAND}                                                 |
      {0:  }                                                                               |
      {0:  }{1: Press }{4:u}{1: to undo the last commands, }{4:U}{1: to fix a whole line. }                    |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the line below marked {10:✗} and place it on the first error.|
      {0:  }                                                                               |
      {0:  } 2. Type {4:x} to delete the first unwanted character.                             |
]])

    feed('<Cmd>310<CR>dd<Cmd>311<CR>2dd')
    screen:expect([[
      {0:  }{3:#}{5: Lesson 2.6: OPERATING ON LINES}                                               |
      {0:  }                                                                               |
      {0:  }{1: Type }{4:dd}{1: to delete a whole line. }                                              |
      {0:  }                                                                               |
      {0:  }Due to the frequency of whole line deletion, the designers of Vi decided       |
      {0:  }it would be easier to simply type two d's to delete a line.                    |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the second line in the phrase below.                    |
      {0:  }                                                                               |
      {0:  } 2. Type {2:dd} to delete the line.                                                |
      {0:  }                                                                               |
      {0:  } 3. Now move to the fourth line.                                               |
      {0:  }                                                                               |
      {0:  } 4. Type {9:2}{4:dd} to delete two lines.                                              |
      {0:  }                                                                               |
      {7:✓ }{3:1)  Roses are red,                                                             }|
      {7:✓ }{3:3)  Violets are blue,                                                          }|
      {7:✓ }{3:^6)  Sugar is sweet                                                             }|
      {7:✓ }{3:7)  And so are you.                                                            }|
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 2.7: THE UNDO COMMAND}                                                 |
      {0:  }                                                                               |
      {0:  }{1: Press }{4:u}{1: to undo the last commands, }{4:U}{1: to fix a whole line. }                    |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the line below marked {10:✗} and place it on the first error.|
      {0:  }                                                                               |
      {0:  } 2. Type {4:x} to delete the first unwanted character.                             |
      {0:  }                                                                               |
      {0:  } 3. Now type {4:u} to undo the last command executed.                              |
      {0:  }                                                                               |
    ]])
  end)

  it("inserting text at start of line doesn't affect highlight/sign", function()
    -- Go to lesson 1.3 and make it top line in the window
    feed('<Cmd>92<CR>zt')
    screen:expect([[
      {0:  }{3:^#}{5: Lesson 1.3: TEXT EDITING: DELETION}                                           |
      {0:  }                                                                               |
      {0:  }{1: Press }{4:x}{1: to delete the character under the cursor. }                            |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the line below marked {10:✗}.                                |
      {0:  }                                                                               |
      {0:  } 2. To fix the errors, move the cursor until it is on top of the               |
      {0:  }    character to be deleted.                                                   |
      {0:  }                                                                               |
      {0:  } 3. Press {2:the x key} to delete the unwanted character.                          |
      {0:  }                                                                               |
      {0:  } 4. Repeat steps 2 through 4 until the sentence is correct.                    |
      {0:  }                                                                               |
      {11:✗ }{3:The ccow jumpedd ovverr thhe mooon.                                            }|
      {0:  }                                                                               |
      {0:  } 5. Now that the line is correct, go on to Lesson 1.4.                         |
      {0:  }                                                                               |
      {0:  }{1:NOTE}: As you go through this tutorial, do not try to memorize everything,      |
      {0:  }      your Neovim vocabulary will expand with usage. Consider returning to     |
      {0:  }      this tutorial periodically for a refresher.                              |
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 1.4: TEXT EDITING: INSERTION}                                          |
      {0:  }                                                                               |
      {0:  }{1: Press }{12:i}{1: to insert text. }                                                      |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the first line below marked {10:✗}.                          |
      {0:  }                                                                               |
      {0:  } 2. To make the first line the same as the second, move the cursor on top      |
      {0:  }    of the first character AFTER where the text is to be inserted.             |
      {0:  }                                                                               |
    ]])
    -- Go to the test line and insert text at the start of the line
    feed('<Cmd>105<CR>iThe <Esc>')
    -- Remove redundant characters
    feed('fcxfdxfvxfrxfhxfox')
    -- Remove the original "The " text (not the just-inserted one)
    feed('^4ldw^')
    screen:expect([[
      {0:  }{3:#}{5: Lesson 1.3: TEXT EDITING: DELETION}                                           |
      {0:  }                                                                               |
      {0:  }{1: Press }{4:x}{1: to delete the character under the cursor. }                            |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the line below marked {10:✗}.                                |
      {0:  }                                                                               |
      {0:  } 2. To fix the errors, move the cursor until it is on top of the               |
      {0:  }    character to be deleted.                                                   |
      {0:  }                                                                               |
      {0:  } 3. Press {2:the x key} to delete the unwanted character.                          |
      {0:  }                                                                               |
      {0:  } 4. Repeat steps 2 through 4 until the sentence is correct.                    |
      {0:  }                                                                               |
      {7:✓ }{3:^The cow jumped over the moon.                                                  }|
      {0:  }                                                                               |
      {0:  } 5. Now that the line is correct, go on to Lesson 1.4.                         |
      {0:  }                                                                               |
      {0:  }{1:NOTE}: As you go through this tutorial, do not try to memorize everything,      |
      {0:  }      your Neovim vocabulary will expand with usage. Consider returning to     |
      {0:  }      this tutorial periodically for a refresher.                              |
      {0:  }                                                                               |
      {0:  }{3:#}{5: Lesson 1.4: TEXT EDITING: INSERTION}                                          |
      {0:  }                                                                               |
      {0:  }{1: Press }{12:i}{1: to insert text. }                                                      |
      {0:  }                                                                               |
      {0:  } 1. Move the cursor to the first line below marked {10:✗}.                          |
      {0:  }                                                                               |
      {0:  } 2. To make the first line the same as the second, move the cursor on top      |
      {0:  }    of the first character AFTER where the text is to be inserted.             |
      {0:  }                                                                               |
    ]])
  end)
end)
