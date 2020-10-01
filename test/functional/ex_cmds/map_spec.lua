local helpers = require("test.functional.helpers")(after_each)
local Screen = require('test.functional.ui.screen')

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

describe(':*map <expr>', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(20, 5)
    screen:attach()
  end)

  it('cursor is restored after :map <expr>', function()
    command(':map <expr> x input("> ")')
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

  it('cursor is restored after :imap <expr>', function()
    command(':imap <expr> x input("> ")')
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

  it('command line is restored after :cmap <expr>', function()
    command(':cmap <expr> x input("> ")')
    feed(':foo')
    screen:expect([[
                          |
      ~                   |
      ~                   |
      ~                   |
      :foo^                |
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
                          |
      ~                   |
      ~                   |
      ~                   |
      :foo^                |
    ]])
  end)

  it('error in :cmap <expr> handled correctly', function()
    screen:try_resize(40, 5)
    command(':cmap <expr> x execute("throw 42")')
    feed(':echo "foo')
    screen:expect([[
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      :echo "foo^                              |
    ]])
    feed('x')
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
end)
