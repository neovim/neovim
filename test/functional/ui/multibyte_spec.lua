local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed
local feed_command = n.feed_command
local insert = n.insert
local fn = n.fn
local api = n.api
local split = vim.split
local dedent = t.dedent

describe('multibyte rendering', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 6)
    screen:attach({ rgb = true })
  end)

  it('works with composed char at start of line', function()
    insert([[
      ̊
      x]])
    feed('gg')
    -- verify the modifier in fact is alone
    feed_command('ascii')
    screen:expect([[
      ^ ̊                                                           |
      x                                                           |
      {1:~                                                           }|*3
      < ̊> 778, Hex 030a, Octal 1412                               |
    ]])

    -- a char inserted before will spontaneously merge with it
    feed('ia<esc>')
    feed_command('ascii')
    screen:expect([[
      ^å                                                           |
      x                                                           |
      {1:~                                                           }|*3
      <a>  97,  Hex 61,  Octal 141 < ̊> 778, Hex 030a, Octal 1412  |
    ]])
  end)

  it('works with doublewidth char at end of line', function()
    feed('58a <esc>a馬<esc>')
    screen:expect([[
                                                                ^馬|
      {1:~                                                           }|*4
                                                                  |
    ]])

    feed('i <esc>')
    screen:expect([[
                                                                ^ {1:>}|
      馬                                                          |
      {1:~                                                           }|*3
                                                                  |
    ]])

    feed('l')
    screen:expect([[
                                                                 {1:>}|
      ^馬                                                          |
      {1:~                                                           }|*3
                                                                  |
    ]])
  end)

  it('clears left half of double-width char when right half is overdrawn', function()
    feed('o-馬<esc>ggiab ')
    screen:expect([[
      ab ^                                                         |
      -馬                                                         |
      {1:~                                                           }|*3
      {5:-- INSERT --}                                                |
    ]])

    -- check double-width char is temporarily hidden when overlapped
    fn.complete(4, { 'xx', 'yy' })
    screen:expect([[
      ab xx^                                                       |
      - {12: xx             }                                          |
      {1:~ }{4: yy             }{1:                                          }|
      {1:~                                                           }|*2
      {5:-- INSERT --}                                                |
    ]])

    -- check it is properly restored
    feed('z')
    screen:expect([[
      ab xxz^                                                      |
      -馬                                                         |
      {1:~                                                           }|*3
      {5:-- INSERT --}                                                |
    ]])
  end)

  it('no stray chars when splitting left of window with double-width chars', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('口'):rep(16),
      'a' .. ('口'):rep(16),
      'aa' .. ('口'):rep(16),
      'aaa' .. ('口'):rep(16),
      'aaaa' .. ('口'):rep(16),
    })
    screen:expect([[
      ^口口口口口口口口口口口口口口口口                            |
      a口口口口口口口口口口口口口口口口                           |
      aa口口口口口口口口口口口口口口口口                          |
      aaa口口口口口口口口口口口口口口口口                         |
      aaaa口口口口口口口口口口口口口口口口                        |
                                                                  |
    ]])

    command('20vnew')
    screen:expect([[
      ^                    │口口口口口口口口口口口口口口口口       |
      {1:~                   }│a口口口口口口口口口口口口口口口口      |
      {1:~                   }│aa口口口口口口口口口口口口口口口口     |
      {1:~                   }│aaa口口口口口口口口口口口口口口口口    |
      {3:[No Name]            }{2:[No Name] [+]                          }|
                                                                  |
    ]])
  end)

  it('0xffff is shown as 4 hex digits', function()
    command([[call setline(1, "\uFFFF!!!")]])
    feed('$')
    screen:expect {
      grid = [[
      {18:<ffff>}!!^!                                                   |
      {1:~                                                           }|*4
                                                                  |
    ]],
    }
  end)

  it('works with a lot of unicode (zalgo) text', function()
    screen:try_resize(65, 10)
    api.nvim_buf_set_lines(
      0,
      0,
      -1,
      true,
      split(
        dedent [[
      L̓̉̑̒̌̚ơ̗̌̒̄̀ŕ̈̈̎̐̕è̇̅̄̄̐m̖̟̟̅̄̚ ̛̓̑̆̇̍i̗̟̞̜̅̐p̗̞̜̉̆̕s̟̜̘̍̑̏ū̟̞̎̃̉ḿ̘̙́́̐ ̖̍̌̇̉̚d̞̄̃̒̉̎ò́̌̌̂̐l̞̀̄̆̌̚ȯ̖̞̋̀̐r̓̇̌̃̃̚ ̗̘̀̏̍́s̜̀̎̎̑̕i̟̗̐̄̄̚t̝̎̆̓̐̒ ̘̇̔̓̊̚ȃ̛̟̗̏̅m̜̟̙̞̈̓é̘̞̟̔̆t̝̂̂̈̑̔,̜̜̖̅̄̍ ̛̗̊̓̆̚c̟̍̆̍̈̔ȯ̖̖̝̑̀n̜̟̎̊̃̚s̟̏̇̎̒̚e̙̐̈̓̌̚c̙̍̈̏̅̕ť̇̄̇̆̓e̛̓̌̈̓̈t̟̍̀̉̆̅u̝̞̎̂̄̚r̘̀̅̈̅̐ ̝̞̓́̇̉ã̏̀̆̅̕d̛̆̐̉̆̋ȉ̞̟̍̃̚p̛̜̊̍̂̓ȋ̏̅̃̋̚ṥ̛̏̃̕č̛̞̝̀̂í̗̘̌́̎n̔̎́̒̂̕ǧ̗̜̋̇̂ ̛̜̔̄̎̃ê̛̔̆̇̕l̘̝̏̐̊̏ĩ̛̍̏̏̄t̟̐́̀̐̎,̙̘̍̆̉̐ ̋̂̏̄̌̅s̙̓̌̈́̇e̛̗̋̒̎̏d̜̗̊̍̊̚
      ď̘̋̌̌̕ǒ̝̗̔̇̕ ̙̍́̄̄̉è̛̛̞̌̌i̜̖̐̈̆̚ȕ̇̈̓̃̓ŝ̛̞̙̉̋m̜̐̂̄̋̂ȯ̈̎̎̅̕d̜̙̓̔̋̑ ̞̗̄̂̂̚t̝̊́̃́̄e̛̘̜̞̓̑m̊̅̏̉̌̕p̛̈̂̇̀̐ỏ̙̘̈̉̔r̘̞̋̍̃̚ ̝̄̀̇̅̇ỉ̛̖̍̓̈n̛̛̝̎̕̕c̛̛̊̅́̐ĭ̗̓̀̍̐d̞̜̋̐̅̚i̟̙̇̄̊̄d̞̊̂̀̇̚ủ̝̉̑̃̕n̜̏̇̄̐̋ť̗̜̞̋̉ ̝̒̓̌̓̚ȕ̖̙̀̚̕t̖̘̎̉̂̌ ̛̝̄̍̌̂l̛̟̝̃̑̋á̛̝̝̔̅b̝̙̜̗̅̒ơ̖̌̒̄̆r̒̇̓̎̈̄e̛̛̖̅̏̇ ̖̗̜̝̃́e̛̛̘̅̔̌ẗ̛̙̗̐̕ ̖̟̇̋̌̈d̞̙̀̉̑̕ŏ̝̂́̐̑l̞̟̗̓̓̀ơ̘̎̃̄̂r̗̗̖̔̆̍ẻ̖̝̞̋̅ ̜̌̇̍̈̊m̈̉̇̄̒̀a̜̞̘̔̅̆g̗̖̈̃̈̉n̙̖̄̈̉̄â̛̝̜̄̃ ̛́̎̕̕̚ā̊́́̆̌l̟̙̞̃̒́i̖̇̎̃̀̋q̟̇̒̆́̊ủ́̌̇̑̚ã̛̘̉̐̚.̛́̏̐̍̊
      U̝̙̎̈̐̆t̜̍̌̀̔̏ ̞̉̍̇̈̃e̟̟̊̄̕̕n̝̜̒̓̆̕i̖̒̌̅̇̚m̞̊̃̔̊̂ ̛̜̊̎̄̂a̘̜̋̒̚̚d̟̊̎̇̂̍ ̜̖̏̑̉̕m̜̒̎̅̄̚i̝̖̓̂̍̕n̙̉̒̑̀̔ỉ̖̝̌̒́m̛̖̘̅̆̎ ̖̉̎̒̌̕v̖̞̀̔́̎e̖̙̗̒̎̉n̛̗̝̎̀̂ȉ̞̗̒̕̚ȧ̟̜̝̅̚m̆̉̐̐̇̈,̏̐̎́̍́ ̜̞̙̘̏̆q̙̖̙̅̓̂ủ̇́̀̔̚í̙̟̟̏̐s̖̝̍̏̂̇ ̛̘̋̈̕̕ń̛̞̜̜̎o̗̜̔̔̈̆s̞̘̘̄̒̋t̛̅̋́̔̈ȓ̓̒́̇̅ủ̜̄̃̒̍d̙̝̘̊̏̚ ̛̟̞̄́̔e̛̗̝̍̃̀x̞̖̃̄̂̅e̖̅̇̐̔̃r̗̞̖̔̎̚c̘̜̖̆̊̏ï̙̝̙̂̕t̖̏́̓̋̂ă̖̄̆̑̒t̜̟̍̉̑̏i̛̞̞̘̒̑ǒ̜̆̅̃̉ṅ̖̜̒̎̚
      u̗̞̓̔̈̏ĺ̟̝́̎̚l̛̜̅̌̎̆a̒̑̆̔̇̃m̜̗̈̊̎̚ċ̘̋̇̂̚ơ̟̖̊́̕ ̖̟̍̉̏̚l̙̔̓̀̅̏ä̞̗̘̙̅ḃ̟̎̄̃̕o̞̎̓̓̓̚r̗̜̊̓̈̒ï̗̜̃̃̅s̀̒̌̂̎̂ ̖̗̗̋̎̐n̝̟̝̘̄̚i̜̒̀̒̐̕s̘̘̄̊̃̀ī̘̜̏̌̕ ̗̖̞̐̈̒ư̙̞̄́̌t̟̘̖̙̊̚ ̌̅̋̆̚̚ä̇̊̇̕̕l̝̞̘̋̔̅i̍̋́̆̑̈q̛̆̐̈̐̚ư̏̆̊́̚î̜̝̑́̊p̗̓̅̑̆̏ ̆́̓̔̋̋e̟̊̋̏̓̚x̗̍̑̊̎̈ ̟̞̆̄̂̍ë̄̎̄̃̅a̛̜̅́̃̈ ̔̋̀̎̐̀c̖̖̍̀̒̂ơ̛̙̖̄̒m̘̔̍̏̆̕ḿ̖̙̝̏̂ȍ̓̋̈̀̕d̆̂̊̅̓̚o̖̔̌̑̚̕ ̙̆́̔̊̒c̖̘̖̀̄̍o̓̄̑̐̓̒ñ̞̒̎̈̚s̞̜̘̈̄̄e̙̊̀̇̌̋q̐̒̓́̔̃ư̗̟̔̔̚å̖̙̞̄̏t̛̙̟̒̇̏.̙̗̓̃̓̎
      D̜̖̆̏̌̌ư̑̃̌̍̕i̝̊̊̊̊̄s̛̙̒́̌̇ ̛̃̔̄̆̌ă̘̔̅̅̀ú̟̟̟̃̃t̟̂̄̈̈̃e̘̅̌̒̂̆ ̖̟̐̉̉̌î̟̟̙̜̇r̛̙̞̗̄̌ú̗̗̃̌̎r̛̙̘̉̊̕e̒̐̔̃̓̋ ̊̊̍̋̑̉d̛̝̙̉̀̓o̘̜̐̐̓̐l̞̋̌̆̍́o̊̊̐̃̃̚ṙ̛̖̘̃̕ ̞̊̀̍̒̕ȉ́̑̐̇̅ǹ̜̗̜̞̏ ̛̜̐̄̄̚r̜̖̈̇̅̋ĕ̗̉̃̔̚p̟̝̀̓̔̆r̜̈̆̇̃̃e̘̔̔̏̎̓h̗̒̉̑̆̚ė̛̘̘̈̐n̘̂̀̒̕̕d̗̅̂̋̅́ê̗̜̜̜̕r̟̋̄̐̅̂i̛̔̌̒̂̕t̛̗̓̎̀̎ ̙̗̀̉̂̚ȉ̟̗̐̓̚n̙̂̍̏̓̉ ̙̘̊̋̍̕v̜̖̀̎̆̐ő̜̆̉̃̎l̑̋̒̉̔̆ư̙̓̓́̚p̝̘̖̎̏̒t̛̘̝̞̂̓ȁ̘̆̔́̊t̖̝̉̒̐̎e̞̟̋̀̅̄ ̆̌̃̀̑̔v̝̘̝̍̀̇ȅ̝̊̄̓̕l̞̝̑̔̂̋ĭ̝̄̅̆̍t̝̜̉̂̈̇
      ē̟̊̇̕̚s̖̘̘̒̄̑s̛̘̀̊̆̇e̛̝̘̒̏̚ ̉̅̑̂̐̎c̛̟̙̎̋̓i̜̇̒̏̆̆l̟̄́̆̊̌l̍̊̋̃̆̌ủ̗̙̒̔̚m̛̘̘̖̅̍ ̖̙̈̎̂̕d̞̟̏̋̈̔ơ̟̝̌̃̄l̗̙̝̂̉̒õ̒̃̄̄̚ŕ̗̏̏̊̍ê̞̝̞̋̈ ̜̔̒̎̃̚e̞̟̞̒̃̄ư̖̏̄̑̃ ̛̗̜̄̓̎f̛̖̞̅̓̃ü̞̏̆̋̕g̜̝̞̑̑̆i̛̘̐̐̅̚à̜̖̌̆̎t̙̙̎̉̂̍ ̋̔̈̎̎̉n̞̓́̔̊̕ư̘̅̋̔̚l̗̍̒̄̀̚l̞̗̘̙̓̍â̘̔̒̎̚ ̖̓̋̉̃̆p̛̛̘̋̌̀ä̙̔́̒̕r̟̟̖̋̐̋ì̗̙̎̓̓ȃ̔̋̑̚̕t̄́̎̓̂̋ư̏̈̂̑̃r̖̓̋̊̚̚.̒̆̑̆̊̎ ̘̜̍̐̂̚E̞̅̐̇́̂x̄́̈̌̉̕ć̘̃̉̃̕è̘̂̑̏̑p̝̘̑̂̌̆t̔̐̅̍̌̂ȇ̞̈̐̚̕ű̝̞̜́̚ŕ̗̝̉̆́
      š̟́̔̏̀ȉ̝̟̝̏̅n̑̆̇̒̆̚t̝̒́̅̋̏ ̗̑̌̋̇̚ơ̙̗̟̆̅c̙̞̙̎̊̎c̘̟̍̔̊̊a̛̒̓̉́̐e̜̘̙̒̅̇ć̝̝̂̇̕ả̓̍̎̂̚t̗̗̗̟̒̃ ̘̒̓̐̇́c̟̞̉̐̓̄ȕ̙̗̅́̏p̛̍̋̈́̅i̖̓̒̍̈̄d̞̃̈̌̆̐a̛̗̝̎̋̉t̞̙̀̊̆̇a̛̙̒̆̉̚t̜̟̘̉̓̚ ̝̘̗̐̇̕n̛̘̑̏̂́ō̑̋̉̏́ň̞̊̆̄̃ ̙̙̙̜̄̏p̒̆̋̋̓̏r̖̖̅̉́̚ơ̜̆̑̈̚i̟̒̀̃̂̌d̛̏̃̍̋̚ë̖̞̙̗̓n̛̘̓̒̅̎t̟̗̙̊̆̚,̘̙̔̊̚̕ ̟̗̘̜̑̔s̜̝̍̀̓̌û̞̙̅̇́n̘̗̝̒̃̎t̗̅̀̅̊̈ ̗̖̅̅̀̄i̛̖̍̅̋̂n̙̝̓̓̎̚ ̞̋̅̋̃̚c̗̒̀̆̌̎ū̞̂̑̌̓ĺ̛̐̍̑́p̝̆̌̎̈̚a̖̙̒̅̈̌ ̝̝̜̂̈̀q̝̖̔̍̒̚ư̔̐̂̎̊ǐ̛̟̖̘̕
      o̖̜̔̋̅̚f̛̊̀̉́̕f̏̉̀̔̃̃i̘̍̎̐̔̎c̙̅̑̂̐̅ȋ̛̜̀̒̚a̋̍̇̏̀̋ ̖̘̒̅̃̒d̗̘̓̈̇̋é̝́̎̒̄š̙̒̊̉̋e̖̓̐̀̍̕r̗̞̂̅̇̄ù̘̇̐̉̀n̐̑̀̄̍̐t̟̀̂̊̄̚ ̟̝̂̍̏́m̜̗̈̂̏̚ő̞̊̑̇̒l̘̑̏́̔̄l̛̛̇̃̋̊i̓̋̒̃̉̌t̛̗̜̏̀̋ ̙̟̒̂̌̐a̙̝̔̆̏̅n̝̙̙̗̆̅i̍̔́̊̃̕m̖̝̟̒̍̚ ̛̃̃̑̌́ǐ̘̉̔̅̚d̝̗̀̌̏̒ ̖̝̓̑̊̚ȇ̞̟̖̌̕š̙̙̈̔̀t̂̉̒̍̄̄ ̝̗̊̋̌̄l̛̞̜̙̘̔å̝̍̂̍̅b̜̆̇̈̉̌ǒ̜̙̎̃̆r̝̀̄̍́̕ư̋̊́̊̕m̜̗̒̐̕̚.̟̘̀̒̌̚]],
        '\n'
      )
    )

    -- tests that we can handle overflow of the buffer
    -- for redraw events (4096 bytes) gracefully
    screen:expect {
      grid = [[
      ^L̓̉̑̒̌̚ơ̗̌̒̄̀ŕ̈̈̎̐̕è̇̅̄̄̐m̖̟̟̅̄̚ ̛̓̑̆̇̍i̗̟̞̜̅̐p̗̞̜̉̆̕s̟̜̘̍̑̏ū̟̞̎̃̉ḿ̘̙́́̐ ̖̍̌̇̉̚d̞̄̃̒̉̎ò́̌̌̂̐l̞̀̄̆̌̚ȯ̖̞̋̀̐r̓̇̌̃̃̚ ̗̘̀̏̍́s̜̀̎̎̑̕i̟̗̐̄̄̚t̝̎̆̓̐̒ ̘̇̔̓̊̚ȃ̛̟̗̏̅m̜̟̙̞̈̓é̘̞̟̔̆t̝̂̂̈̑̔,̜̜̖̅̄̍ ̛̗̊̓̆̚c̟̍̆̍̈̔ȯ̖̖̝̑̀n̜̟̎̊̃̚s̟̏̇̎̒̚e̙̐̈̓̌̚c̙̍̈̏̅̕ť̇̄̇̆̓e̛̓̌̈̓̈t̟̍̀̉̆̅u̝̞̎̂̄̚r̘̀̅̈̅̐ ̝̞̓́̇̉ã̏̀̆̅̕d̛̆̐̉̆̋ȉ̞̟̍̃̚p̛̜̊̍̂̓ȋ̏̅̃̋̚ṥ̛̏̃̕č̛̞̝̀̂í̗̘̌́̎n̔̎́̒̂̕ǧ̗̜̋̇̂ ̛̜̔̄̎̃ê̛̔̆̇̕l̘̝̏̐̊̏ĩ̛̍̏̏̄t̟̐́̀̐̎,̙̘̍̆̉̐ ̋̂̏̄̌̅s̙̓̌̈́̇e̛̗̋̒̎̏d̜̗̊̍̊̚     |
      ď̘̋̌̌̕ǒ̝̗̔̇̕ ̙̍́̄̄̉è̛̛̞̌̌i̜̖̐̈̆̚ȕ̇̈̓̃̓ŝ̛̞̙̉̋m̜̐̂̄̋̂ȯ̈̎̎̅̕d̜̙̓̔̋̑ ̞̗̄̂̂̚t̝̊́̃́̄e̛̘̜̞̓̑m̊̅̏̉̌̕p̛̈̂̇̀̐ỏ̙̘̈̉̔r̘̞̋̍̃̚ ̝̄̀̇̅̇ỉ̛̖̍̓̈n̛̛̝̎̕̕c̛̛̊̅́̐ĭ̗̓̀̍̐d̞̜̋̐̅̚i̟̙̇̄̊̄d̞̊̂̀̇̚ủ̝̉̑̃̕n̜̏̇̄̐̋ť̗̜̞̋̉ ̝̒̓̌̓̚ȕ̖̙̀̚̕t̖̘̎̉̂̌ ̛̝̄̍̌̂l̛̟̝̃̑̋á̛̝̝̔̅b̝̙̜̗̅̒ơ̖̌̒̄̆r̒̇̓̎̈̄e̛̛̖̅̏̇ ̖̗̜̝̃́e̛̛̘̅̔̌ẗ̛̙̗̐̕ ̖̟̇̋̌̈d̞̙̀̉̑̕ŏ̝̂́̐̑l̞̟̗̓̓̀ơ̘̎̃̄̂r̗̗̖̔̆̍ẻ̖̝̞̋̅ ̜̌̇̍̈̊m̈̉̇̄̒̀a̜̞̘̔̅̆g̗̖̈̃̈̉n̙̖̄̈̉̄â̛̝̜̄̃ ̛́̎̕̕̚ā̊́́̆̌l̟̙̞̃̒́i̖̇̎̃̀̋q̟̇̒̆́̊ủ́̌̇̑̚ã̛̘̉̐̚.̛́̏̐̍̊   |
      U̝̙̎̈̐̆t̜̍̌̀̔̏ ̞̉̍̇̈̃e̟̟̊̄̕̕n̝̜̒̓̆̕i̖̒̌̅̇̚m̞̊̃̔̊̂ ̛̜̊̎̄̂a̘̜̋̒̚̚d̟̊̎̇̂̍ ̜̖̏̑̉̕m̜̒̎̅̄̚i̝̖̓̂̍̕n̙̉̒̑̀̔ỉ̖̝̌̒́m̛̖̘̅̆̎ ̖̉̎̒̌̕v̖̞̀̔́̎e̖̙̗̒̎̉n̛̗̝̎̀̂ȉ̞̗̒̕̚ȧ̟̜̝̅̚m̆̉̐̐̇̈,̏̐̎́̍́ ̜̞̙̘̏̆q̙̖̙̅̓̂ủ̇́̀̔̚í̙̟̟̏̐s̖̝̍̏̂̇ ̛̘̋̈̕̕ń̛̞̜̜̎o̗̜̔̔̈̆s̞̘̘̄̒̋t̛̅̋́̔̈ȓ̓̒́̇̅ủ̜̄̃̒̍d̙̝̘̊̏̚ ̛̟̞̄́̔e̛̗̝̍̃̀x̞̖̃̄̂̅e̖̅̇̐̔̃r̗̞̖̔̎̚c̘̜̖̆̊̏ï̙̝̙̂̕t̖̏́̓̋̂ă̖̄̆̑̒t̜̟̍̉̑̏i̛̞̞̘̒̑ǒ̜̆̅̃̉ṅ̖̜̒̎̚               |
      u̗̞̓̔̈̏ĺ̟̝́̎̚l̛̜̅̌̎̆a̒̑̆̔̇̃m̜̗̈̊̎̚ċ̘̋̇̂̚ơ̟̖̊́̕ ̖̟̍̉̏̚l̙̔̓̀̅̏ä̞̗̘̙̅ḃ̟̎̄̃̕o̞̎̓̓̓̚r̗̜̊̓̈̒ï̗̜̃̃̅s̀̒̌̂̎̂ ̖̗̗̋̎̐n̝̟̝̘̄̚i̜̒̀̒̐̕s̘̘̄̊̃̀ī̘̜̏̌̕ ̗̖̞̐̈̒ư̙̞̄́̌t̟̘̖̙̊̚ ̌̅̋̆̚̚ä̇̊̇̕̕l̝̞̘̋̔̅i̍̋́̆̑̈q̛̆̐̈̐̚ư̏̆̊́̚î̜̝̑́̊p̗̓̅̑̆̏ ̆́̓̔̋̋e̟̊̋̏̓̚x̗̍̑̊̎̈ ̟̞̆̄̂̍ë̄̎̄̃̅a̛̜̅́̃̈ ̔̋̀̎̐̀c̖̖̍̀̒̂ơ̛̙̖̄̒m̘̔̍̏̆̕ḿ̖̙̝̏̂ȍ̓̋̈̀̕d̆̂̊̅̓̚o̖̔̌̑̚̕ ̙̆́̔̊̒c̖̘̖̀̄̍o̓̄̑̐̓̒ñ̞̒̎̈̚s̞̜̘̈̄̄e̙̊̀̇̌̋q̐̒̓́̔̃ư̗̟̔̔̚å̖̙̞̄̏t̛̙̟̒̇̏.̙̗̓̃̓̎         |
      D̜̖̆̏̌̌ư̑̃̌̍̕i̝̊̊̊̊̄s̛̙̒́̌̇ ̛̃̔̄̆̌ă̘̔̅̅̀ú̟̟̟̃̃t̟̂̄̈̈̃e̘̅̌̒̂̆ ̖̟̐̉̉̌î̟̟̙̜̇r̛̙̞̗̄̌ú̗̗̃̌̎r̛̙̘̉̊̕e̒̐̔̃̓̋ ̊̊̍̋̑̉d̛̝̙̉̀̓o̘̜̐̐̓̐l̞̋̌̆̍́o̊̊̐̃̃̚ṙ̛̖̘̃̕ ̞̊̀̍̒̕ȉ́̑̐̇̅ǹ̜̗̜̞̏ ̛̜̐̄̄̚r̜̖̈̇̅̋ĕ̗̉̃̔̚p̟̝̀̓̔̆r̜̈̆̇̃̃e̘̔̔̏̎̓h̗̒̉̑̆̚ė̛̘̘̈̐n̘̂̀̒̕̕d̗̅̂̋̅́ê̗̜̜̜̕r̟̋̄̐̅̂i̛̔̌̒̂̕t̛̗̓̎̀̎ ̙̗̀̉̂̚ȉ̟̗̐̓̚n̙̂̍̏̓̉ ̙̘̊̋̍̕v̜̖̀̎̆̐ő̜̆̉̃̎l̑̋̒̉̔̆ư̙̓̓́̚p̝̘̖̎̏̒t̛̘̝̞̂̓ȁ̘̆̔́̊t̖̝̉̒̐̎e̞̟̋̀̅̄ ̆̌̃̀̑̔v̝̘̝̍̀̇ȅ̝̊̄̓̕l̞̝̑̔̂̋ĭ̝̄̅̆̍t̝̜̉̂̈̇        |
      ē̟̊̇̕̚s̖̘̘̒̄̑s̛̘̀̊̆̇e̛̝̘̒̏̚ ̉̅̑̂̐̎c̛̟̙̎̋̓i̜̇̒̏̆̆l̟̄́̆̊̌l̍̊̋̃̆̌ủ̗̙̒̔̚m̛̘̘̖̅̍ ̖̙̈̎̂̕d̞̟̏̋̈̔ơ̟̝̌̃̄l̗̙̝̂̉̒õ̒̃̄̄̚ŕ̗̏̏̊̍ê̞̝̞̋̈ ̜̔̒̎̃̚e̞̟̞̒̃̄ư̖̏̄̑̃ ̛̗̜̄̓̎f̛̖̞̅̓̃ü̞̏̆̋̕g̜̝̞̑̑̆i̛̘̐̐̅̚à̜̖̌̆̎t̙̙̎̉̂̍ ̋̔̈̎̎̉n̞̓́̔̊̕ư̘̅̋̔̚l̗̍̒̄̀̚l̞̗̘̙̓̍â̘̔̒̎̚ ̖̓̋̉̃̆p̛̛̘̋̌̀ä̙̔́̒̕r̟̟̖̋̐̋ì̗̙̎̓̓ȃ̔̋̑̚̕t̄́̎̓̂̋ư̏̈̂̑̃r̖̓̋̊̚̚.̒̆̑̆̊̎ ̘̜̍̐̂̚E̞̅̐̇́̂x̄́̈̌̉̕ć̘̃̉̃̕è̘̂̑̏̑p̝̘̑̂̌̆t̔̐̅̍̌̂ȇ̞̈̐̚̕ű̝̞̜́̚ŕ̗̝̉̆́           |
      š̟́̔̏̀ȉ̝̟̝̏̅n̑̆̇̒̆̚t̝̒́̅̋̏ ̗̑̌̋̇̚ơ̙̗̟̆̅c̙̞̙̎̊̎c̘̟̍̔̊̊a̛̒̓̉́̐e̜̘̙̒̅̇ć̝̝̂̇̕ả̓̍̎̂̚t̗̗̗̟̒̃ ̘̒̓̐̇́c̟̞̉̐̓̄ȕ̙̗̅́̏p̛̍̋̈́̅i̖̓̒̍̈̄d̞̃̈̌̆̐a̛̗̝̎̋̉t̞̙̀̊̆̇a̛̙̒̆̉̚t̜̟̘̉̓̚ ̝̘̗̐̇̕n̛̘̑̏̂́ō̑̋̉̏́ň̞̊̆̄̃ ̙̙̙̜̄̏p̒̆̋̋̓̏r̖̖̅̉́̚ơ̜̆̑̈̚i̟̒̀̃̂̌d̛̏̃̍̋̚ë̖̞̙̗̓n̛̘̓̒̅̎t̟̗̙̊̆̚,̘̙̔̊̚̕ ̟̗̘̜̑̔s̜̝̍̀̓̌û̞̙̅̇́n̘̗̝̒̃̎t̗̅̀̅̊̈ ̗̖̅̅̀̄i̛̖̍̅̋̂n̙̝̓̓̎̚ ̞̋̅̋̃̚c̗̒̀̆̌̎ū̞̂̑̌̓ĺ̛̐̍̑́p̝̆̌̎̈̚a̖̙̒̅̈̌ ̝̝̜̂̈̀q̝̖̔̍̒̚ư̔̐̂̎̊ǐ̛̟̖̘̕          |
      o̖̜̔̋̅̚f̛̊̀̉́̕f̏̉̀̔̃̃i̘̍̎̐̔̎c̙̅̑̂̐̅ȋ̛̜̀̒̚a̋̍̇̏̀̋ ̖̘̒̅̃̒d̗̘̓̈̇̋é̝́̎̒̄š̙̒̊̉̋e̖̓̐̀̍̕r̗̞̂̅̇̄ù̘̇̐̉̀n̐̑̀̄̍̐t̟̀̂̊̄̚ ̟̝̂̍̏́m̜̗̈̂̏̚ő̞̊̑̇̒l̘̑̏́̔̄l̛̛̇̃̋̊i̓̋̒̃̉̌t̛̗̜̏̀̋ ̙̟̒̂̌̐a̙̝̔̆̏̅n̝̙̙̗̆̅i̍̔́̊̃̕m̖̝̟̒̍̚ ̛̃̃̑̌́ǐ̘̉̔̅̚d̝̗̀̌̏̒ ̖̝̓̑̊̚ȇ̞̟̖̌̕š̙̙̈̔̀t̂̉̒̍̄̄ ̝̗̊̋̌̄l̛̞̜̙̘̔å̝̍̂̍̅b̜̆̇̈̉̌ǒ̜̙̎̃̆r̝̀̄̍́̕ư̋̊́̊̕m̜̗̒̐̕̚.̟̘̀̒̌̚                     |
      {1:~                                                                }|
                                                                       |
    ]],
    }

    -- nvim will reset the zalgo text^W^W glyph cache if it gets too full.
    -- this should be exceedingly rare, but fake it to make sure it works
    api.nvim__invalidate_glyph_cache()
    screen:expect {
      grid = [[
      ^L̓̉̑̒̌̚ơ̗̌̒̄̀ŕ̈̈̎̐̕è̇̅̄̄̐m̖̟̟̅̄̚ ̛̓̑̆̇̍i̗̟̞̜̅̐p̗̞̜̉̆̕s̟̜̘̍̑̏ū̟̞̎̃̉ḿ̘̙́́̐ ̖̍̌̇̉̚d̞̄̃̒̉̎ò́̌̌̂̐l̞̀̄̆̌̚ȯ̖̞̋̀̐r̓̇̌̃̃̚ ̗̘̀̏̍́s̜̀̎̎̑̕i̟̗̐̄̄̚t̝̎̆̓̐̒ ̘̇̔̓̊̚ȃ̛̟̗̏̅m̜̟̙̞̈̓é̘̞̟̔̆t̝̂̂̈̑̔,̜̜̖̅̄̍ ̛̗̊̓̆̚c̟̍̆̍̈̔ȯ̖̖̝̑̀n̜̟̎̊̃̚s̟̏̇̎̒̚e̙̐̈̓̌̚c̙̍̈̏̅̕ť̇̄̇̆̓e̛̓̌̈̓̈t̟̍̀̉̆̅u̝̞̎̂̄̚r̘̀̅̈̅̐ ̝̞̓́̇̉ã̏̀̆̅̕d̛̆̐̉̆̋ȉ̞̟̍̃̚p̛̜̊̍̂̓ȋ̏̅̃̋̚ṥ̛̏̃̕č̛̞̝̀̂í̗̘̌́̎n̔̎́̒̂̕ǧ̗̜̋̇̂ ̛̜̔̄̎̃ê̛̔̆̇̕l̘̝̏̐̊̏ĩ̛̍̏̏̄t̟̐́̀̐̎,̙̘̍̆̉̐ ̋̂̏̄̌̅s̙̓̌̈́̇e̛̗̋̒̎̏d̜̗̊̍̊̚     |
      ď̘̋̌̌̕ǒ̝̗̔̇̕ ̙̍́̄̄̉è̛̛̞̌̌i̜̖̐̈̆̚ȕ̇̈̓̃̓ŝ̛̞̙̉̋m̜̐̂̄̋̂ȯ̈̎̎̅̕d̜̙̓̔̋̑ ̞̗̄̂̂̚t̝̊́̃́̄e̛̘̜̞̓̑m̊̅̏̉̌̕p̛̈̂̇̀̐ỏ̙̘̈̉̔r̘̞̋̍̃̚ ̝̄̀̇̅̇ỉ̛̖̍̓̈n̛̛̝̎̕̕c̛̛̊̅́̐ĭ̗̓̀̍̐d̞̜̋̐̅̚i̟̙̇̄̊̄d̞̊̂̀̇̚ủ̝̉̑̃̕n̜̏̇̄̐̋ť̗̜̞̋̉ ̝̒̓̌̓̚ȕ̖̙̀̚̕t̖̘̎̉̂̌ ̛̝̄̍̌̂l̛̟̝̃̑̋á̛̝̝̔̅b̝̙̜̗̅̒ơ̖̌̒̄̆r̒̇̓̎̈̄e̛̛̖̅̏̇ ̖̗̜̝̃́e̛̛̘̅̔̌ẗ̛̙̗̐̕ ̖̟̇̋̌̈d̞̙̀̉̑̕ŏ̝̂́̐̑l̞̟̗̓̓̀ơ̘̎̃̄̂r̗̗̖̔̆̍ẻ̖̝̞̋̅ ̜̌̇̍̈̊m̈̉̇̄̒̀a̜̞̘̔̅̆g̗̖̈̃̈̉n̙̖̄̈̉̄â̛̝̜̄̃ ̛́̎̕̕̚ā̊́́̆̌l̟̙̞̃̒́i̖̇̎̃̀̋q̟̇̒̆́̊ủ́̌̇̑̚ã̛̘̉̐̚.̛́̏̐̍̊   |
      U̝̙̎̈̐̆t̜̍̌̀̔̏ ̞̉̍̇̈̃e̟̟̊̄̕̕n̝̜̒̓̆̕i̖̒̌̅̇̚m̞̊̃̔̊̂ ̛̜̊̎̄̂a̘̜̋̒̚̚d̟̊̎̇̂̍ ̜̖̏̑̉̕m̜̒̎̅̄̚i̝̖̓̂̍̕n̙̉̒̑̀̔ỉ̖̝̌̒́m̛̖̘̅̆̎ ̖̉̎̒̌̕v̖̞̀̔́̎e̖̙̗̒̎̉n̛̗̝̎̀̂ȉ̞̗̒̕̚ȧ̟̜̝̅̚m̆̉̐̐̇̈,̏̐̎́̍́ ̜̞̙̘̏̆q̙̖̙̅̓̂ủ̇́̀̔̚í̙̟̟̏̐s̖̝̍̏̂̇ ̛̘̋̈̕̕ń̛̞̜̜̎o̗̜̔̔̈̆s̞̘̘̄̒̋t̛̅̋́̔̈ȓ̓̒́̇̅ủ̜̄̃̒̍d̙̝̘̊̏̚ ̛̟̞̄́̔e̛̗̝̍̃̀x̞̖̃̄̂̅e̖̅̇̐̔̃r̗̞̖̔̎̚c̘̜̖̆̊̏ï̙̝̙̂̕t̖̏́̓̋̂ă̖̄̆̑̒t̜̟̍̉̑̏i̛̞̞̘̒̑ǒ̜̆̅̃̉ṅ̖̜̒̎̚               |
      u̗̞̓̔̈̏ĺ̟̝́̎̚l̛̜̅̌̎̆a̒̑̆̔̇̃m̜̗̈̊̎̚ċ̘̋̇̂̚ơ̟̖̊́̕ ̖̟̍̉̏̚l̙̔̓̀̅̏ä̞̗̘̙̅ḃ̟̎̄̃̕o̞̎̓̓̓̚r̗̜̊̓̈̒ï̗̜̃̃̅s̀̒̌̂̎̂ ̖̗̗̋̎̐n̝̟̝̘̄̚i̜̒̀̒̐̕s̘̘̄̊̃̀ī̘̜̏̌̕ ̗̖̞̐̈̒ư̙̞̄́̌t̟̘̖̙̊̚ ̌̅̋̆̚̚ä̇̊̇̕̕l̝̞̘̋̔̅i̍̋́̆̑̈q̛̆̐̈̐̚ư̏̆̊́̚î̜̝̑́̊p̗̓̅̑̆̏ ̆́̓̔̋̋e̟̊̋̏̓̚x̗̍̑̊̎̈ ̟̞̆̄̂̍ë̄̎̄̃̅a̛̜̅́̃̈ ̔̋̀̎̐̀c̖̖̍̀̒̂ơ̛̙̖̄̒m̘̔̍̏̆̕ḿ̖̙̝̏̂ȍ̓̋̈̀̕d̆̂̊̅̓̚o̖̔̌̑̚̕ ̙̆́̔̊̒c̖̘̖̀̄̍o̓̄̑̐̓̒ñ̞̒̎̈̚s̞̜̘̈̄̄e̙̊̀̇̌̋q̐̒̓́̔̃ư̗̟̔̔̚å̖̙̞̄̏t̛̙̟̒̇̏.̙̗̓̃̓̎         |
      D̜̖̆̏̌̌ư̑̃̌̍̕i̝̊̊̊̊̄s̛̙̒́̌̇ ̛̃̔̄̆̌ă̘̔̅̅̀ú̟̟̟̃̃t̟̂̄̈̈̃e̘̅̌̒̂̆ ̖̟̐̉̉̌î̟̟̙̜̇r̛̙̞̗̄̌ú̗̗̃̌̎r̛̙̘̉̊̕e̒̐̔̃̓̋ ̊̊̍̋̑̉d̛̝̙̉̀̓o̘̜̐̐̓̐l̞̋̌̆̍́o̊̊̐̃̃̚ṙ̛̖̘̃̕ ̞̊̀̍̒̕ȉ́̑̐̇̅ǹ̜̗̜̞̏ ̛̜̐̄̄̚r̜̖̈̇̅̋ĕ̗̉̃̔̚p̟̝̀̓̔̆r̜̈̆̇̃̃e̘̔̔̏̎̓h̗̒̉̑̆̚ė̛̘̘̈̐n̘̂̀̒̕̕d̗̅̂̋̅́ê̗̜̜̜̕r̟̋̄̐̅̂i̛̔̌̒̂̕t̛̗̓̎̀̎ ̙̗̀̉̂̚ȉ̟̗̐̓̚n̙̂̍̏̓̉ ̙̘̊̋̍̕v̜̖̀̎̆̐ő̜̆̉̃̎l̑̋̒̉̔̆ư̙̓̓́̚p̝̘̖̎̏̒t̛̘̝̞̂̓ȁ̘̆̔́̊t̖̝̉̒̐̎e̞̟̋̀̅̄ ̆̌̃̀̑̔v̝̘̝̍̀̇ȅ̝̊̄̓̕l̞̝̑̔̂̋ĭ̝̄̅̆̍t̝̜̉̂̈̇        |
      ē̟̊̇̕̚s̖̘̘̒̄̑s̛̘̀̊̆̇e̛̝̘̒̏̚ ̉̅̑̂̐̎c̛̟̙̎̋̓i̜̇̒̏̆̆l̟̄́̆̊̌l̍̊̋̃̆̌ủ̗̙̒̔̚m̛̘̘̖̅̍ ̖̙̈̎̂̕d̞̟̏̋̈̔ơ̟̝̌̃̄l̗̙̝̂̉̒õ̒̃̄̄̚ŕ̗̏̏̊̍ê̞̝̞̋̈ ̜̔̒̎̃̚e̞̟̞̒̃̄ư̖̏̄̑̃ ̛̗̜̄̓̎f̛̖̞̅̓̃ü̞̏̆̋̕g̜̝̞̑̑̆i̛̘̐̐̅̚à̜̖̌̆̎t̙̙̎̉̂̍ ̋̔̈̎̎̉n̞̓́̔̊̕ư̘̅̋̔̚l̗̍̒̄̀̚l̞̗̘̙̓̍â̘̔̒̎̚ ̖̓̋̉̃̆p̛̛̘̋̌̀ä̙̔́̒̕r̟̟̖̋̐̋ì̗̙̎̓̓ȃ̔̋̑̚̕t̄́̎̓̂̋ư̏̈̂̑̃r̖̓̋̊̚̚.̒̆̑̆̊̎ ̘̜̍̐̂̚E̞̅̐̇́̂x̄́̈̌̉̕ć̘̃̉̃̕è̘̂̑̏̑p̝̘̑̂̌̆t̔̐̅̍̌̂ȇ̞̈̐̚̕ű̝̞̜́̚ŕ̗̝̉̆́           |
      š̟́̔̏̀ȉ̝̟̝̏̅n̑̆̇̒̆̚t̝̒́̅̋̏ ̗̑̌̋̇̚ơ̙̗̟̆̅c̙̞̙̎̊̎c̘̟̍̔̊̊a̛̒̓̉́̐e̜̘̙̒̅̇ć̝̝̂̇̕ả̓̍̎̂̚t̗̗̗̟̒̃ ̘̒̓̐̇́c̟̞̉̐̓̄ȕ̙̗̅́̏p̛̍̋̈́̅i̖̓̒̍̈̄d̞̃̈̌̆̐a̛̗̝̎̋̉t̞̙̀̊̆̇a̛̙̒̆̉̚t̜̟̘̉̓̚ ̝̘̗̐̇̕n̛̘̑̏̂́ō̑̋̉̏́ň̞̊̆̄̃ ̙̙̙̜̄̏p̒̆̋̋̓̏r̖̖̅̉́̚ơ̜̆̑̈̚i̟̒̀̃̂̌d̛̏̃̍̋̚ë̖̞̙̗̓n̛̘̓̒̅̎t̟̗̙̊̆̚,̘̙̔̊̚̕ ̟̗̘̜̑̔s̜̝̍̀̓̌û̞̙̅̇́n̘̗̝̒̃̎t̗̅̀̅̊̈ ̗̖̅̅̀̄i̛̖̍̅̋̂n̙̝̓̓̎̚ ̞̋̅̋̃̚c̗̒̀̆̌̎ū̞̂̑̌̓ĺ̛̐̍̑́p̝̆̌̎̈̚a̖̙̒̅̈̌ ̝̝̜̂̈̀q̝̖̔̍̒̚ư̔̐̂̎̊ǐ̛̟̖̘̕          |
      o̖̜̔̋̅̚f̛̊̀̉́̕f̏̉̀̔̃̃i̘̍̎̐̔̎c̙̅̑̂̐̅ȋ̛̜̀̒̚a̋̍̇̏̀̋ ̖̘̒̅̃̒d̗̘̓̈̇̋é̝́̎̒̄š̙̒̊̉̋e̖̓̐̀̍̕r̗̞̂̅̇̄ù̘̇̐̉̀n̐̑̀̄̍̐t̟̀̂̊̄̚ ̟̝̂̍̏́m̜̗̈̂̏̚ő̞̊̑̇̒l̘̑̏́̔̄l̛̛̇̃̋̊i̓̋̒̃̉̌t̛̗̜̏̀̋ ̙̟̒̂̌̐a̙̝̔̆̏̅n̝̙̙̗̆̅i̍̔́̊̃̕m̖̝̟̒̍̚ ̛̃̃̑̌́ǐ̘̉̔̅̚d̝̗̀̌̏̒ ̖̝̓̑̊̚ȇ̞̟̖̌̕š̙̙̈̔̀t̂̉̒̍̄̄ ̝̗̊̋̌̄l̛̞̜̙̘̔å̝̍̂̍̅b̜̆̇̈̉̌ǒ̜̙̎̃̆r̝̀̄̍́̕ư̋̊́̊̕m̜̗̒̐̕̚.̟̘̀̒̌̚                     |
      {1:~                                                                }|
                                                                       |
    ]],
      reset = true,
    }
  end)

  it('works with arabic input and arabicshape', function()
    command('set arabic')

    command('set noarabicshape')
    feed('isghl!<esc>')
    screen:expect {
      grid = [[
                                                             ^!مالس|
      {1:                                                           ~}|*4
                                                                  |
    ]],
    }

    command('set arabicshape')
    screen:expect {
      grid = [[
                                                              ^!ﻡﻼﺳ|
      {1:                                                           ~}|*4
                                                                  |
    ]],
    }
  end)

  it('works with arabic input and arabicshape and norightleft', function()
    command('set arabic norightleft')

    command('set noarabicshape')
    feed('isghl!<esc>')
    screen:expect {
      grid = [[
      سلام^!                                                       |
      {1:~                                                           }|*4
                                                                  |
    ]],
    }

    command('set arabicshape')
    screen:expect {
      grid = [[
      ﺱﻼﻣ^!                                                        |
      {1:~                                                           }|*4
                                                                  |
    ]],
    }
  end)

  it('works with arabicshape and multiple composing chars', function()
    -- this tests an important edge case: arabicshape might increase the byte size of the base
    -- character in a way so that the last composing char no longer fits. use "g8" on the text
    -- to observe what is happening (the final E1 80 B7 gets deleted with 'arabicshape')
    -- If we would increase the schar_t size, say from 32 to 64 bytes, we need to extend the
    -- test text with even more zalgo energy to still touch this edge case.

    api.nvim_buf_set_lines(0, 0, -1, true, { 'سلام့̀́̂̃̄̅̆̇̈̉̊̋̌' })
    command('set noarabicshape')

    screen:expect {
      grid = [[
      ^سلام့̀́̂̃̄̅̆̇̈̉̊̋̌                                                        |
      {1:~                                                           }|*4
                                                                  |
    ]],
    }

    command('set arabicshape')
    screen:expect {
      grid = [[
      ^ﺱﻼﻣ̀́̂̃̄̅̆̇̈̉̊̋̌                                                         |
      {1:~                                                           }|*4
                                                                  |
    ]],
    }
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
    {1:~                                       }|
    {3:你好                                    }|
                                            |
    ]])
  end)
  it('last char shows (single byte)', function()
    command('set statusline=abc')
    screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:abc                                     }|
                                            |
    ]])
  end)
  it('unicode control points', function()
    command('set statusline=')
    screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:<9f>                                    }|
                                            |
    ]])
  end)
  it('MAX_MCO (6) unicode combination points', function()
    command('set statusline=o̸⃯ᷰ⃐⃧⃝')
    -- o + U+1DF0 + U+20EF + U+0338 + U+20D0 + U+20E7 + U+20DD
    screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:o̸⃯ᷰ⃐⃧⃝                                       }|
                                            |
    ]])
  end)
  it('non-printable followed by MAX_MCO unicode combination points', function()
    command('set statusline=̸⃯ᷰ⃐⃧⃝')
    -- U+9F + U+1DF0 + U+20EF + U+0338 + U+20D0 + U+20E7 + U+20DD
    screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:<9f><1df0><20ef><0338><20d0><20e7><20dd>}|
                                            |
    ]])
  end)

  it('hidden group %( %) does not cause invalid unicode', function()
    command("let &statusline = '%#StatColorHi2#%(✓%#StatColorHi2#%) Q≡'")
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|
      {3: Q≡                                     }|
                                              |
    ]],
    }
  end)

  it('unprintable chars in filename with default stl', function()
    command('file 🧑‍💻')
    -- TODO: this is wrong but avoids a crash
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|
      {3:🧑�💻                                   }|
                                              |
    ]],
    }
  end)

  it('unprintable chars in filename with custom stl', function()
    command('set statusline=xx%#ErrorMsg#%f%##yy')
    command('file 🧑‍💻')
    -- TODO: this is also wrong but also avoids a crash
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|
      {3:xx}{9:🧑<200d>💻}{3:yy                          }|
                                              |
    ]],
    }
  end)
end)
