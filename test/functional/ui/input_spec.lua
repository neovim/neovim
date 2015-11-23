local helpers = require('test.functional.helpers')
local clear, execute, nvim = helpers.clear, helpers.execute, helpers.nvim
local feed, next_message, eq = helpers.feed, helpers.next_message, helpers.eq
local expect = helpers.expect
local Screen = require('test.functional.ui.screen')

describe('mappings', function()
  local cid

  local add_mapping = function(mapping, send)
    local cmd = "nnoremap "..mapping.." :call rpcnotify("..cid..", 'mapped', '"
                ..send:gsub('<', '<lt>').."')<cr>"
    execute(cmd)
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
  end)
end)

describe('feeding large chunks of input with <Paste>', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    execute('set ruler')
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
