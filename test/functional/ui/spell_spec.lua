-- Test for scenarios involving 'spell'

local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local exec = t.exec
local feed = t.feed
local insert = t.insert
local api = t.api
local is_os = t.is_os

describe("'spell'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(80, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { special = Screen.colors.Red, undercurl = true },
      [2] = { special = Screen.colors.Blue, undercurl = true },
      [3] = { foreground = tonumber('0x6a0dad') },
      [4] = { foreground = Screen.colors.Magenta },
      [5] = { bold = true, foreground = Screen.colors.SeaGreen },
      [6] = { foreground = Screen.colors.Red },
      [7] = { foreground = Screen.colors.Blue },
      [8] = { foreground = Screen.colors.Blue, special = Screen.colors.Red, undercurl = true },
      [9] = { bold = true },
      [10] = { background = Screen.colors.LightGrey, foreground = Screen.colors.DarkBlue },
    })
  end)

  it('joins long lines #7937', function()
    if is_os('openbsd') then
      pending('FIXME #12104', function() end)
      return
    end
    exec('set spell')
    insert([[
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
    consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
    cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat
    non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    ]])
    feed('ggJJJJJJ0')
    screen:expect([[
    {1:^Lorem} {1:ipsum} dolor sit {1:amet}, {1:consectetur} {1:adipiscing} {1:elit}, {1:sed} do {1:eiusmod} {1:tempor} {1:i}|
    {1:ncididunt} {1:ut} {1:labore} et {1:dolore} {1:magna} {1:aliqua}. {1:Ut} {1:enim} ad minim {1:veniam}, {1:quis} {1:nostru}|
    {1:d} {1:exercitation} {1:ullamco} {1:laboris} {1:nisi} {1:ut} {1:aliquip} ex ea {1:commodo} {1:consequat}. {1:Duis} {1:aut}|
    {1:e} {1:irure} dolor in {1:reprehenderit} in {1:voluptate} {1:velit} {1:esse} {1:cillum} {1:dolore} {1:eu} {1:fugiat} {1:n}|
    {1:ulla} {1:pariatur}. {1:Excepteur} {1:sint} {1:occaecat} {1:cupidatat} non {1:proident}, {1:sunt} in culpa {1:qui}|
     {1:officia} {1:deserunt} {1:mollit} {1:anim} id est {1:laborum}.                                   |
    {0:~                                                                               }|
                                                                                    |
    ]])
  end)

  -- oldtest: Test_spell_screendump()
  it('has correct highlight at start of line', function()
    exec([=[
      call setline(1, [
        \"This is some text without any spell errors.  Everything",
        \"should just be black, nothing wrong here.",
        \"",
        \"This line has a sepll error. and missing caps.",
        \"And and this is the the duplication.",
        \"with missing caps here.",
      \])
      set spell spelllang=en_nz
    ]=])
    screen:expect([[
      ^This is some text without any spell errors.  Everything                         |
      should just be black, nothing wrong here.                                       |
                                                                                      |
      This line has a {1:sepll} error. {2:and} missing caps.                                  |
      {1:And and} this is {1:the the} duplication.                                            |
      {2:with} missing caps here.                                                         |
      {0:~                                                                               }|
                                                                                      |
    ]])
  end)

  -- oldtest: Test_spell_screendump_spellcap()
  it('SpellCap highlight at start of line', function()
    exec([=[
      call setline(1, [
        \"   This line has a sepll error. and missing caps and trailing spaces.   ",
        \"another missing cap here.",
        \"",
        \"and here.",
        \"    ",
        \"and here."
      \])
      set spell spelllang=en
    ]=])
    screen:expect([[
      ^   This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap here.                                                       |
                                                                                      |
      {2:and} here.                                                                       |
                                                                                      |
      {2:and} here.                                                                       |
      {0:~                                                                               }|
                                                                                      |
    ]])
    -- After adding word missing Cap in next line is updated
    feed('3GANot<Esc>')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap here.                                                       |
      No^t                                                                             |
      and here.                                                                       |
                                                                                      |
      {2:and} here.                                                                       |
      {0:~                                                                               }|
                                                                                      |
    ]])
    -- Deleting a full stop removes missing Cap in next line
    feed('5Gdd<C-L>k$x')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap here.                                                       |
      Not                                                                             |
      and her^e                                                                        |
      and here.                                                                       |
      {0:~                                                                               }|*2
                                                                                      |
    ]])
    -- Undo also updates the next line (go to command line to remove message)
    feed('u:<Esc>')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap here.                                                       |
      Not                                                                             |
      and here^.                                                                       |
      {2:and} here.                                                                       |
      {0:~                                                                               }|*2
                                                                                      |
    ]])
    -- Folding an empty line does not remove Cap in next line
    feed('uzfk:<Esc>')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap here.                                                       |
      Not                                                                             |
      {10:^+--  2 lines: and here.·························································}|
      {2:and} here.                                                                       |
      {0:~                                                                               }|*2
                                                                                      |
    ]])
    -- Folding the end of a sentence does not remove Cap in next line
    -- and editing a line does not remove Cap in current line
    feed('Jzfkk$x')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      {2:another} missing cap her^e                                                        |
      {10:+--  2 lines: Not·······························································}|
      {2:and} here.                                                                       |
      {0:~                                                                               }|*3
                                                                                      |
    ]])
    -- Cap is correctly applied in the first row of a window
    feed('<C-E><C-L>')
    screen:expect([[
      {2:another} missing cap her^e                                                        |
      {10:+--  2 lines: Not·······························································}|
      {2:and} here.                                                                       |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    -- Adding an empty line does not remove Cap in "mod_bot" area
    feed('zbO<Esc>')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      ^                                                                                |
      {2:another} missing cap here                                                        |
      {10:+--  2 lines: Not·······························································}|
      {2:and} here.                                                                       |
      {0:~                                                                               }|*2
                                                                                      |
    ]])
    -- Multiple empty lines does not remove Cap in the line after
    feed('O<Esc><C-L>')
    screen:expect([[
         This line has a {1:sepll} error. {2:and} missing caps and trailing spaces.           |
      ^                                                                                |
                                                                                      |
      {2:another} missing cap here                                                        |
      {10:+--  2 lines: Not·······························································}|
      {2:and} here.                                                                       |
      {0:~                                                                               }|
                                                                                      |
    ]])
  end)

  -- oldtest: Test_spell_compatible()
  it([[redraws properly when using "C" and "$" is in 'cpo']], function()
    exec([=[
      call setline(1, [
        \ "test "->repeat(20),
        \ "",
        \ "end",
      \ ])
      set spell cpo+=$
    ]=])
    feed('51|C')
    screen:expect([[
      {2:test} test test test test test test test test test ^test test test test test test |
      test test test test$                                                            |
                                                                                      |
      {2:end}                                                                             |
      {0:~                                                                               }|*3
      {9:-- INSERT --}                                                                    |
    ]])
    feed('x')
    screen:expect([[
      {2:test} test test test test test test test test test x^est test test test test test |
      test test test test$                                                            |
                                                                                      |
      {2:end}                                                                             |
      {0:~                                                                               }|*3
      {9:-- INSERT --}                                                                    |
    ]])
  end)

  it('extmarks, "noplainbuffer" and syntax #20385 #23398', function()
    exec('set filetype=c')
    exec('syntax on')
    exec('set spell')
    insert([[
      #include <stdbool.h>
      bool func(void);
      // I am a speling mistakke]])
    feed('ge')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:spelin^g}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:speling}{7: }{8:^mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:^speling}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
      {6:search hit BOTTOM, continuing at TOP}                                            |
    ]])
    exec('echo ""')
    local ns = api.nvim_create_namespace('spell')
    -- extmark with spell=true enables spell
    local id = api.nvim_buf_set_extmark(0, ns, 1, 4, { end_row = 1, end_col = 10, spell = true })
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} {1:func}({5:void});                                                                |
      {7:// I am a }{8:^speling}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} {1:^func}({5:void});                                                                |
      {7:// I am a }{8:speling}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    api.nvim_buf_del_extmark(0, ns, id)
    -- extmark with spell=false disables spell
    id = api.nvim_buf_set_extmark(0, ns, 2, 18, { end_row = 2, end_col = 26, spell = false })
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} ^func({5:void});                                                                |
      {7:// I am a }{8:speling}{7: mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:^speling}{7: mistakke}                                                      |
      {0:~                                                                               }|*4
      {6:search hit TOP, continuing at BOTTOM}                                            |
    ]])
    exec('echo ""')
    api.nvim_buf_del_extmark(0, ns, id)
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:^speling}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:speling}{7: }{8:^mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    -- "noplainbuffer" shouldn't change spellchecking behavior with syntax enabled
    exec('set spelloptions+=noplainbuffer')
    screen:expect_unchanged()
    feed('[s')
    screen:expect([[
      {3:#include }{4:<stdbool.h>}                                                            |
      {5:bool} func({5:void});                                                                |
      {7:// I am a }{8:^speling}{7: }{8:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    -- no spellchecking with "noplainbuffer" and syntax disabled
    exec('syntax off')
    screen:expect([[
      #include <stdbool.h>                                                            |
      bool func(void);                                                                |
      // I am a ^speling mistakke                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      #include <stdbool.h>                                                            |
      bool func(void);                                                                |
      // I am a ^speling mistakke                                                      |
      {0:~                                                                               }|*4
      {6:search hit BOTTOM, continuing at TOP}                                            |
    ]])
    exec('echo ""')
    -- everything is spellchecked without "noplainbuffer" with syntax disabled
    exec('set spelloptions&')
    screen:expect([[
      #include <{1:stdbool}.h>                                                            |
      {1:bool} {1:func}(void);                                                                |
      // I am a {1:^speling} {1:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      #include <{1:stdbool}.h>                                                            |
      {1:bool} {1:^func}(void);                                                                |
      // I am a {1:speling} {1:mistakke}                                                      |
      {0:~                                                                               }|*4
                                                                                      |
    ]])
  end)

  it('and syntax does not clear extmark highlighting at the start of a word', function()
    screen:try_resize(43, 3)
    exec([[
      set spell
      syntax match Constant "^.*$"
      call setline(1, "This is some text without any spell errors.")
    ]])
    local ns = api.nvim_create_namespace('spell')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { hl_group = 'WarningMsg', end_col = 43 })
    screen:expect([[
      {6:^This is some text without any spell errors.}|
      {0:~                                          }|
                                                 |
    ]])
  end)
end)
