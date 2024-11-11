local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local uv = vim.uv

local eq = t.eq
local matches = t.matches
local feed = n.feed
local eval = n.eval
local clear = n.clear
local fn = n.fn
local nvim_prog_abs = n.nvim_prog_abs
local write_file = t.write_file
local is_os = t.is_os
local skip = t.skip

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
      eq(nil, uv.fs_stat(fname))
      fn.system({
        nvim_prog_abs(),
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--headless',
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '-s',
        '-',
        fname,
      }, { ':call setline(1, "42")', ':wqall!', '' })
      eq(0, eval('v:shell_error'))
      local attrs = uv.fs_stat(fname)
      eq(#'42\n', attrs.size)
    end)

    it('does not expand $VAR', function()
      eq(nil, uv.fs_stat(fname))
      eq(true, not not dollar_fname:find('%$%w+'))
      write_file(dollar_fname, ':call setline(1, "100500")\n:wqall!\n')
      fn.system({
        nvim_prog_abs(),
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--headless',
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '-s',
        dollar_fname,
        fname,
      })
      eq(0, eval('v:shell_error'))
      local attrs = uv.fs_stat(fname)
      eq(#'100500\n', attrs.size)
    end)

    it('does not crash when run completion in ex mode', function()
      fn.system({
        nvim_prog_abs(),
        '--clean',
        '-e',
        '-s',
        '--cmd',
        'exe "norm! i\\<C-X>\\<C-V>"',
      })
      eq(0, eval('v:shell_error'))
    end)

    it('does not crash after reading from stdin in non-headless mode', function()
      skip(is_os('win'))
      local screen = Screen.new(40, 8)
      local args = {
        nvim_prog_abs(),
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--cmd',
        '"set noswapfile shortmess+=IFW fileformats=unix notermguicolors"',
        '-s',
        '-',
      }

      -- Need to explicitly pipe to stdin so that the embedded Nvim instance doesn't try to read
      -- data from the terminal #18181
      fn.termopen(string.format([[echo "" | %s]], table.concat(args, ' ')), {
        env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
      })
      screen:expect(
        [[
        ^                                        |
        ~                                       |*4
        {1:[No Name]             0,0-1          All}|
                                                |*2
      ]],
        {
          [1] = { reverse = true },
        }
      )
      feed('i:cq<CR>')
      screen:expect([[
                                                |
        [Process exited 1]{2: }                     |
                                                |*5
        {5:-- TERMINAL --}                          |
      ]])
      --[=[ Example of incorrect output:
      screen:expect([[
        ^nvim: /var/tmp/portage/dev-libs/libuv-1.|
        10.2/work/libuv-1.10.2/src/unix/core.c:5|
        19: uv__close: Assertion `fd > STDERR_FI|
        LENO' failed.                           |
                                                |
        [Process exited 6]                      |
                                                |*2
      ]])
      ]=]
    end)

    it('errors out when trying to use nonexistent file with -s', function()
      eq(
        'Cannot open for reading: "' .. nonexistent_fname .. '": no such file or directory\n',
        fn.system({
          nvim_prog_abs(),
          '-u',
          'NONE',
          '-i',
          'NONE',
          '--headless',
          '--cmd',
          'set noswapfile shortmess+=IFW fileformats=unix',
          '--cmd',
          'language C',
          '-s',
          nonexistent_fname,
        })
      )
      eq(2, eval('v:shell_error'))
    end)

    it('errors out when trying to use -s twice', function()
      write_file(fname, ':call setline(1, "1")\n:wqall!\n')
      write_file(dollar_fname, ':call setline(1, "2")\n:wqall!\n')
      eq(
        'Attempt to open script file again: "-s ' .. dollar_fname .. '"\n',
        fn.system({
          nvim_prog_abs(),
          '-u',
          'NONE',
          '-i',
          'NONE',
          '--headless',
          '--cmd',
          'set noswapfile shortmess+=IFW fileformats=unix',
          '--cmd',
          'language C',
          '-s',
          fname,
          '-s',
          dollar_fname,
          fname_2,
        })
      )
      eq(2, eval('v:shell_error'))
      eq(nil, uv.fs_stat(fname_2))
    end)
  end)

  it('nvim -v, :version', function()
    matches('Run ":verbose version"', fn.execute(':version'))
    matches('Compilation: .*Run :checkhealth', fn.execute(':verbose version'))
    matches('Run "nvim %-V1 %-v"', fn.system({ nvim_prog_abs(), '-v' }))
    matches('Compilation: .*Run :checkhealth', fn.system({ nvim_prog_abs(), '-V1', '-v' }))
  end)

  if is_os('win') then
    for _, prefix in ipairs({ '~/', '~\\' }) do
      it('expands ' .. prefix .. ' on Windows', function()
        local fname = os.getenv('USERPROFILE') .. '\\nvim_test.txt'
        finally(function()
          os.remove(fname)
        end)
        write_file(fname, 'some text')
        eq(
          'some text',
          fn.system({
            nvim_prog_abs(),
            '-es',
            '+%print',
            '+q',
            prefix .. 'nvim_test.txt',
          }):gsub('\n', '')
        )
      end)
    end
  end
end)
