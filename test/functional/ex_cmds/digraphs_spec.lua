local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local feed = helpers.feed
local Screen = require('test.functional.ui.screen')

describe(':digraphs', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(65, 8)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [4] = {bold = true},
      [5] = {background = Screen.colors.LightGrey},
      [6] = {foreground = Screen.colors.Blue1},
      [7] = {bold = true, reverse = true},
    })
    screen:attach()
  end)

  it('displays digraphs', function()
    feed(':digraphs<CR>')
    screen:expect([[
      E` {6:È}  200    E^ {6:Ê}  202    E" {6:Ë}  203    I` {6:Ì}  204    I^ {6:Î}  206    |
      I" {6:Ï}  207    N~ {6:Ñ}  209    O` {6:Ò}  210    O^ {6:Ô}  212    O~ {6:Õ}  213    |
      /\ {6:×}  215    U` {6:Ù}  217    U^ {6:Û}  219    Ip {6:Þ}  222    a` {6:à}  224    |
      a^ {6:â}  226    a~ {6:ã}  227    a" {6:ä}  228    a@ {6:å}  229    e` {6:è}  232    |
      e^ {6:ê}  234    e" {6:ë}  235    i` {6:ì}  236    i^ {6:î}  238    n~ {6:ñ}  241    |
      o` {6:ò}  242    o^ {6:ô}  244    o~ {6:õ}  245    u` {6:ù}  249    u^ {6:û}  251    |
      y" {6:ÿ}  255                                                        |
      {3:Press ENTER or type command to continue}^                          |
    ]])
  end)

end)

