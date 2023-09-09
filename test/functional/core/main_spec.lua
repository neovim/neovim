local luv = require('luv')
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local matches = helpers.matches
local feed = helpers.feed
local eval = helpers.eval
local clear = helpers.clear
local funcs = helpers.funcs
local nvim_prog_abs = helpers.nvim_prog_abs
local write_file = helpers.write_file
local is_os = helpers.is_os
local skip = helpers.skip

describe('command-line option', function()
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
      eq(nil, luv.fs_stat(fname))
      funcs.system(
        {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
         '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
         '-s', '-', fname},
        {':call setline(1, "42")', ':wqall!', ''})
      eq(0, eval('v:shell_error'))
      local attrs = luv.fs_stat(fname)
      eq(#('42\n'), attrs.size)
    end)

    it('does not expand $VAR', function()
      eq(nil, luv.fs_stat(fname))
      eq(true, not not dollar_fname:find('%$%w+'))
      write_file(dollar_fname, ':call setline(1, "100500")\n:wqall!\n')
      funcs.system(
        {nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE', '--headless',
         '--cmd', 'set noswapfile shortmess+=IFW fileformats=unix',
         '-s', dollar_fname, fname})
      eq(0, eval('v:shell_error'))
      local attrs = luv.fs_stat(fname)
      eq(#('100500\n'), attrs.size)
    end)

    it('does not crash after reading from stdin in non-headless mode', function()
      skip(is_os('win'))
      local screen = Screen.new(40, 8)
      screen:attach()
      local args = {
        nvim_prog_abs(), '-u', 'NONE', '-i', 'NONE',
        '--cmd', '"set noswapfile shortmess+=IFW fileformats=unix"',
        '-s', '-'
      }

      -- Need to explicitly pipe to stdin so that the embedded Nvim instance doesn't try to read
      -- data from the terminal #18181
      funcs.termopen(string.format([[echo "" | %s]], table.concat(args, " ")))
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
        [1] = {foreground = tonumber('0x4040ff'), fg_indexed=true},
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
      eq(nil, luv.fs_stat(fname_2))
    end)
  end)

  it('nvim -v, :version', function()
    matches('Run ":verbose version"', funcs.execute(':version'))
    matches('Compilation: .*Run :checkhealth', funcs.execute(':verbose version'))
    matches('Run "nvim %-V1 %-v"', funcs.system({nvim_prog_abs(), '-v'}))
    matches('Compilation: .*Run :checkhealth', funcs.system({nvim_prog_abs(), '-V1', '-v'}))
  end)
end)
