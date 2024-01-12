local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local api = helpers.api
local poke_eventloop = helpers.poke_eventloop

before_each(clear)

describe('Ex mode', function()
  it('supports command line editing', function()
    local function test_ex_edit(expected, cmd)
      feed('gQ' .. cmd .. '<C-b>"<CR>')
      local ret = eval('@:[1:]') -- Remove leading quote.
      feed('visual<CR>')
      eq(api.nvim_replace_termcodes(expected, true, true, true), ret)
    end
    command('set sw=2')
    test_ex_edit('bar', 'foo bar<C-u>bar')
    test_ex_edit('1<C-u>2', '1<C-v><C-u>2')
    test_ex_edit('213', '1<C-b>2<C-e>3')
    test_ex_edit('2013', '01<Home>2<End>3')
    test_ex_edit('0213', '01<Left>2<Right>3')
    test_ex_edit('0342', '012<Left><Left><Insert>3<Insert>4')
    test_ex_edit('foo ', 'foo bar<C-w>')
    test_ex_edit('foo', 'fooba<Del><Del>')
    test_ex_edit('foobar', 'foo<Tab>bar')
    test_ex_edit('abbreviate', 'abbrev<Tab>')
    test_ex_edit('1<C-t><C-t>', '1<C-t><C-t>')
    test_ex_edit('1<C-t><C-t>', '1<C-t><C-t><C-d>')
    test_ex_edit('    foo', '    foo<C-d>')
    test_ex_edit('    foo0', '    foo0<C-d>')
    test_ex_edit('    foo^', '    foo^<C-d>')
    test_ex_edit('foo', '<BS><C-H><Del><kDel>foo')
    -- default wildchar <Tab> interferes with this test
    command('set wildchar=<c-e>')
    test_ex_edit('a\tb', 'a\t\t<C-H>b')
    test_ex_edit('\tm<C-T>n', '\tm<C-T>n')
    command('set wildchar&')
  end)

  it('substitute confirmation prompt', function()
    command('set noincsearch nohlsearch inccommand=')
    local screen = Screen.new(60, 6)
    screen:set_default_attr_ids({
      [0] = { bold = true, reverse = true }, -- MsgSeparator
      [1] = { foreground = Screen.colors.Brown }, -- LineNr
      [2] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    })
    screen:attach()
    command([[call setline(1, ['foo foo', 'foo foo', 'foo foo'])]])
    command([[set number]])
    feed('gQ')
    screen:expect([[
      {1:  1 }foo foo                                                 |
      {1:  2 }foo foo                                                 |
      {1:  3 }foo foo                                                 |
      {0:                                                            }|
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      :^                                                           |
    ]])

    feed('%s/foo/bar/gc<CR>')
    screen:expect([[
      {1:  1 }foo foo                                                 |
      {0:                                                            }|
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      :%s/foo/bar/gc                                              |
      {1:  1 }foo foo                                                 |
          ^^^^                                                     |
    ]])
    feed('N<CR>')
    screen:expect([[
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      :%s/foo/bar/gc                                              |
      {1:  1 }foo foo                                                 |
          ^^^N                                                    |
      {1:  1 }foo foo                                                 |
          ^^^^                                                     |
    ]])
    feed('n<CR>')
    screen:expect([[
      {1:  1 }foo foo                                                 |
          ^^^N                                                    |
      {1:  1 }foo foo                                                 |
          ^^^n                                                    |
      {1:  1 }foo foo                                                 |
              ^^^^                                                 |
    ]])
    feed('y<CR>')

    feed('q<CR>')
    screen:expect([[
      {1:  1 }foo foo                                                 |
              ^^^y                                                |
      {1:  2 }foo foo                                                 |
          ^^^q                                                    |
      {1:  2 }foo foo                                                 |
      :^                                                           |
    ]])

    -- Pressing enter in ex mode should print the current line
    feed('<CR>')
    screen:expect([[
              ^^^y                                                |
      {1:  2 }foo foo                                                 |
          ^^^q                                                    |
      {1:  2 }foo foo                                                 |
      {1:  3 }foo foo                                                 |
      :^                                                           |
    ]])

    feed(':vi<CR>')
    screen:expect([[
      {1:  1 }foo bar                                                 |
      {1:  2 }foo foo                                                 |
      {1:  3 }^foo foo                                                 |
      {2:~                                                           }|*2
                                                                  |
    ]])
  end)

  it('pressing Ctrl-C in :append inside a loop in Ex mode does not hang', function()
    local screen = Screen.new(60, 6)
    screen:set_default_attr_ids({
      [0] = { bold = true, reverse = true }, -- MsgSeparator
      [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    })
    screen:attach()
    feed('gQ')
    feed('for i in range(1)<CR>')
    feed('append<CR>')
    screen:expect([[
      {0:                                                            }|
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      :for i in range(1)                                          |
                                                                  |
      :  append                                                   |
      ^                                                            |
    ]])
    feed('<C-C>')
    poke_eventloop() -- Wait for input to be flushed
    feed('foo<CR>')
    screen:expect([[
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      :for i in range(1)                                          |
                                                                  |
      :  append                                                   |
      foo                                                         |
      ^                                                            |
    ]])
    feed('.<CR>')
    screen:expect([[
      :for i in range(1)                                          |
                                                                  |
      :  append                                                   |
      foo                                                         |
      .                                                           |
      :  ^                                                         |
    ]])
    feed('endfor<CR>')
    feed('vi<CR>')
    screen:expect([[
      ^foo                                                         |
      {1:~                                                           }|*4
                                                                  |
    ]])
  end)
end)
