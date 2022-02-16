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

  it('can create maps with description', function()
    command('nnoremap <silent><desc=Some interesting map> asdf <Nop>')
    eq([[

n  asdf        * <Nop>
                 Some interesting map]],
       helpers.exec_capture('nnoremap asdf'))
  end)

  it('accepts escaped > in map-description', function()
    command([[nnoremap <silent><desc=escape \> with \\> asdf <Nop>]])
    eq([[

n  asdf        * <Nop>
                 escape > with \]],
       helpers.exec_capture('nnoremap asdf'))
  end)
end)
