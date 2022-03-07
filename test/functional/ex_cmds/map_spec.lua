local helpers = require("test.functional.helpers")(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local exec = helpers.exec
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

  it('<Plug> mappings ignore nore', function()
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

  it("Doesn't auto ignore nore for keys before or after <Plug> mapping", function()
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

describe(':*map cursor and redrawing', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(20, 5)
    screen:attach()
  end)

  it('cursor is restored after :map <expr> which calls input()', function()
    command('map <expr> x input("> ")')
    screen:expect([[
      ^                    |
      ~                   |
      ~                   |
      ~                   |
                          |
    ]])
    feed('x')
    screen:expect([[
                          |
      ~                   |
      ~                   |
      ~                   |
      > ^                  |
    ]])
    feed('\n')
    screen:expect([[
      ^                    |
      ~                   |
      ~                   |
      ~                   |
      >                   |
    ]])
  end)

  it('cursor is restored after :imap <expr> which calls input()', function()
    command('imap <expr> x input("> ")')
    feed('i')
    screen:expect([[
      ^                    |
      ~                   |
      ~                   |
      ~                   |
      -- INSERT --        |
    ]])
    feed('x')
    screen:expect([[
                          |
      ~                   |
      ~                   |
      ~                   |
      > ^                  |
    ]])
    feed('\n')
    screen:expect([[
      ^                    |
      ~                   |
      ~                   |
      ~                   |
      >                   |
    ]])
  end)

  it('cursor is restored after :map <expr> which redraws statusline vim-patch:8.1.2336', function()
    exec([[
      call setline(1, ['one', 'two', 'three'])
      2
      set ls=2
      hi! link StatusLine ErrorMsg
      noremap <expr> <C-B> Func()
      func Func()
	  let g:on = !get(g:, 'on', 0)
	  redraws
	  return ''
      endfunc
      func Status()
	  return get(g:, 'on', 0) ? '[on]' : ''
      endfunc
      set stl=%{Status()}
    ]])
    feed('<C-B>')
    screen:expect([[
      one                 |
      ^two                 |
      three               |
      [on]                |
                          |
    ]])
  end)

  it('error in :nmap <expr> does not mess up display vim-patch:4.2.4338', function()
    screen:try_resize(40, 5)
    command('nmap <expr> <F2> execute("throw 42")')
    feed('<F2>')
    screen:expect([[
                                              |
                                              |
      Error detected while processing :       |
      E605: Exception not caught: 42          |
      Press ENTER or type command to continue^ |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                        |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
  end)

  it('error in :cmap <expr> handled correctly vim-patch:4.2.4338', function()
    screen:try_resize(40, 5)
    command('cmap <expr> <F2> execute("throw 42")')
    feed(':echo "foo')
    screen:expect([[
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      :echo "foo^                              |
    ]])
    feed('<F2>')
    screen:expect([[
                                              |
      :echo "foo                              |
      Error detected while processing :       |
      E605: Exception not caught: 42          |
      :echo "foo^                              |
    ]])
    feed('"')
    screen:expect([[
                                              |
      :echo "foo                              |
      Error detected while processing :       |
      E605: Exception not caught: 42          |
      :echo "foo"^                             |
    ]])
    feed('\n')
    screen:expect([[
      :echo "foo                              |
      Error detected while processing :       |
      E605: Exception not caught: 42          |
      foo                                     |
      Press ENTER or type command to continue^ |
    ]])
  end)

  it('listing mappings clears command line vim-patch:8.2.4401', function()
    screen:try_resize(40, 5)
    command('nmap a b')
    feed(':                      nmap a<CR>')
    screen:expect([[
      ^                                        |
      ~                                       |
      ~                                       |
      ~                                       |
      n  a             b                      |
    ]])
  end)
end)
