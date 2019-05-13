local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local command = helpers.command
local exc_exec = helpers.exc_exec
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths
local source = helpers.source

local file_base = 'Xtest-functional-ex_cmds-quickfix_commands'

before_each(clear)

for _, c in ipairs({'l', 'c'}) do
  local file = ('%s.%s'):format(file_base, c)
  local filecmd = c .. 'file'
  local getfcmd = c .. 'getfile'
  local addfcmd = c .. 'addfile'
  local getlist = (c == 'c') and funcs.getqflist or (
      function() return funcs.getloclist(0) end)

  describe((':%s*file commands'):format(c), function()
    before_each(function()
      write_file(file, ([[
        %s-1.res:700:10:Line 700
        %s-2.res:800:15:Line 800
      ]]):format(file, file))
    end)
    after_each(function()
      os.remove(file)
    end)

    it('work', function()
      command(('%s %s'):format(filecmd, file))
      -- Second line of each entry (i.e. `nr=-1, …`) was obtained from actual
      -- results. First line (i.e. `{lnum=…`) was obtained from legacy test.
      local list = {
        {lnum=700, col=10, text='Line 700', module='',
         nr=-1, bufnr=2, valid=1, pattern='', vcol=0, ['type']=''},
        {lnum=800, col=15, text='Line 800', module='',
         nr=-1, bufnr=3, valid=1, pattern='', vcol=0, ['type']=''},
      }
      eq(list, getlist())
      eq(('%s-1.res'):format(file), funcs.bufname(list[1].bufnr))
      eq(('%s-2.res'):format(file), funcs.bufname(list[2].bufnr))

      -- Run cfile/lfile from a modified buffer
      command('enew!')
      curbufmeths.set_lines(1, 1, true, {'Quickfix'})
      eq(('Vim(%s):E37: No write since last change (add ! to override)'):format(
          filecmd),
         exc_exec(('%s %s'):format(filecmd, file)))

      write_file(file, ([[
        %s-3.res:900:30:Line 900
      ]]):format(file))
      command(('%s %s'):format(addfcmd, file))
      list[#list + 1] = {
        lnum=900, col=30, text='Line 900', module='',
        nr=-1, bufnr=5, valid=1, pattern='', vcol=0, ['type']='',
      }
      eq(list, getlist())
      eq(('%s-3.res'):format(file), funcs.bufname(list[3].bufnr))

      write_file(file, ([[
        %s-1.res:222:77:Line 222
        %s-2.res:333:88:Line 333
      ]]):format(file, file))
      command('enew!')
      command(('%s %s'):format(getfcmd, file))
      list = {
        {lnum=222, col=77, text='Line 222', module='',
         nr=-1, bufnr=2, valid=1, pattern='', vcol=0, ['type']=''},
        {lnum=333, col=88, text='Line 333', module='',
         nr=-1, bufnr=3, valid=1, pattern='', vcol=0, ['type']=''},
      }
      eq(list, getlist())
      eq(('%s-1.res'):format(file), funcs.bufname(list[1].bufnr))
      eq(('%s-2.res'):format(file), funcs.bufname(list[2].bufnr))
    end)
  end)
end

describe('quickfix', function()
  it('location-list update on buffer modification', function()
    source([[
        new
        setl bt=nofile
        let lines = ['Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5']
        call append(0, lines)
        new
        setl bt=nofile
        call append(0, lines)
        let qf_item = {
          \ 'lnum': 4,
          \ 'text': "This is the error line.",
          \ }
        let qf_item['bufnr'] = bufnr('%')
        call setloclist(0, [qf_item])
        wincmd p
        let qf_item['bufnr'] = bufnr('%')
        call setloclist(0, [qf_item])
        1del _
        call append(0, ['New line 1', 'New line 2', 'New line 3'])
        silent ll
    ]])
    eq({0, 6, 1, 0, 1}, funcs.getcurpos())
  end)
end)
