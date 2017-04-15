local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local request = helpers.request
local source = helpers.source

describe('autocmd BufEnter', function()
  before_each(clear)

  it("triggered by nvim_command('edit <dir>')", function()
    command("autocmd BufEnter * if isdirectory(expand('<afile>')) | let g:dir_bufenter = 1 | endif")
    request("nvim_command", "split .")
    eq(1, eval("exists('g:dir_bufenter')"))  -- Did BufEnter for the directory.
    eq(2, eval("bufnr('%')"))                -- Switched to the dir buffer.
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
    command("call Test()")
    eq(1, eval("exists('g:dir_bufenter')"))  -- Did BufEnter for the directory.
    eq(2, eval("bufnr('%')"))                -- Switched to the dir buffer.
  end)
end)
