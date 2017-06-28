local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local feed = helpers.feed
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local source = helpers.source

local screen

before_each(function()
  clear()
  screen = Screen.new(40, 8)
  screen:attach()
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
    let g:EMPTY = ''
    cnoremap <expr> {REDRAW} Redraw()
    nnoremap <expr> {PROMPT} extend(g:, {"out": input({"prompt": ":", "highlight": g:Nvim_color_input})}).EMPTY
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
  ]])
  screen:set_default_attr_ids({
    RBP1={background = Screen.colors.Red},
    RBP2={background = Screen.colors.Yellow},
    RBP3={background = Screen.colors.Green},
    RBP4={background = Screen.colors.Blue},
    EOB={bold = true, foreground = Screen.colors.Blue1},
    ERR={foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    SK={foreground = Screen.colors.Blue},
  })
end)

local function set_color_cb(funcname)
  meths.set_var('Nvim_color_input', funcname)
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
    -- FIXME
    -- feed('{REDRAW}')
    -- screen:expect([[
    --                                           |
    --   {EOB:~                                       }|
    --   {EOB:~                                       }|
    --   {EOB:~                                       }|
    --   {EOB:~                                       }|
    --   {EOB:~                                       }|
    --   {EOB:~                                       }|
    --   :echo {RBP1:(}{RBP2:(}42{RBP2:)}^                             |
    -- ]])
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
    if true then return pending('echoerr does not work well now') end
    set_color_cb('Echoerring')
    start_prompt('e')
    -- FIXME Does not work well with :echoerr: error message overwrites cmdline.
  end)
  it('does the right thing when throwing', function()
    if true then return pending('Throwing does not work well now') end
    set_color_cb('Throwing')
    start_prompt('e')
    -- FIXME Does not work well with :throw: error message overwrites cmdline.
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
    if true then return pending('<C-c> does not work well enough now') end
    set_color_cb('Halting')
    start_prompt('echo 42')
    for i = 1, 6 do
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
      feed('<C-c>')
    end
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      Type  :quit<Enter>  to exit Nvim        |
    ]])
    start_prompt('echo 42<CR>')
    screen:expect([[
      ^                                        |
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      {EOB:~                                       }|
      42                                      |
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
  -- TODO Check for all other errors
end)
describe('Ex commands coloring support', function()
  it('still executes command-line even if errored out', function()
    meths.set_var('Nvim_color_cmdline', 'SplittedMultibyteStart')
    feed(':let x = "«"\n')
    eq('«', meths.get_var('x'))
    local msg = 'E5405: Chunk 0 start 10 splits multibyte character'
    eq('\n'..msg, funcs.execute('messages'))
  end)
end)

-- TODO Specifically test for coloring in cmdline and expr modes
