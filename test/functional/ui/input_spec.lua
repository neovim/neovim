local helpers = require('test.functional.helpers')(after_each)
local clear, feed_command, nvim = helpers.clear, helpers.feed_command, helpers.nvim
local feed, next_msg, eq = helpers.feed, helpers.next_msg, helpers.eq
local command = helpers.command
local expect = helpers.expect
local write_file = helpers.write_file
local Screen = require('test.functional.ui.screen')

describe('mappings', function()
  local cid

  local add_mapping = function(mapping, send)
    local cmd = "nnoremap "..mapping.." :call rpcnotify("..cid..", 'mapped', '"
                ..send:gsub('<', '<lt>').."')<cr>"
    feed_command(cmd)
  end

  local check_mapping = function(mapping, expected)
    feed(mapping)
    eq({'notification', 'mapped', {expected}}, next_msg())
  end

  before_each(function()
    clear()
    cid = nvim('get_api_info')[1]
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<s-up>', '<s-up>')
    add_mapping('<c-s-up>', '<c-s-up>')
    add_mapping('<c-s-a-up>', '<c-s-a-up>')
    add_mapping('<c-s-a-d-up>', '<c-s-a-d-up>')
    add_mapping('<c-d-a>', '<c-d-a>')
    add_mapping('<d-1>', '<d-1>')
  end)

  it('ok', function()
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
  end)
end)

describe('feeding large chunks of input with <Paste>', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    feed_command('set ruler')
  end)

  it('ok', function()
    local t = {}
    for i = 1, 20000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed('i<Paste>')
    screen:expect([[
      ^                                                     |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      -- INSERT (paste) --                                 |
    ]])
    feed(table.concat(t, '<Enter>'))
    screen:expect([[
      item 19988                                           |
      item 19989                                           |
      item 19990                                           |
      item 19991                                           |
      item 19992                                           |
      item 19993                                           |
      item 19994                                           |
      item 19995                                           |
      item 19996                                           |
      item 19997                                           |
      item 19998                                           |
      item 19999                                           |
      item 20000^                                           |
      -- INSERT (paste) --                                 |
    ]])
    feed('<Paste>')
    screen:expect([[
      item 19988                                           |
      item 19989                                           |
      item 19990                                           |
      item 19991                                           |
      item 19992                                           |
      item 19993                                           |
      item 19994                                           |
      item 19995                                           |
      item 19996                                           |
      item 19997                                           |
      item 19998                                           |
      item 19999                                           |
      item 20000^                                           |
      -- INSERT --                       20000,11      Bot |
    ]])
  end)
end)

describe('input utf sequences that contain CSI/K_SPECIAL', function()
  before_each(clear)
  it('ok', function()
    feed('i…<esc>')
    expect('…')
  end)
end)

describe('input non-printable chars', function()
  it("doesn't crash when echoing them back", function()
    write_file("Xtest-overwrite", [[foobar]])
    clear()
    local screen = Screen.new(60,8)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4}
    })
    screen:attach()
    command("set display-=msgsep")

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
