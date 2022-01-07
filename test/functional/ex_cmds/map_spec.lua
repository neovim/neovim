local helpers = require("test.functional.helpers")(after_each)

local eq = helpers.eq
local feed = helpers.feed
local meths = helpers.meths
local clear = helpers.clear
local command = helpers.command
local expect = helpers.expect
local insert = helpers.insert
local eval = helpers.eval

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

  it('<Plug> keymaps ignore nore', function()
    command('let x = 0')
    eq(0, meths.eval('x'))
    command [[
      nnoremap <Plug>(Increase_x) <cmd>let x+=1<cr>
      nmap increase_x_remap <Plug>(Increase_x)
      nnoremap increase_x_noremap <Plug>(Increase_x)
    ]]
    feed('increase_x_remap')
    eq(1, meths.eval('x'))
    feed('increase_x_noremap')
    eq(2, meths.eval('x'))
  end)
  it("Doesn't auto ignore nore for keys before or after <Plug> keymap", function()
    command('let x = 0')
    eq(0, meths.eval('x'))
    command [[
      nnoremap x <nop>
      nnoremap <Plug>(Increase_x) <cmd>let x+=1<cr>
      nmap increase_x_remap x<Plug>(Increase_x)x
      nnoremap increase_x_noremap x<Plug>(Increase_x)x
    ]]
    insert("Some text")
    eq('Some text', eval("getline('.')"))

    feed('increase_x_remap')
    eq(1, meths.eval('x'))
    eq('Some text', eval("getline('.')"))
    feed('increase_x_noremap')
    eq(2, meths.eval('x'))
    eq('Some te', eval("getline('.')"))
  end)
end)
