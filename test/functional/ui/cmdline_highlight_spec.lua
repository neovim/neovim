local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local feed = helpers.feed
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local source = helpers.source
local dedent = helpers.dedent
local command = helpers.command
local curbufmeths = helpers.curbufmeths

local screen

-- Bug in input() handling: :redraw! will erase the whole prompt up until
-- user types something. It exists in Vim as well, so using `h<BS>` as
-- a workaround.
local function redraw_input()
  feed('{REDRAW}h<BS>')
end

before_each(function()
  clear()
  screen = Screen.new(40, 8)
  screen:attach()
  command("set display-=msgsep")
  source([[
    highlight RBP1 guibg=Red
    highlight RBP2 guibg=Yellow
    highlight RBP3 guibg=Green
    highlight RBP4 guibg=Blue
    let g:NUM_LVLS = 4
    function Redraw()
      redraw!
      return ''
    endfunction
    let g:id = ''
    cnoremap <expr> {REDRAW} Redraw()
    function DoPrompt(do_return) abort
      let id = g:id
      let Cb = g:Nvim_color_input{g:id}
      let out = input({'prompt': ':', 'highlight': Cb})
      let g:out{id} = out
      return (a:do_return ? out : '')
    endfunction
    nnoremap <expr> {PROMPT} DoPrompt(0)
    cnoremap <expr> {PROMPT} DoPrompt(1)
    function RainBowParens(cmdline)
      let ret = []
      let i = 0
      let lvl = 0
      while i < len(a:cmdline)
        if a:cmdline[i] is# '('
          call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
          let lvl += 1
        elseif a:cmdline[i] is# ')'
          let lvl -= 1
          call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
        endif
        let i += 1
      endwhile
      return ret
    endfunction
    function SplittedMultibyteStart(cmdline)
      let ret = []
      let i = 0
      while i < len(a:cmdline)
        let char = nr2char(char2nr(a:cmdline[i:]))
        if a:cmdline[i:i +  len(char) - 1] is# char
          if len(char) > 1
            call add(ret, [i + 1, i + len(char), 'RBP2'])
          endif
          let i += len(char)
        else
          let i += 1
        endif
      endwhile
      return ret
    endfunction
    function SplittedMultibyteEnd(cmdline)
      let ret = []
      let i = 0
      while i < len(a:cmdline)
        let char = nr2char(char2nr(a:cmdline[i:]))
        if a:cmdline[i:i +  len(char) - 1] is# char
          if len(char) > 1
            call add(ret, [i, i + 1, 'RBP1'])
          endif
          let i += len(char)
        else
          let i += 1
        endif
      endwhile
      return ret
    endfunction
    function Echoing(cmdline)
      echo 'HERE'
      return v:_null_list
    endfunction
    function Echoning(cmdline)
      echon 'HERE'
      return v:_null_list
    endfunction
    function Echomsging(cmdline)
      echomsg 'HERE'
      return v:_null_list
    endfunction
    function Echoerring(cmdline)
      echoerr 'HERE'
      return v:_null_list
    endfunction
    function Redrawing(cmdline)
      redraw!
      return v:_null_list
    endfunction
    function Throwing(cmdline)
      throw "ABC"
      return v:_null_list
    endfunction
    function Halting(cmdline)
      while 1
      endwhile
    endfunction
    function ReturningGlobal(cmdline)
      return g:callback_return
    endfunction
    function ReturningGlobal2(cmdline)
      return g:callback_return[:len(a:cmdline)-1]
    endfunction
    function ReturningGlobalN(n, cmdline)
      return g:callback_return{a:n}
    endfunction
    let g:recording_calls = []
    function Recording(cmdline)
      call add(g:recording_calls, a:cmdline)
      return []
    endfunction
  ]])
  screen:set_default_attr_ids({
    RBP1={background = Screen.colors.Red},
    RBP2={background = Screen.colors.Yellow},
    RBP3={background = Screen.colors.Green},
    RBP4={background = Screen.colors.Blue},
    EOB={bold = true, foreground = Screen.colors.Blue1},
    ERR={foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    SK={foreground = Screen.colors.Blue},
    PE={bold = true, foreground = Screen.colors.SeaGreen4},
    NUM={foreground = Screen.colors.Blue2},
    NPAR={foreground = Screen.colors.Yellow},
    SQ={foreground = Screen.colors.Blue3},
    SB={foreground = Screen.colors.Blue4},
    E={foreground = Screen.colors.Red, background = Screen.colors.Blue},
    M={bold = true},
  })
end)

local function set_color_cb(funcname, callback_return, id)
  meths.set_var('id', id or '')
  if id and id ~= '' and funcs.exists('*' .. funcname .. 'N') then
    command(('let g:Nvim_color_input%s = {cmdline -> %sN(%s, cmdline)}'):format(
      id, funcname, id))
    if callback_return then
      meths.set_var('callback_return' .. id, callback_return)
    end
  else
    meths.set_var('Nvim_color_input', funcname)
    if callback_return then
      meths.set_var('callback_return', callback_return)
    end
  end
end
local function start_prompt(text)
  feed('{PROMPT}' .. (text or ''))
end

describe('Command-line coloring', function()
  it('works', function()
    set_color_cb('RainBowParens')
    meths.set_option('more', false)
    start_prompt()
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :^                                       |
    ]])
    feed('e')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :e^                                      |
    ]])
    feed('cho ')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo ^                                  |
    ]])
    feed('(')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}^                                 |
    ]])
    feed('(')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}^                                |
    ]])
    feed('42')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}42^                              |
    ]])
    feed('))')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}{RBP1:)}^                            |
    ]])
    feed('<BS>')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}^                             |
    ]])
    redraw_input()
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}^                             |
    ]])
  end)
  for _, func_part in ipairs({'', 'n', 'msg'}) do
    it('disables :echo' .. func_part .. ' messages', function()
      set_color_cb('Echo' .. func_part .. 'ing')
      start_prompt('echo')
      screen:expect([[
                                                |
        {EOB:~                                       }|
        {EOB:~                                       }|
        {EOB:~                                       }|
        {EOB:~                                       }|
        {EOB:~                                       }|
        {EOB:~                                       }|
        :echo^                                   |
      ]])
    end)
  end
  it('does the right thing when hl start appears to split multibyte char',
  function()
    set_color_cb('SplittedMultibyteStart')
    start_prompt('echo "«')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo "                                 |
      {ERR:E5405: Chunk 0 start 7 splits multibyte }|
      {ERR:character}                               |
      :echo "«^                                |
    ]])
    feed('»')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo "                                 |
      {ERR:E5405: Chunk 0 start 7 splits multibyte }|
      {ERR:character}                               |
      :echo "«»^                               |
    ]])
  end)
  it('does the right thing when hl end appears to split multibyte char',
  function()
    set_color_cb('SplittedMultibyteEnd')
    start_prompt('echo "«')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo "                                 |
      {ERR:E5406: Chunk 0 end 7 splits multibyte ch}|
      {ERR:aracter}                                 |
      :echo "«^                                |
    ]])
  end)
  it('does the right thing when errorring', function()
    set_color_cb('Echoerring')
    start_prompt('e')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5407: Callback has thrown an exception:}|
      {ERR: Vim(echoerr):HERE}                      |
      :e^                                      |
    ]])
  end)
  it('silences :echo', function()
    set_color_cb('Echoing')
    start_prompt('e')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :e^                                      |
    ]])
    eq('', meths.command_output('messages'))
  end)
  it('silences :echon', function()
    set_color_cb('Echoning')
    start_prompt('e')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :e^                                      |
    ]])
    eq('', meths.command_output('messages'))
  end)
  it('silences :echomsg', function()
    set_color_cb('Echomsging')
    start_prompt('e')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :e^                                      |
    ]])
    eq('', meths.command_output('messages'))
  end)
  it('does the right thing when throwing', function()
    set_color_cb('Throwing')
    start_prompt('e')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5407: Callback has thrown an exception:}|
      {ERR: ABC}                                    |
      :e^                                      |
    ]])
  end)
  it('stops executing callback after a number of errors', function()
    set_color_cb('SplittedMultibyteStart')
    start_prompt('let x = "«»«»«»«»«»"\n')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :let x = "                              |
      {ERR:E5405: Chunk 0 start 10 splits multibyte}|
      {ERR: character}                              |
      ^:let x = "«»«»«»«»«»"                   |
    ]])
    feed('\n')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    eq('let x = "«»«»«»«»«»"', meths.get_var('out'))
    local msg = '\nE5405: Chunk 0 start 10 splits multibyte character'
    eq(msg:rep(1), funcs.execute('messages'))
  end)
  it('allows interrupting callback with <C-c>', function()
    set_color_cb('Halting')
    start_prompt('echo 42')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    screen:sleep(500)
    feed('<C-c>')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5407: Callback has thrown an exception:}|
      {ERR: Keyboard interrupt}                     |
      :echo 42^                                |
    ]])
    redraw_input()
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo 42^                                |
    ]])
    feed('\n')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ^:echo 42                                |
    ]])
    feed('\n')
    eq('echo 42', meths.get_var('out'))
    feed('<C-c>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      Type  :qa!  and pr...nges and exit Nvim |
    ]])
  end)
  it('works fine with NUL, NL, CR', function()
    set_color_cb('RainBowParens')
    start_prompt('echo ("<C-v><CR><C-v><Nul><C-v><NL>")')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}"{SK:^M^@^@}"{RBP1:)}^                        |
    ]])
  end)
  it('errors out when callback returns something wrong', function()
    command('cnoremap + ++')
    set_color_cb('ReturningGlobal', '')
    start_prompt('#')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5400: Callback should return list}      |
      :#^                                      |
    ]])

    feed('<CR><CR><CR>')
    set_color_cb('ReturningGlobal', {{0, 1, 'Normal'}, 42})
    start_prompt('#')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5401: List item 1 is not a List}        |
      :#^                                      |
    ]])

    feed('<CR><CR><CR>')
    set_color_cb('ReturningGlobal2', {{0, 1, 'Normal'}, {1}})
    start_prompt('+')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :+                                      |
      {ERR:E5402: List item 1 has incorrect length:}|
      {ERR: 1 /= 3}                                 |
      :++^                                     |
    ]])

    feed('<CR><CR><CR>')
    set_color_cb('ReturningGlobal2', {{0, 1, 'Normal'}, {2, 3, 'Normal'}})
    start_prompt('+')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :+                                      |
      {ERR:E5403: Chunk 1 start 2 not in range [1, }|
      {ERR:2)}                                      |
      :++^                                     |
    ]])

    feed('<CR><CR><CR>')
    set_color_cb('ReturningGlobal2', {{0, 1, 'Normal'}, {1, 3, 'Normal'}})
    start_prompt('+')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :+                                      |
      {ERR:E5404: Chunk 1 end 3 not in range (1, 2]}|
                                              |
      :++^                                     |
    ]])
  end)
  it('does not error out when called from a errorred out cycle', function()
    set_color_cb('ReturningGlobal', {{0, 1, 'Normal'}})
    feed(dedent([[
      :set regexpengine=2
      :for pat in [' \ze*', ' \zs*']
      :  try
      :    let l = matchlist('x x', pat)
      :    $put =input({'prompt':'>','highlight':'ReturningGlobal'})
      :
      :    $put ='E888 NOT detected for ' . pat
      :  catch
      :    $put =input({'prompt':'>','highlight':'ReturningGlobal'})
      :
      :    $put ='E888 detected for ' . pat
      :  endtry
      :endfor
      :
      :
      :
      :
      :
      :
    ]]))
    eq({'', ':', 'E888 detected for  \\ze*', ':', 'E888 detected for  \\zs*'},
       curbufmeths.get_lines(0, -1, false))
    eq('', funcs.execute('messages'))
  end)
  it('allows nesting input()s', function()
    set_color_cb('ReturningGlobal', {{0, 1, 'RBP1'}}, '')
    start_prompt('1')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP1:1}^                                      |
    ]])

    set_color_cb('ReturningGlobal', {{0, 1, 'RBP2'}}, '1')
    start_prompt('2')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP2:2}^                                      |
    ]])

    set_color_cb('ReturningGlobal', {{0, 1, 'RBP3'}}, '2')
    start_prompt('3')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP3:3}^                                      |
    ]])

    set_color_cb('ReturningGlobal', {{0, 1, 'RBP4'}}, '3')
    start_prompt('4')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP4:4}^                                      |
    ]])

    feed('<CR>')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP3:3}4^                                     |
    ]])
    feed('<CR>')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP2:2}34^                                    |
    ]])
    feed('<CR>')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :{RBP1:1}234^                                   |
    ]])
    feed('<CR><CR><C-l>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    eq('1234', meths.get_var('out'))
    eq('234', meths.get_var('out1'))
    eq('34', meths.get_var('out2'))
    eq('4', meths.get_var('out3'))
    eq(0, funcs.exists('g:out4'))
  end)
  it('runs callback with the same data only once', function()
    local function new_recording_calls(...)
      eq({...}, meths.get_var('recording_calls'))
      meths.set_var('recording_calls', {})
    end
    set_color_cb('Recording')
    start_prompt('')
    -- Regression test. Disambiguation:
    --
    --     new_recording_calls(expected_result) -- (actual_before_fix)
    --
    feed('a')
    new_recording_calls('a')  -- ('a', 'a')
    feed('b')
    new_recording_calls('ab') -- ('a', 'ab', 'ab')
    feed('c')
    new_recording_calls('abc')  -- ('ab', 'abc', 'abc')
    feed('<BS>')
    new_recording_calls('ab')  -- ('abc', 'ab', 'ab')
    feed('<BS>')
    new_recording_calls('a')  -- ('ab', 'a', 'a')
    feed('<BS>')
    new_recording_calls()  -- ('a')
    feed('<CR><CR>')
    eq('', meths.get_var('out'))
  end)
  it('does not crash when callback has caught not-a-editor-command exception',
  function()
    source([[
      function CaughtExc(cmdline) abort
        try
          gibberish
        catch
          " Do nothing
        endtry
        return []
      endfunction
    ]])
    set_color_cb('CaughtExc')
    start_prompt('1')
    eq(1, meths.eval('1'))
  end)
