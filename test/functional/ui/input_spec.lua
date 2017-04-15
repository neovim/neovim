local helpers = require('test.functional.helpers')(after_each)
local clear, feed_command, nvim = helpers.clear, helpers.feed_command, helpers.nvim
local feed, next_message, eq = helpers.feed, helpers.next_message, helpers.eq
local expect = helpers.expect
local Screen = require('test.functional.ui.screen')

if helpers.pending_win32(pending) then return end

describe('mappings', function()
  local cid

  local add_mapping = function(mapping, send)
    local cmd = "nnoremap "..mapping.." :call rpcnotify("..cid..", 'mapped', '"
                ..send:gsub('<', '<lt>').."')<cr>"
    feed_command(cmd)
  end

  local check_mapping = function(mapping, expected)
    feed(mapping)
    eq({'notification', 'mapped', {expected}}, next_message())
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
