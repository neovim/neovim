local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval
local request = t.request
local source = t.source

describe('autocmd BufEnter', function()
  before_each(clear)

  it("triggered by nvim_command('edit <dir>')", function()
    command("autocmd BufEnter * if isdirectory(expand('<afile>')) | let g:dir_bufenter = 1 | endif")
    request('nvim_command', 'split .')
    eq(1, eval("exists('g:dir_bufenter')")) -- Did BufEnter for the directory.
    eq(2, eval("bufnr('%')")) -- Switched to the dir buffer.
  end)

  it('triggered by "try|:split <dir>|endtry" in a function', function()
    command("autocmd BufEnter * if isdirectory(expand('<afile>')) | let g:dir_bufenter = 1 | endif")
    source([[
      function! Test()
        try
          exe 'split .'
        catch
        endtry
      endfunction
    ]])
    command('call Test()')
    eq(1, eval("exists('g:dir_bufenter')")) -- Did BufEnter for the directory.
    eq(2, eval("bufnr('%')")) -- Switched to the dir buffer.
  end)

  it('triggered by ":split normal|:help|:bw"', function()
    t.add_builddir_to_rtp()
    command('split normal')
    command('wincmd j')
    command('help')
    command('wincmd L')
    command('autocmd BufEnter normal let g:bufentered = 1')
    command('bw')
    eq(1, eval('bufnr("%")')) -- The cursor is back to the bottom window
    eq(0, eval("exists('g:bufentered')")) -- The autocmd hasn't been triggered
  end)
end)
