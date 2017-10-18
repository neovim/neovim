local helpers = require("test.functional.helpers")(after_each)

local eq = helpers.eq
local feed = helpers.feed
local meths = helpers.meths
local clear = helpers.clear
local command = helpers.command
local expect = helpers.expect

describe(':*map', function()
  before_each(clear)

  it('are not affected by &isident', function()
    meths.set_var('counter', 0)
    command('nnoremap <C-x> :let counter+=1<CR>')
    meths.set_option('isident', ('%u'):format(('>'):byte()))
    command('nnoremap <C-y> :let counter+=1<CR>')
    -- &isident used to disable keycode parsing here as well
    feed('\24\25<C-x><C-y>')
    eq(4, meths.get_var('counter'))
  end)

  it(':imap <M-">', function()
    command('imap <M-"> foo')
    feed('i-<M-">-')
    expect('-foo-')
  end)
end)
