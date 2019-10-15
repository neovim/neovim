local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local feed_command = helpers.feed_command
local insert = helpers.insert
local funcs = helpers.funcs

describe("multibyte rendering", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 6)
    screen:attach({rgb=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {background = Screen.colors.WebGray},
      [3] = {background = Screen.colors.LightMagenta},
      [4] = {bold = true},
    })
  end)

  it("works with composed char at start of line", function()
    insert([[
      ̊
      x]])
    feed("gg")
     -- verify the modifier infact is alone
    feed_command("ascii")
    screen:expect([[
      ^ ̊                                                           |
      x                                                           |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      < ̊> 778, Hex 030a, Octal 1412                               |
    ]])

    -- a char inserted before will spontaneously merge with it
    feed("ia<esc>")
    feed_command("ascii")
    screen:expect([[
      ^å                                                           |
      x                                                           |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      <a>  97,  Hex 61,  Octal 141 < ̊> 778, Hex 030a, Octal 1412  |
    ]])
  end)

  it('works with doublewidth char at end of line', function()
    feed('58a <esc>a馬<esc>')
    screen:expect([[
                                                                ^馬|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])

    feed('i <esc>')
    screen:expect([[
                                                                ^ {1:>}|
      馬                                                          |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])

    feed('l')
    screen:expect([[
                                                                 {1:>}|
      ^馬                                                          |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])
  end)

  it('clears left half of double-width char when right half is overdrawn', function()
    feed('o-馬<esc>ggiab ')
    screen:expect([[
      ab ^                                                         |
      -馬                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])

    -- check double-with char is temporarily hidden when overlapped
    funcs.complete(4, {'xx', 'yy'})
    screen:expect([[
      ab xx^                                                       |
      - {2: xx             }                                          |
      {1:~ }{3: yy             }{1:                                          }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])

    -- check it is properly restored
    feed('z')
    screen:expect([[
      ab xxz^                                                      |
      -馬                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- INSERT --}                                                |
    ]])
  end)
end)

describe('multibyte rendering: statusline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 4)
    screen:attach()
    command('set laststatus=2')
  end)

  it('last char shows (multibyte)', function()
    command('set statusline=你好')
    screen:expect([[
    ^                                        |
    ~                                       |
    你好                                    |
                                            |
    ]])
  end)
  it('last char shows (single byte)', function()
    command('set statusline=abc')
    screen:expect([[
    ^                                        |
    ~                                       |
    abc                                     |
                                            |
    ]])
  end)
  it('unicode control points', function()
    command('set statusline=')
    screen:expect([[
    ^                                        |
    ~                                       |
    <9f>                                    |
                                            |
    ]])
  end)
  it('MAX_MCO (6) unicode combination points', function()
    command('set statusline=o̸⃯ᷰ⃐⃧⃝')
    -- o + U+1DF0 + U+20EF + U+0338 + U+20D0 + U+20E7 + U+20DD
    screen:expect([[
    ^                                        |
    ~                                       |
    o̸⃯ᷰ⃐⃧⃝                                       |
                                            |
    ]])
  end)
  it('non-printable followed by MAX_MCO unicode combination points', function()
    command('set statusline=̸⃯ᷰ⃐⃧⃝')
    -- U+9F + U+1DF0 + U+20EF + U+0338 + U+20D0 + U+20E7 + U+20DD
    screen:expect([[
    ^                                        |
    ~                                       |
    <9f><1df0><20ef><0338><20d0><20e7><20dd>|
                                            |
    ]])
  end)
end)