end)
describe('Ex commands coloring support', function()
  it('works', function()
    meths.set_var('Nvim_color_cmdline', 'RainBowParens')
    feed(':echo (((1)))')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :echo {RBP1:(}{RBP2:(}{RBP3:(}1{RBP3:)}{RBP2:)}{RBP1:)}^                           |
    ]])
  end)
  it('still executes command-line even if errored out', function()
    meths.set_var('Nvim_color_cmdline', 'SplittedMultibyteStart')
    feed(':let x = "«"\n')
    eq('«', meths.get_var('x'))
    local msg = 'E5405: Chunk 0 start 10 splits multibyte character'
    eq('\n'..msg, funcs.execute('messages'))
  end)
  it('does not error out when called from a errorred out cycle', function()
    -- Apparently when there is a cycle in which one of the commands errors out
    -- this error may be caught by color_cmdline before it is presented to the
    -- user.
    feed(dedent([[
      :set regexpengine=2
      :for pat in [' \ze*', ' \zs*']
      :  try
      :    let l = matchlist('x x', pat)
      :    $put ='E888 NOT detected for ' . pat
      :  catch
      :    $put ='E888 detected for ' . pat
      :  endtry
      :endfor
    ]]))
    eq({'', 'E888 detected for  \\ze*', 'E888 detected for  \\zs*'},
       curbufmeths.get_lines(0, -1, false))
    eq('', funcs.execute('messages'))
  end)
  it('does not crash when using `n` in debug mode', function()
    feed(':debug execute "echo 1"\n')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      Entering Debug mode.  Type "cont" to con|
      tinue.                                  |
      cmd: execute "echo 1"                   |
      >^                                       |
    ]])
    feed('n\n')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      Entering Debug mode.  Type "cont" to con|
      tinue.                                  |
      cmd: execute "echo 1"                   |
      >n                                      |
      1                                       |
      {PE:Press ENTER or type command to continue}^ |
    ]])
    feed('\n')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
  end)
  it('does not prevent mapping error from cancelling prompt', function()
    command("cnoremap <expr> x execute('throw 42')[-1]")
    feed(':#x')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :#                                      |
      {ERR:Error detected while processing :}       |
      {ERR:E605: Exception not caught: 42}          |
      :#^                                      |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    eq('Error detected while processing :\nE605: Exception not caught: 42',
       meths.command_output('messages'))
  end)
  it('errors out when failing to get callback', function()
    meths.set_var('Nvim_color_cmdline', 42)
    feed(':#')
    screen:expect([[
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :                                       |
      {ERR:E5408: Unable to get g:Nvim_color_cmdlin}|
      {ERR:e callback: Vim:E6000: Argument is not a}|
      {ERR: function or function name}              |
      :#^                                      |
    ]])
  end)
