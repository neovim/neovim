local helpers = require('test.functional.helpers')
local clear, execute, nvim = helpers.clear, helpers.execute, helpers.nvim
local feed, next_message, eq = helpers.feed, helpers.next_message, helpers.eq
local expect = helpers.expect

describe('mappings', function()
  local cid

  local add_mapping = function(mapping, send)
    local str = 'mapped '..mapping
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

describe('input utf sequences that contain CSI/K_SPECIAL', function()
  it('ok', function()
    feed('i…<esc>')
    expect('…')
  end)
end)
