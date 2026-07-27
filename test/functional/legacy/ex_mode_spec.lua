local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local eq = t.eq
local feed = n.feed
local fn = n.fn

before_each(clear)

-- Interactive Ex mode ([count]q:) is a keep-open |cmdwin| REPL. #40962
describe('Ex mode', function()
  it('executes commands against the caller window, auto-prints, records history', function()
    local screen = Screen.new(60, 10)
    command([[call setline(1, ['line1', 'line2', 'line3'])]])
    feed('1q:')
    screen:expect([[
      line1                                                       |
      {2:[No Name] [+]                                               }|
      {1::}^                                                           |
      {1:~                                                           }|*5
      {3:[Ex mode]                                                   }|
      {5:-- INSERT --}                                                |
    ]])
    t.matches('Entering Ex mode%.', n.exec_capture('messages'))
    feed("put ='inserted'<CR>")
    feed('visual<CR>')
    eq('n', fn.mode(1))
    eq({ 'line1', 'inserted', 'line2', 'line3' }, fn.getline(1, '$'))
    eq('visual', fn.histget('cmd', -1))
    eq("put ='inserted'", fn.histget('cmd', -2))
    -- Ex mode can be re-entered (the "[Ex mode]" buffer name is not duplicated).
    feed('1q:')
    screen:expect({ any = vim.pesc('{3:[Ex mode]') })
    feed('visual<CR>')
    eq('n', fn.mode(1))
    -- ":exmode" (but not ":ex", which is ":edit") also enters Ex mode.
    eq('ex', fn.fullcommand('ex'))
    eq('exmode', fn.fullcommand('exm'))
    command('exmode')
    screen:expect({ any = vim.pesc('{3:[Ex mode]') })
    feed('visual<CR>')
    eq('n', fn.mode(1))
  end)

  it('bare address and empty line move the cursor and auto-print', function()
    local screen = Screen.new(60, 8)
    command([[call setline(1, ['line1', 'line2'])]])
    feed('1q:')
    feed('1<CR>') -- Bare address: move and auto-print.
    screen:expect({ any = vim.pesc('" line1') })
    feed('<CR>') -- Empty line: advance and auto-print (POSIX ex "+").
    screen:expect({ any = vim.pesc('" line2') })
    feed('<CR>') -- At end-of-file.
    screen:expect({ any = 'E501' })
    feed('visual<CR>')
    eq(2, fn.line('.'))
  end)

  it('explicit :print is not doubled by auto-print', function()
    command([[call setline(1, ['line1', 'line2'])]])
    feed('1q:')
    feed('1,2print<CR>')
    -- Transcript records each printed line once, not the cursor line again.
    eq({ '1,2print', '" line1', '" line2', '' }, n.api.nvim_buf_get_lines(0, 0, -1, false))
    feed('visual<CR>')
  end)

  it('substitute confirmation prompt', function()
    local screen = Screen.new(60, 8)
    command('set inccommand=')
    command([[call setline(1, repeat(['foo foo'], 2))]])
    feed('1q:')
    feed('%s/foo/bar/gc<CR>')
    screen:expect({ any = vim.pesc('replace with bar? (y)es/(n)o/(a)ll') })
    feed('y') -- Replace the first match ...
    feed('q') -- ... then quit at the second prompt: back to the REPL.
    screen:expect({ any = vim.pesc('{5:-- INSERT --}') })
    feed('visual<CR>')
    eq({ 'bar foo', 'foo foo' }, fn.getline(1, '$'))
  end)

  it('collects multi-line commands until the block is complete', function()
    local screen = Screen.new(60, 10)
    feed('1q:')
    feed('append<CR>')
    -- Continuation lines should not have ":" prefix in 'statuscolumn'.
    screen:expect([[
                                                                  |
      {2:[No Name]                                                   }|
      {1::}append                                                     |
      {1: }^                                                           |
      {1:~                                                           }|*4
      {3:[Ex mode]                                                   }|
      {5:-- INSERT --}                                                |
    ]])
    feed('x1<CR>x2<CR>.<CR>')
    -- Executing :append does not end the REPL's Insert mode (ex_append restores "State").
    eq('i', fn.mode(1))
    -- Ending :append with "." does not auto-print the last inserted line.
    eq({ 'append', 'x1', 'x2', '.', '' }, n.api.nvim_buf_get_lines(0, 0, -1, false))
    feed('let g:x = 0<CR>')
    feed('if 1<CR>')
    -- Continuation lines should not have ":" prefix in 'statuscolumn'.
    screen:expect([[
      x1                                                          |
      {2:[No Name] [+]                                               }|
      {1: }x1                                                         |
      {1: }x2                                                         |
      {1: }.                                                          |
      {1::}let g:x = 0                                                |
      {1::}if 1                                                       |
      {1: }^                                                           |
      {3:[Ex mode]                                                   }|
      {5:-- INSERT --}                                                |
    ]])
    feed('let g:x = 1<CR>endif<CR>')
    feed('function! F()<CR>return 42<CR>endfunction<CR>')
    feed('let g:h =<lt><lt> trim EOS<CR>  hey<CR>EOS<CR>')
    feed('visual<CR>')
    eq({ 'x1', 'x2' }, fn.getline(1, '$'))
    eq(1, n.eval('g:x'))
    eq(42, n.eval('F()'))
    eq({ 'hey' }, n.eval('g:h'))
  end)

  it('pressing Ctrl-C in :append inside a loop does not hang', function()
    feed('1q:')
    feed('for i in range(1)<CR>')
    feed('append<CR>')
    -- CTRL-C cancels the cmdwin (ends Ex mode): back to the ":" cmdline, like |q:|.
    feed('<C-C>')
    eq('', fn.getcmdwintype())
    feed('<Esc>')
    eq('n', fn.mode(1))
    eq({ '' }, fn.getline(1, '$'))
  end)
end)
