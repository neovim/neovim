local helpers = require('test.functional.helpers')(after_each)
local clear, feed_command = helpers.clear, helpers.feed_command
local feed, next_msg, eq = helpers.feed, helpers.next_msg, helpers.eq
local command = helpers.command
local expect = helpers.expect
local meths = helpers.meths
local exec_lua = helpers.exec_lua
local write_file = helpers.write_file
local Screen = require('test.functional.ui.screen')

before_each(clear)

describe('mappings', function()
  local add_mapping = function(mapping, send)
    local cmd = "nnoremap "..mapping.." :call rpcnotify(1, 'mapped', '"
                ..send:gsub('<', '<lt>').."')<cr>"
    feed_command(cmd)
  end

  local check_mapping = function(mapping, expected)
    feed(mapping)
    eq({'notification', 'mapped', {expected}}, next_msg())
  end

  before_each(function()
    add_mapping('<C-L>', '<C-L>')
    add_mapping('<C-S-L>', '<C-S-L>')
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<c-s-up>', '<c-s-up>')
    add_mapping('<c-s-a-up>', '<c-s-a-up>')
    add_mapping('<c-s-a-d-up>', '<c-s-a-d-up>')
    add_mapping('<c-d-a>', '<c-d-a>')
    add_mapping('<d-1>', '<d-1>')
    add_mapping('<khome>','<khome>')
    add_mapping('<kup>','<kup>')
    add_mapping('<kpageup>','<kpageup>')
    add_mapping('<kleft>','<kleft>')
    add_mapping('<korigin>','<korigin>')
    add_mapping('<kright>','<kright>')
    add_mapping('<kend>','<kend>')
    add_mapping('<kdown>','<kdown>')
    add_mapping('<kpagedown>','<kpagedown>')
    add_mapping('<kinsert>','<kinsert>')
    add_mapping('<kdel>','<kdel>')
    add_mapping('<kdivide>','<kdivide>')
    add_mapping('<kmultiply>','<kmultiply>')
    add_mapping('<kminus>','<kminus>')
    add_mapping('<kplus>','<kplus>')
    add_mapping('<kenter>','<kenter>')
    add_mapping('<kcomma>','<kcomma>')
    add_mapping('<kequal>','<kequal>')
  end)

  it('ok', function()
    check_mapping('<C-L>', '<C-L>')
    check_mapping('<C-S-L>', '<C-S-L>')
    check_mapping('<s-up>', '<s-up>')
    check_mapping('<c-s-up>', '<c-s-up>')
    check_mapping('<s-c-up>', '<c-s-up>')
    check_mapping('<c-s-a-up>', '<c-s-a-up>')
    check_mapping('<s-c-a-up>', '<c-s-a-up>')
    check_mapping('<c-a-s-up>', '<c-s-a-up>')
    check_mapping('<s-a-c-up>', '<c-s-a-up>')
    check_mapping('<a-c-s-up>', '<c-s-a-up>')
    check_mapping('<a-s-c-up>', '<c-s-a-up>')
    check_mapping('<c-s-a-d-up>', '<c-s-a-d-up>')
    check_mapping('<s-a-d-c-up>', '<c-s-a-d-up>')
    check_mapping('<d-s-a-c-up>', '<c-s-a-d-up>')
    check_mapping('<c-d-a>', '<c-d-a>')
    check_mapping('<d-c-a>', '<c-d-a>')
    check_mapping('<d-1>', '<d-1>')
    check_mapping('<khome>','<khome>')
    check_mapping('<KP7>','<khome>')
    check_mapping('<kup>','<kup>')
    check_mapping('<KP8>','<kup>')
    check_mapping('<kpageup>','<kpageup>')
    check_mapping('<KP9>','<kpageup>')
    check_mapping('<kleft>','<kleft>')
    check_mapping('<KP4>','<kleft>')
    check_mapping('<korigin>','<korigin>')
    check_mapping('<KP5>','<korigin>')
    check_mapping('<kright>','<kright>')
    check_mapping('<KP6>','<kright>')
    check_mapping('<kend>','<kend>')
    check_mapping('<KP1>','<kend>')
    check_mapping('<kdown>','<kdown>')
    check_mapping('<KP2>','<kdown>')
    check_mapping('<kpagedown>','<kpagedown>')
    check_mapping('<KP3>','<kpagedown>')
    check_mapping('<kinsert>','<kinsert>')
    check_mapping('<KP0>','<kinsert>')
    check_mapping('<kdel>','<kdel>')
    check_mapping('<KPPeriod>','<kdel>')
    check_mapping('<kdivide>','<kdivide>')
    check_mapping('<KPDiv>','<kdivide>')
    check_mapping('<kmultiply>','<kmultiply>')
    check_mapping('<KPMult>','<kmultiply>')
    check_mapping('<kminus>','<kminus>')
    check_mapping('<KPMinus>','<kminus>')
    check_mapping('<kplus>','<kplus>')
    check_mapping('<KPPlus>','<kplus>')
    check_mapping('<kenter>','<kenter>')
    check_mapping('<KPEnter>','<kenter>')
    check_mapping('<kcomma>','<kcomma>')
    check_mapping('<KPComma>','<kcomma>')
    check_mapping('<kequal>','<kequal>')
    check_mapping('<KPEquals>','<kequal>')
  end)

  it('support meta + multibyte char mapping', function()
    add_mapping('<m-ä>', '<m-ä>')
    check_mapping('<m-ä>', '<m-ä>')
  end)
end)

