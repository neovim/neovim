local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local feed = helpers.feed
local eval = helpers.eval
local clear = helpers.clear
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local write_file = helpers.write_file

local function nvim_prog_abs()
  -- system(['build/bin/nvim']) does not work for whatever reason. It needs to
  -- either be executable searched in $PATH or something starting with / or ./.
  if nvim_prog:match('[/\\]') then
    return funcs.fnamemodify(nvim_prog, ':p')
  else
    return nvim_prog
  end
end

describe('Command-line option', function()
  describe('-s', function()
    local fname = 'Xtest-functional-core-main-s'
    local fname_2 = fname .. '.2'
    local nonexistent_fname = fname .. '.nonexistent'
    local dollar_fname = '$' .. fname
    before_each(function()
      clear()
      os.remove(fname)
      os.remove(dollar_fname)
    end)
    after_each(function()
      os.remove(fname)
      os.remove(dollar_fname)
    end)
    it('treats - as stdin', function()
      eq(nil, lfs.attributes(fname))
      funcs.system(
        {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
         '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
         '-s', '-', fname},
        {':call setline(1, "42")', ':wqall!', ''})
      eq(0, eval('v:shell_error'))
      local attrs = lfs.attributes(fname)
      eq(#('42\n'), attrs.size)
    end)
    it('does not expand $VAR', function()
      eq(nil, lfs.attributes(fname))
      eq(true, not not dollar_fname:find('%$%w+'))
      write_file(dollar_fname, ':call setline(1, "100500")\n:wqall!\n')
      funcs.system(
        {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
         '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
         '-s', dollar_fname, fname})
      eq(0, eval('v:shell_error'))
      local attrs = lfs.attributes(fname)
      eq(#('100500\n'), attrs.size)
    end)
    it('does not crash after reading from stdin in non-headless mode', function()
      if helpers.pending_win32(pending) then return end
      local screen = Screen.new(40, 8)
      screen:attach()
      funcs.termopen({
        nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
         '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
         '-s', '-'
      })
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {2:[No Name]             0,0-1          All}|
                                                |
                                                |
      ]], {
        [1] = {foreground = 4210943},
        [2] = {bold = true, reverse = true}
      })
      feed('i:cq<CR>')
      screen:expect([[
                                                |
        [Process exited 1]                      |
                                                |
                                                |
                                                |
                                                |
                                                |
        -- TERMINAL --                          |
      ]])
      --[=[ Example of incorrect output:
      screen:expect([[
        ^nvim: /var/tmp/portage/dev-libs/libuv-1.|
        10.2/work/libuv-1.10.2/src/unix/core.c:5|
        19: uv__close: Assertion `fd > STDERR_FI|
        LENO' failed.                           |
                                                |
        [Process exited 6]                      |
                                                |
                                                |
      ]])
      ]=]
    end)
    it('errors out when trying to use nonexistent file with -s', function()
      eq(
        'Cannot open for reading: "'..nonexistent_fname..'": no such file or directory\n',
        funcs.system(
          {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
           '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
           '--cmd', 'language C',
           '-s', nonexistent_fname}))
      eq(2, eval('v:shell_error'))
    end)
    it('errors out when trying to use -s twice', function()
      write_file(fname, ':call setline(1, "1")\n:wqall!\n')
      write_file(dollar_fname, ':call setline(1, "2")\n:wqall!\n')
      eq(
        'Attempt to open script file again: "-s '..dollar_fname..'"\n',
        funcs.system(
          {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
           '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
           '--cmd', 'language C',
           '-s', fname, '-s', dollar_fname, fname_2}))
      eq(2, eval('v:shell_error'))
      eq(nil, lfs.attributes(fname_2))
    end)
  end)
end)
