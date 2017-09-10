local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local eval = helpers.eval
local feed_command = helpers.feed_command
local expect = helpers.expect
local feed = helpers.feed
local insert = helpers.insert
local meths = helpers.meths
local neq = helpers.neq
local ok = helpers.ok
local source = helpers.source
local wait = helpers.wait
local nvim = helpers.nvim

local multiline_text = [[
  1 2 3
  A B C
  4 5 6
  X Y Z
  7 8 9
]]

local multimatch_text  = [[
  a bdc eae a fgl lzia r
  x
]]

local multibyte_text = [[
 £ ¥ ѫѫ PEPPERS
£ ¥ ѫfѫ
 a£ ѫ¥KOL 
£ ¥  libm
£ ¥
]]

local long_multiline_text = [[
  1 2 3
  A B C
  4 5 6
  X Y Z
  7 8 9
  K L M
  a b c
  d e f
  q r s
  x y z
  £ m n
  t œ ¥
]]
local function common_setup(screen, inccommand, text)
  if screen then
    command("syntax on")
    command("set nohlsearch")
    command("hi Substitute guifg=red guibg=yellow")
    screen:attach()
    screen:set_default_attr_ids({
      [1]  = {foreground = Screen.colors.Fuchsia},
      [2]  = {foreground = Screen.colors.Brown, bold = true},
      [3]  = {foreground = Screen.colors.SlateBlue},
      [4]  = {bold = true, foreground = Screen.colors.SlateBlue},
      [5]  = {foreground = Screen.colors.DarkCyan},
      [6]  = {bold = true},
      [7]  = {underline = true, bold = true, foreground = Screen.colors.SlateBlue},
      [8]  = {foreground = Screen.colors.Slateblue, underline = true},
      [9]  = {background = Screen.colors.Yellow},
      [10] = {reverse = true},
      [11] = {reverse = true, bold=true},
      [12] = {foreground = Screen.colors.Red, background = Screen.colors.Yellow},
      [13] = {bold = true, foreground = Screen.colors.SeaGreen},
      [14] = {foreground = Screen.colors.White, background = Screen.colors.Red},
      [15] = {bold=true, foreground=Screen.colors.Blue},
      [16] = {background=Screen.colors.Grey90},  -- cursorline
      vis  = {background=Screen.colors.LightGrey}
    })
  end

  command("set inccommand=" .. (inccommand and inccommand or ""))

  if text then
    insert(text)
  end
end

