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
  end)

  it('displays digraphs', function()
    command('set more')
    feed(':digraphs<CR>')
    screen:expect([[
      :digraphs                                                        |
      NU {18:^@}  10    SH {18:^A}   1    SX {18:^B}   2    EX {18:^C}   3    ET {18:^D}   4    |
      EQ {18:^E}   5    AK {18:^F}   6    BL {18:^G}   7    BS {18:^H}   8    HT {18:^I}   9    |
      LF {18:^@}  10    VT {18:^K}  11    FF {18:^L}  12    CR {18:^M}  13    SO {18:^N}  14    |
      SI {18:^O}  15    DL {18:^P}  16    D1 {18:^Q}  17    D2 {18:^R}  18    D3 {18:^S}  19    |
      D4 {18:^T}  20    NK {18:^U}  21    SY {18:^V}  22    EB {18:^W}  23    CN {18:^X}  24    |
      EM {18:^Y}  25    SB {18:^Z}  26    EC {18:^[}  27    FS {18:^\}  28    GS {18:^]}  29    |
      {6:-- More --}^                                                       |
    ]])
  end)
end)
