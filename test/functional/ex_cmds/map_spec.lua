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

  it('shows <nop> as mapping rhs', function()
    command('nmap asdf <Nop>')
    eq([[

n  asdf          <Nop>]],
       helpers.exec_capture('nmap asdf'))
  end)

  it('mappings with description can be filtered', function()
    meths.set_keymap('n', 'asdf1', 'qwert', {desc='do the one thing'})
    meths.set_keymap('n', 'asdf2', 'qwert', {desc='doesnot really do anything'})
    meths.set_keymap('n', 'asdf3', 'qwert', {desc='do the other thing'})
    eq([[

n  asdf3         qwert
                 do the other thing
n  asdf1         qwert
                 do the one thing]],
       helpers.exec_capture('filter the nmap'))
  end)

  it('can create mappings with description', function()
    command('nnoremap <silent><desc=Some interesting map> asdf <Nop>')
    eq([[

n  asdf        * <Nop>
                 Some interesting map]],
       helpers.exec_capture('nnoremap asdf'))
  end)

  it('accepts escaped > in description', function()
    command([[nnoremap <silent><desc=escape \> with \\> asdf <Nop>]])
    eq([[

n  asdf        * <Nop>
                 escape > with \]],
       helpers.exec_capture('nnoremap asdf'))
  end)
  it('can use newline & tab in description', function()
    command([[nnoremap <silent><desc=can do multiline\n\t\t tabs too> asdf <Nop>]])
    eq([[

n  asdf        * <Nop>
                 can do multiline
		 tabs too]],
       helpers.exec_capture('nnoremap asdf'))
  end)
end)