describe(":substitute", function()
  local screen =  Screen.new(30,15)

  before_each(function()
    clear()
  end)

  it(", inccomand=split, highlights multiline substitutions", function()
    common_setup(screen, "split", multiline_text)
    feed("gg")

    feed(":%s/2\\_.*X/MMM")
    screen:expect([[
      1 {12:MMM} Y Z                     |
      7 8 9                         |
                                    |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |1| 1 {12:MMM} Y Z                 |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/2\_.*X/MMM^                |
    ]])

    feed("\\rK\\rLLL")
    screen:expect([[
      1 {12:MMM}                         |
      {12:K}                             |
      {12:LLL} Y Z                       |
      7 8 9                         |
                                    |
      {11:[No Name] [+]                 }|
      |1| 1 {12:MMM}                     |
      |2|{12: K}                         |
      |3|{12: LLL} Y Z                   |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/2\_.*X/MMM\rK\rLLL^        |
    ]])
  end)

  it(", inccomand=nosplit, highlights multiline substitutions", function()
    common_setup(screen, "nosplit", multiline_text)
    feed("gg")

    feed(":%s/2\\_.*X/MMM")
    screen:expect([[
      1 {12:MMM} Y Z                     |
      7 8 9                         |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/2\_.*X/MMM^                |
    ]])

    feed("\\rK\\rLLL")
    screen:expect([[
      1 {12:MMM}                         |
      {12:K}                             |
      {12:LLL} Y Z                       |
      7 8 9                         |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/2\_.*X/MMM\rK\rLLL^        |
    ]])
  end)

  it(", inccomand=split, highlights multiple matches on a line", function()
    common_setup(screen, "split", multimatch_text)
    command("set gdefault")
    feed("gg")

    feed(":%s/a/XLK")
    screen:expect([[
      {12:XLK} bdc e{12:XLK}e {12:XLK} fgl lzi{12:XLK} r|
      x                             |
                                    |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |1| {12:XLK} bdc e{12:XLK}e {12:XLK} fgl lzi{12:X}|
      {12:LK} r                          |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/a/XLK^                     |
    ]])
  end)

  it(", inccomand=nosplit, highlights multiple matches on a line", function()
    common_setup(screen, "nosplit", multimatch_text)
    command("set gdefault")
    feed("gg")

    feed(":%s/a/XLK")
    screen:expect([[
      {12:XLK} bdc e{12:XLK}e {12:XLK} fgl lzi{12:XLK} r|
      x                             |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/a/XLK^                     |
    ]])
  end)

  it(", inccomand=split, with \\zs", function()
    common_setup(screen, "split", multiline_text)
    feed("gg")

    feed(":%s/[0-9]\\n\\zs[A-Z]/OKO")
    screen:expect([[
      1 2 3                         |
      {12:OKO} B C                       |
      4 5 6                         |
      {12:OKO} Y Z                       |
      7 8 9                         |
      {11:[No Name] [+]                 }|
      |1| 1 2 3                     |
      |2| {12:OKO} B C                   |
      |3| 4 5 6                     |
      |4| {12:OKO} Y Z                   |
                                    |
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/[0-9]\n\zs[A-Z]/OKO^       |
    ]])
  end)

  it(", inccomand=nosplit, with \\zs", function()
    common_setup(screen, "nosplit", multiline_text)
    feed("gg")

    feed(":%s/[0-9]\\n\\zs[A-Z]/OKO")
    screen:expect([[
      1 2 3                         |
      {12:OKO} B C                       |
      4 5 6                         |
      {12:OKO} Y Z                       |
      7 8 9                         |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/[0-9]\n\zs[A-Z]/OKO^       |
    ]])
  end)

  it(", inccomand=split, substitutions of different length",
    function()
    common_setup(screen, "split", "T T123 T2T TTT T090804\nx")

    feed(":%s/T\\([0-9]\\+\\)/\\1\\1/g")
    screen:expect([[
      T {12:123123} {12:22}T TTT {12:090804090804} |
      x                             |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |1| T {12:123123} {12:22}T TTT {12:090804090}|
      {12:804}                           |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/T\([0-9]\+\)/\1\1/g^       |
    ]])
  end)

  it(", inccomand=nosplit, substitutions of different length", function()
    common_setup(screen, "nosplit", "T T123 T2T TTT T090804\nx")

    feed(":%s/T\\([0-9]\\+\\)/\\1\\1/g")
    screen:expect([[
      T {12:123123} {12:22}T TTT {12:090804090804} |
      x                             |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/T\([0-9]\+\)/\1\1/g^       |
    ]])
  end)

  it(", inccomand=split, contraction of lines", function()
    local text = [[
      T T123 T T123 T2T TT T23423424
      x
      afa Q
      adf la;lkd R
      alx
      ]]

    common_setup(screen, "split", text)
    feed(":%s/[QR]\\n")
    screen:expect([[
      afa Q                         |
      adf la;lkd R                  |
      alx                           |
                                    |
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |3| afa Q                     |
      |4| adf la;lkd R              |
      |5| alx                       |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/[QR]\n^                    |
    ]])
    
    feed("/KKK")
    screen:expect([[
      x                             |
      afa {12:KKK}adf la;lkd {12:KKK}alx      |
                                    |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |3| afa {12:KKK}adf la;lkd {12:KKK}alx  |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/[QR]\n/KKK^                |
    ]])
  end)

  it(", inccomand=nosplit, contraction of lines", function()
    local text = [[
      T T123 T T123 T2T TT T23423424
      x
      afa Q
      adf la;lkd R
      alx
      ]]

    common_setup(screen, "nosplit", text)
    feed(":%s/[QR]\\n/KKK")
    screen:expect([[
      T T123 T T123 T2T TT T23423424|
      x                             |
      afa {12:KKK}adf la;lkd {12:KKK}alx      |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/[QR]\n/KKK^                |
    ]])
  end)

  it(", inccommand=split, multibyte text", function()
    common_setup(screen, "split", multibyte_text)
    feed(":%s/£.*ѫ/X¥¥")
    screen:expect([[
      {12:X¥¥}                           |
       a{12:X¥¥}¥KOL                     |
      £ ¥  libm                     |
      £ ¥                           |
                                    |
      {11:[No Name] [+]                 }|
      |1|  {12:X¥¥} PEPPERS              |
      |2| {12:X¥¥}                       |
      |3|  a{12:X¥¥}¥KOL                 |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/£.*ѫ/X¥¥^                  |
    ]])

    feed("\\ra££   ¥")
    screen:expect([[
      {12:a££   ¥}                       |
       a{12:X¥¥}                         |
      {12:a££   ¥}¥KOL                   |
      £ ¥  libm                     |
      £ ¥                           |
      {11:[No Name] [+]                 }|
      |1|  {12:X¥¥}                      |
      |2|{12: a££   ¥} PEPPERS           |
      |3| {12:X¥¥}                       |
      |4|{12: a££   ¥}                   |
      |5|  a{12:X¥¥}                     |
      |6|{12: a££   ¥}¥KOL               |
                                    |
      {10:[Preview]                     }|
      :%s/£.*ѫ/X¥¥\ra££   ¥^         |
    ]])
  end)

  it(", inccommand=nosplit, multibyte text", function()
    common_setup(screen, "nosplit", multibyte_text)
    feed(":%s/£.*ѫ/X¥¥")
    screen:expect([[
       {12:X¥¥} PEPPERS                  |
      {12:X¥¥}                           |
       a{12:X¥¥}¥KOL                     |
      £ ¥  libm                     |
      £ ¥                           |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/£.*ѫ/X¥¥^                  |
    ]])

    feed("\\ra££   ¥")
    screen:expect([[
       {12:X¥¥}                          |
      {12:a££   ¥} PEPPERS               |
      {12:X¥¥}                           |
      {12:a££   ¥}                       |
       a{12:X¥¥}                         |
      {12:a££   ¥}¥KOL                   |
      £ ¥  libm                     |
      £ ¥                           |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      :%s/£.*ѫ/X¥¥\ra££   ¥^         |
    ]])
  end)

  it(", inccomand=split, small cmdwinheight", function()
    common_setup(screen, "split", long_multiline_text)
    command("set cmdwinheight=2")

    feed(":%s/[a-z]")
    screen:expect([[
      X Y Z                         |
      7 8 9                         |
      K L M                         |
      a b c                         |
      d e f                         |
      q r s                         |
      x y z                         |
      £ m n                         |
      t œ ¥                         |
                                    |
      {11:[No Name] [+]                 }|
      | 7| a b c                    |
      | 8| d e f                    |
      {10:[Preview]                     }|
      :%s/[a-z]^                     |
    ]])

    feed("/JLKR £")
    screen:expect([[
      X Y Z                         |
      7 8 9                         |
      K L M                         |
      {12:JLKR £} b c                    |
      {12:JLKR £} e f                    |
      {12:JLKR £} r s                    |
      {12:JLKR £} y z                    |
      £ {12:JLKR £} n                    |
      {12:JLKR £} œ ¥                    |
                                    |
      {11:[No Name] [+]                 }|
      | 7| {12:JLKR £} b c               |
      | 8| {12:JLKR £} e f               |
      {10:[Preview]                     }|
      :%s/[a-z]/JLKR £^              |
    ]])

    feed("\\rѫ ab   \\rXXXX")
    screen:expect([[
      7 8 9                         |
      K L M                         |
      {12:JLKR £}                        |
      {12:ѫ ab   }                       |
      {12:XXXX} b c                      |
      {12:JLKR £}                        |
      {12:ѫ ab   }                       |
      {12:XXXX} e f                      |
      {12:JLKR £}                        |
      {11:[No Name] [+]                 }|
      | 7| {12:JLKR £}                   |
      | 8|{12: ѫ ab   }                  |
      {10:[Preview]                     }|
      :%s/[a-z]/JLKR £\rѫ ab   \rXXX|
      X^                             |
    ]])
  end)

  it(", inccomand=split, large cmdwinheight", function()
    common_setup(screen, "split", long_multiline_text)
    command("set cmdwinheight=11")

    feed(":%s/. .$")
    screen:expect([[
      t œ ¥                         |
      {11:[No Name] [+]                 }|
      | 1| 1 2 3                    |
      | 2| A B C                    |
      | 3| 4 5 6                    |
      | 4| X Y Z                    |
      | 5| 7 8 9                    |
      | 6| K L M                    |
      | 7| a b c                    |
      | 8| d e f                    |
      | 9| q r s                    |
      |10| x y z                    |
      |11| £ m n                    |
      {10:[Preview]                     }|
      :%s/. .$^                      |
    ]])

    feed("/ YYY")
    screen:expect([[
      t {12: YYY}                        |
      {11:[No Name] [+]                 }|
      | 1| 1 {12: YYY}                   |
      | 2| A {12: YYY}                   |
      | 3| 4 {12: YYY}                   |
      | 4| X {12: YYY}                   |
      | 5| 7 {12: YYY}                   |
      | 6| K {12: YYY}                   |
      | 7| a {12: YYY}                   |
      | 8| d {12: YYY}                   |
      | 9| q {12: YYY}                   |
      |10| x {12: YYY}                   |
      |11| £ {12: YYY}                   |
      {10:[Preview]                     }|
      :%s/. .$/ YYY^                 |
    ]])

    feed("\\r KKK") 
    screen:expect([[
      a {12: YYY}                        |
      {11:[No Name] [+]                 }|
      | 1| 1 {12: YYY}                   |
      | 2|{12:  KKK}                     |
      | 3| A {12: YYY}                   |
      | 4|{12:  KKK}                     |
      | 5| 4 {12: YYY}                   |
      | 6|{12:  KKK}                     |
      | 7| X {12: YYY}                   |
      | 8|{12:  KKK}                     |
      | 9| 7 {12: YYY}                   |
      |10|{12:  KKK}                     |
      |11| K {12: YYY}                   |
      {10:[Preview]                     }|
      :%s/. .$/ YYY\r KKK^           |
    ]])
  end)

  it(", inccomand=split, lookaround", function()
    common_setup(screen, "split", "something\neverything\nsomeone")
    feed([[:%s/\(some\)\@<lt>=thing/one/]])
    screen:expect([[
      some{12:one}                       |
      everything                    |
      someone                       |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |1| some{12:one}                   |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/\(some\)\@<=thing/one/^    |
    ]])
    feed("<C-c>")

    feed([[:%s/\(some\)\@<lt>!thing/one/]])
    screen:expect([[
      something                     |
      every{12:one}                      |
      someone                       |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |2| every{12:one}                  |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/\(some\)\@<!thing/one/^    |
    ]])
    feed([[<C-c>]])

    feed([[:%s/some\(thing\)\@=/every/]])
    screen:expect([[
      {12:every}thing                    |
      everything                    |
      someone                       |
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |1| {12:every}thing                |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/some\(thing\)\@=/every/^   |
    ]])
    feed([[<C-c>]])

    feed([[:%s/some\(thing\)\@!/every/]])
    screen:expect([[
      everything                    |
      {12:every}one                      |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {11:[No Name] [+]                 }|
      |3| {12:every}one                  |
                                    |
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {15:~                             }|
      {10:[Preview]                     }|
      :%s/some\(thing\)\@!/every/^   |
    ]])
  end)
end)
