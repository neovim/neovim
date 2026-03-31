local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed

describe(':digraphs', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(65, 8)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [4] = { bold = true },
      [5] = { background = Screen.colors.LightGrey },
      [6] = { foreground = Screen.colors.Blue1 },
      [7] = { bold = true, reverse = true },
    })
  end)

  it('displays digraphs', function()
    command('set more')
    feed(':digraphs<CR>')
    screen:expect([[
      :digraphs                                                        |
      NU {6:^@}  10    SH {6:^A}   1    SX {6:^B}   2    EX {6:^C}   3    ET {6:^D}   4    |
      EQ {6:^E}   5    AK {6:^F}   6    BL {6:^G}   7    BS {6:^H}   8    HT {6:^I}   9    |
      LF {6:^@}  10    VT {6:^K}  11    FF {6:^L}  12    CR {6:^M}  13    SO {6:^N}  14    |
      SI {6:^O}  15    DL {6:^P}  16    D1 {6:^Q}  17    D2 {6:^R}  18    D3 {6:^S}  19    |
      D4 {6:^T}  20    NK {6:^U}  21    SY {6:^V}  22    EB {6:^W}  23    CN {6:^X}  24    |
      EM {6:^Y}  25    SB {6:^Z}  26    EC {6:^[}  27    FS {6:^\}  28    GS {6:^]}  29    |
      {3:-- More --}^                                                       |
    ]])
  end)
end)
