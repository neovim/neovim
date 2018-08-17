local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local feed_command = helpers.feed_command
local feed = helpers.feed
local eq = helpers.eq
local expect = helpers.expect
local eval = helpers.eval
local funcs = helpers.funcs
local insert = helpers.insert
local exc_exec = helpers.exc_exec
local Screen = require('test.functional.ui.screen')

describe('mappings with <Cmd>', function()
  local screen
  local function cmdmap(lhs, rhs)
    feed_command('noremap '..lhs..' <Cmd>'..rhs..'<cr>')
    feed_command('noremap! '..lhs..' <Cmd>'..rhs..'<cr>')
  end

  before_each(function()
    clear()
    screen = Screen.new(65, 8)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [4] = {bold = true},
      [5] = {background = Screen.colors.LightGrey},
      [6] = {foreground = Screen.colors.Blue1},
      [7] = {bold = true, reverse = true},
    })
    screen:attach()

    cmdmap('<F3>', 'let m = mode(1)')
    cmdmap('<F4>', 'normal! ww')
    cmdmap('<F5>', 'normal! "ay')
    cmdmap('<F6>', 'throw "very error"')
    feed_command([[
        function! TextObj()
            if mode() !=# "v"
                normal! v
            end
            call cursor(1,3)
            normal! o
            call cursor(2,4)
        endfunction]])
    cmdmap('<F7>', 'call TextObj()')
    insert([[
        some short lines
        of test text]])
    feed('gg')
    cmdmap('<F8>', 'startinsert')
    cmdmap('<F9>', 'stopinsert')
    feed_command("abbr foo <Cmd>let g:y = 17<cr>bar")
  end)

  it('can be displayed', function()
    feed_command('map <F3>')
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
         {6:<F3>}        {6:*} {6:<Cmd>}let m = mode(1){6:<CR>}                        |
    ]])
  end)

  it('handles invalid mappings', function()
    feed_command('let x = 0')
    feed_command('noremap <F3> <Cmd><Cmd>let x = 1<cr>')
    feed('<F3>')
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {2:E5521: <Cmd> mapping must end with <CR> before second <Cmd>}      |
    ]])

    feed_command('noremap <F3> <Cmd><F3>let x = 2<cr>')
    feed('<F3>')
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {2:E5522: <Cmd> mapping must not include <F3> key}                   |
    ]])

    feed_command('noremap <F3> <Cmd>let x = 3')
    feed('<F3>')
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {2:E5520: <Cmd> mapping must end with <CR>}                          |
    ]])
    eq(0, eval('x'))
  end)

  it('works in various modes and sees correct `mode()` value', function()
    -- normal mode
    feed('<F3>')
    eq('n', eval('m'))

    -- visual mode
    feed('v<F3>')
    eq('v', eval('m'))
    -- didn't leave visual mode
    eq('v', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- visual mapping in select mode
    feed('gh<F3>')
    eq('v', eval('m'))
    -- didn't leave select mode
    eq('s', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- select mode mapping
    feed_command('snoremap <F3> <Cmd>let m = mode(1)<cr>')
    feed('gh<F3>')
    eq('s', eval('m'))
    -- didn't leave select mode
    eq('s', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- operator-pending mode
    feed("d<F3>")
    eq('no', eval('m'))
    -- did leave operator-pending mode
    eq('n', eval('mode(1)'))

    --insert mode
    feed('i<F3>')
    eq('i', eval('m'))
    eq('i', eval('mode(1)'))

    -- replace mode
    feed("<Ins><F3>")
    eq('R', eval('m'))
    eq('R', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- virtual replace mode
    feed("gR<F3>")
    eq('Rv', eval('m'))
    eq('Rv', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- langmap works, but is not distinguished in mode(1)
    feed(":set iminsert=1<cr>i<F3>")
    eq('i', eval('m'))
    eq('i', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    feed(':<F3>')
    eq('c', eval('m'))
    eq('c', eval('mode(1)'))
    feed('<esc>')
    eq('n', eval('mode(1)'))

    -- terminal mode
    feed_command('tnoremap <F3> <Cmd>let m = mode(1)<cr>')
    feed_command('split | terminal')
    feed('i')
    eq('t', eval('mode(1)'))
    feed('<F3>')
    eq('t', eval('m'))
    eq('t', eval('mode(1)'))
  end)

  it('works in normal mode', function()
    cmdmap('<F2>', 'let s = [mode(1), v:count, v:register]')

    -- check v:count and v:register works
    feed('<F2>')
    eq({'n', 0, '"'}, eval('s'))
    feed('7<F2>')
    eq({'n', 7, '"'}, eval('s'))
    feed('"e<F2>')
    eq({'n', 0, 'e'}, eval('s'))
    feed('5"k<F2>')
    eq({'n', 5, 'k'}, eval('s'))
    feed('"+2<F2>')
    eq({'n', 2, '+'}, eval('s'))

    -- text object enters visual mode
    feed('<F7>')
    screen:expect([[
      so{5:me short lines}                                                 |
      {5:of }^test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- VISUAL --}                                                     |
    ]])
    feed('<esc>')

    -- startinsert
    feed('<F8>')
    eq('i', eval('mode(1)'))
    feed('<esc>')

    eq('n', eval('mode(1)'))
    cmdmap(',a', 'call feedkeys("aalpha") \\| let g:a = getline(2)')
    cmdmap(',b', 'call feedkeys("abeta", "x") \\| let g:b = getline(2)')

    feed(',a<F3>')
    screen:expect([[
      some short lines                                                 |
      of alpha^test text                                                |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])
    -- feedkeys were not executed immediately
    eq({'n', 'of test text'}, eval('[m,a]'))
    eq('i', eval('mode(1)'))
    feed('<esc>')

    feed(',b<F3>')
    screen:expect([[
      some short lines                                                 |
      of alphabet^atest text                                            |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]])
    -- feedkeys(..., 'x') was executed immediately, but insert mode gets aborted
    eq({'n', 'of alphabetatest text'}, eval('[m,b]'))
    eq('n', eval('mode(1)'))
  end)

  it('works in :normal command', function()
    feed_command('noremap ,x <Cmd>call append(1, "xx")\\| call append(1, "aa")<cr>')
    feed_command('noremap ,f <Cmd>nosuchcommand<cr>')
    feed_command('noremap ,e <Cmd>throw "very error"\\| call append(1, "yy")<cr>')
    feed_command('noremap ,m <Cmd>echoerr "The message."\\| call append(1, "zz")<cr>')
    feed_command('noremap ,w <Cmd>for i in range(5)\\|if i==1\\|echoerr "Err"\\|endif\\|call append(1, i)\\|endfor<cr>')

    feed(":normal ,x<cr>")
    screen:expect([[
      ^some short lines                                                 |
      aa                                                               |
      xx                                                               |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]])

    eq('Vim:E492: Not an editor command: nosuchcommand', exc_exec("normal ,f"))
    eq('very error', exc_exec("normal ,e"))
    eq('Vim(echoerr):The message.', exc_exec("normal ,m"))
    feed('w')
    screen:expect([[
      some ^short lines                                                 |
      aa                                                               |
      xx                                                               |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]])

    feed_command(':%d')
    eq('Vim(echoerr):Err', exc_exec("normal ,w"))
    screen:expect([[
      ^                                                                 |
      0                                                                |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      --No lines in buffer--                                           |
    ]])

    feed_command(':%d')
    feed_command(':normal ,w')
    screen:expect([[
      ^                                                                 |
      4                                                                |
      3                                                                |
      2                                                                |
      1                                                                |
      0                                                                |
      {1:~                                                                }|
      {2:Err}                                                              |
    ]])
  end)

  it('works in visual mode', function()
    -- can extend visual mode
    feed('v<F4>')
    screen:expect([[
      {5:some short }^lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- VISUAL --}                                                     |
    ]])
    eq('v', funcs.mode(1))

    -- can invoke operator, ending visual mode
    feed('<F5>')
    eq('n', funcs.mode(1))
    eq({'some short l'}, funcs.getreg('a',1,1))

    -- error doesn't interrupt visual mode
    feed('ggvw<F6>')
    screen:expect([[
      {5:some }short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {7:                                                                 }|
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      {3:Press ENTER or type command to continue}^                          |
    ]])
    feed('<cr>')
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    -- still in visual mode, <cr> was consumed by the error prompt
    screen:expect([[
      {5:some }^short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- VISUAL --}                                                     |
    ]])
    eq('v', funcs.mode(1))
    feed('<F7>')
    screen:expect([[
      so{5:me short lines}                                                 |
      {5:of }^test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- VISUAL --}                                                     |
    ]])
    eq('v', funcs.mode(1))

    -- startinsert gives "-- (insert) VISUAL --" mode
    feed('<F8>')
    screen:expect([[
      so{5:me short lines}                                                 |
      {5:of }^test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- (insert) VISUAL --}                                            |
    ]])
    eq('v', eval('mode(1)'))
    feed('<esc>')
    eq('i', eval('mode(1)'))
  end)

  it('works in select mode', function()
    feed_command('snoremap <F1> <cmd>throw "very error"<cr>')
    feed_command('snoremap <F2> <cmd>normal! <c-g>"by<cr>')
    -- can extend select mode
    feed('gh<F4>')
    screen:expect([[
      {5:some short }^lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- SELECT --}                                                     |
    ]])
    eq('s', funcs.mode(1))

    -- visual mapping in select mode restart selct mode after operator
    feed('<F5>')
    eq('s', funcs.mode(1))
    eq({'some short l'}, funcs.getreg('a',1,1))

    -- select mode mapping works, and does not restart select mode
    feed('<F2>')
    eq('n', funcs.mode(1))
    eq({'some short l'}, funcs.getreg('b',1,1))

    -- error doesn't interrupt temporary visual mode
    feed('<esc>ggvw<c-g><F6>')
    screen:expect([[
      {5:some }short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {7:                                                                 }|
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      {3:Press ENTER or type command to continue}^                          |
    ]])
    feed('<cr>')
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    -- still in visual mode, <cr> was consumed by the error prompt
    screen:expect([[
      {5:some }^short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- VISUAL --}                                                     |
    ]])
    -- quirk: restoration of select mode is not performed
    eq('v', funcs.mode(1))

    -- error doesn't interrupt select mode
    feed('<esc>ggvw<c-g><F1>')
    screen:expect([[
      {5:some }short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {7:                                                                 }|
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      {3:Press ENTER or type command to continue}^                          |
    ]])
    feed('<cr>')
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    -- still in select mode, <cr> was consumed by the error prompt
    screen:expect([[
      {5:some }^short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- SELECT --}                                                     |
    ]])
    -- quirk: restoration of select mode is not performed
    eq('s', funcs.mode(1))

    feed('<F7>')
    screen:expect([[
      so{5:me short lines}                                                 |
      {5:of }^test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- SELECT --}                                                     |
    ]])
    eq('s', funcs.mode(1))

    -- startinsert gives "-- SELECT (insert) --" mode
    feed('<F8>')
    screen:expect([[
      so{5:me short lines}                                                 |
      {5:of }^test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- (insert) SELECT --}                                            |
    ]])
    eq('s', eval('mode(1)'))
    feed('<esc>')
    eq('i', eval('mode(1)'))
  end)


  it('works in operator-pending mode', function()
    feed('d<F4>')
    expect([[
        lines
        of test text]])
    eq({'some short '}, funcs.getreg('"',1,1))
    feed('.')
    expect([[
        test text]])
    eq({'lines', 'of '}, funcs.getreg('"',1,1))
    feed('uu')
    expect([[
        some short lines
        of test text]])

    -- error aborts operator-pending, operator not performed
    feed('d<F6>')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {7:                                                                 }|
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      {3:Press ENTER or type command to continue}^                          |
    ]])
    feed('<cr>')
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    expect([[
        some short lines
        of test text]])

    feed('"bd<F7>')
    expect([[
        soest text]])
    eq(funcs.getreg('b',1,1), {'me short lines', 'of t'})

    -- startinsert aborts operator
    feed('d<F8>')
    eq('i', eval('mode(1)'))
    expect([[
        soest text]])
  end)

  it('works in insert mode', function()

    -- works the same as <c-o>w<c-o>w
    feed('iindeed <F4>little ')
    screen:expect([[
      indeed some short little ^lines                                   |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])

    feed('<F6>')
    screen:expect([[
      indeed some short little lines                                   |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {7:                                                                 }|
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      {3:Press ENTER or type command to continue}^                          |
    ]])


    feed('<cr>')
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    -- still in insert
    screen:expect([[
      indeed some short little ^lines                                   |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])
    eq('i', eval('mode(1)'))

    -- When entering visual mode from InsertEnter autocmd, an async event, or
    -- a <cmd> mapping, vim ends up in undocumented "INSERT VISUAL" mode. If a
    -- vim patch decides to disable this mode, this test is expected to fail.
    feed('<F7>stuff ')
    screen:expect([[
      in{5:deed some short little lines}                                   |
      {5:of stuff }^test text                                               |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT VISUAL --}                                              |
    ]])
    expect([[
      indeed some short little lines
      of stuff test text]])

    feed('<F5>')
    eq(funcs.getreg('a',1,1), {'deed some short little lines', 'of stuff t'})

    -- still in insert
    screen:expect([[
      in^deed some short little lines                                   |
      of stuff test text                                               |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])
    eq('i', eval('mode(1)'))

    -- also works as part of abbreviation
    feed('<space>foo ')
    screen:expect([[
      in bar ^deed some short little lines                              |
      of stuff test text                                               |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])
    eq(17, eval('g:y'))

    -- :startinsert does nothing
    feed('<F8>')
    eq('i', eval('mode(1)'))

    -- :stopinsert works
    feed('<F9>')
    eq('n', eval('mode(1)'))
  end)

  it('works in cmdline mode', function()
    feed(':text<F3>')
    eq('c', eval('m'))
    -- didn't leave cmdline mode
    eq('c', eval('mode(1)'))
    feed('<cr>')
    eq('n', eval('mode(1)'))
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {2:E492: Not an editor command: text}                                |
    ]])

    feed(':echo 2<F6>')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {7:                                                                 }|
      :echo 2                                                          |
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      :echo 2^                                                          |
    ]])
    eq('E605: Exception not caught: very error', eval('v:errmsg'))
    -- didn't leave cmdline mode
    eq('c', eval('mode(1)'))
    feed('+2<cr>')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {7:                                                                 }|
      :echo 2                                                          |
      {2:Error detected while processing :}                                |
      {2:E605: Exception not caught: very error}                           |
      4                                                                |
      {3:Press ENTER or type command to continue}^                          |
    ]])
    -- however, message scrolling may cause extra CR prompt
    -- This is consistent with output from async events.
    feed('<cr>')
    screen:expect([[
      ^some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]])
    eq('n', eval('mode(1)'))

    feed(':let g:x = 3<F4>')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      :let g:x = 3^                                                     |
    ]])
    feed('+2<cr>')
    -- cursor was moved in the background
    screen:expect([[
      some short ^lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      :let g:x = 3+2                                                   |
    ]])
    eq(5, eval('g:x'))

    feed(':let g:y = 7<F8>')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      :let g:y = 7^                                                     |
    ]])
    eq('c', eval('mode(1)'))
    feed('+2<cr>')
    -- startinsert takes effect after leaving cmdline mode
    screen:expect([[
      some short ^lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {4:-- INSERT --}                                                     |
    ]])
    eq('i', eval('mode(1)'))
    eq(9, eval('g:y'))

  end)

  it("doesn't crash when invoking cmdline mode recursively #8859", function()
    cmdmap('<F2>', 'norm! :foo')
    feed(':bar')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      :bar^                                                             |
    ]])

    feed('<f2>x')
    screen:expect([[
      some short lines                                                 |
      of test text                                                     |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      :barx^                                                            |
    ]])
  end)

end)