describe('input utf sequences that contain CSI/K_SPECIAL', function()
  it('ok', function()
    feed('i…<esc>')
    expect('…')
  end)
end)

describe('input non-printable chars', function()
  after_each(function()
    os.remove('Xtest-overwrite')
  end)

  it("doesn't crash when echoing them back", function()
    write_file("Xtest-overwrite", [[foobar]])
    local screen = Screen.new(60,8)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4}
    })
    screen:attach()
    command("set display-=msgsep shortmess-=F")

    feed_command("e Xtest-overwrite")
    screen:expect([[
      ^foobar                                                      |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      "Xtest-overwrite" [noeol] 1L, 6C                            |
    ]])

    -- The timestamp is in second resolution, wait two seconds to be sure.
    screen:sleep(2000)
    write_file("Xtest-overwrite", [[smurf]])
    feed_command("w")
    screen:expect([[
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      "Xtest-overwrite"                                           |
      {2:WARNING: The file has been changed since reading it!!!}      |
      {3:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed("u")
    screen:expect([[
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      "Xtest-overwrite"                                           |
      {2:WARNING: The file has been changed since reading it!!!}      |
      {3:Do you really want to write to it (y/n)?}u                   |
      {3:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed("\005")
    screen:expect([[
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      "Xtest-overwrite"                                           |
      {2:WARNING: The file has been changed since reading it!!!}      |
      {3:Do you really want to write to it (y/n)?}u                   |
      {3:Do you really want to write to it (y/n)?}                    |
      {3:Do you really want to write to it (y/n)?}^                    |
    ]])

    feed("n")
    screen:expect([[
      {1:~                                                           }|
      {1:~                                                           }|
      "Xtest-overwrite"                                           |
      {2:WARNING: The file has been changed since reading it!!!}      |
      {3:Do you really want to write to it (y/n)?}u                   |
      {3:Do you really want to write to it (y/n)?}                    |
      {3:Do you really want to write to it (y/n)?}n                   |
      {3:Press ENTER or type command to continue}^                     |
    ]])

    feed("<cr>")
    screen:expect([[
      ^foobar                                                      |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])
  end)
end)

describe("event processing and input", function()
  it('not blocked by event bursts', function()
    meths.set_keymap('', '<f2>', "<cmd>lua vim.rpcnotify(1, 'stop') winning = true <cr>", {noremap=true})

    exec_lua [[
      winning = false
      burst = vim.schedule_wrap(function(tell)
        if tell then
          vim.rpcnotify(1, 'start')
        end
        -- Are we winning, son?
        if not winning then
          burst(false)
        end
      end)
      burst(true)
    ]]

    eq({'notification', 'start', {}}, next_msg())
    feed '<f2>'
    eq({'notification', 'stop', {}}, next_msg())
  end)
end)