end)
describe('Expressions coloring support', function()
  it('works', function()
    meths.command('hi clear NvimNumber')
    meths.command('hi clear NvimNestingParenthesis')
    meths.command('hi NvimNumber guifg=Blue2')
    meths.command('hi NvimNestingParenthesis guifg=Yellow')
    feed(':echo <C-r>=(((1)))')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ={NPAR:(((}{NUM:1}{NPAR:)))}^                                |
    ]])
  end)
  it('does not use Nvim_color_expr', function()
    meths.set_var('Nvim_color_expr', 42)
    -- Used to error out due to failing to get callback.
    meths.command('hi clear NvimNumber')
    meths.command('hi NvimNumber guifg=Blue2')
    feed(':<C-r>=1')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ={NUM:1}^                                      |
    ]])
  end)
  it('works correctly with non-ASCII and control characters', function()
    meths.command('hi clear NvimStringBody')
    meths.command('hi clear NvimStringQuote')
    meths.command('hi clear NvimInvalid')
    meths.command('hi NvimStringQuote guifg=Blue3')
    meths.command('hi NvimStringBody guifg=Blue4')
    meths.command('hi NvimInvalid guifg=Red guibg=Blue')
    feed('i<C-r>="«»"«»')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ={SQ:"}{SB:«»}{SQ:"}{E:«»}^                                 |
    ]])
    feed('<C-c>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {M:-- INSERT --}                            |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
                                              |
    ]])
    feed(':<C-\\>e"<C-v><C-x>"<C-v><C-x>')
    -- TODO(ZyX-I): Parser highlighting should not override special character
    --              highlighting.
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ={SQ:"}{SB:^X}{SQ:"}{ERR:^X}^                                 |
    ]])
    feed('<C-c>')
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      :^                                       |
    ]])
    funcs.setreg('a', {'\192'})
    feed('<C-r>="<C-r><C-r>a"<C-r><C-r>a"foo"')
    -- TODO(ZyX-I): Parser highlighting should not override special character
    --              highlighting.
    screen:expect([[
                                              |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      ={SQ:"}{SB:<c0>}{SQ:"}{E:<c0>"}{SB:foo}{E:"}^                        |
    ]])
  end)
end)
