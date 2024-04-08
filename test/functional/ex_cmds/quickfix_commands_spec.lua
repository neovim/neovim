local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = t.feed
local eq = t.eq
local clear = t.clear
local fn = t.fn
local command = t.command
local exc_exec = t.exc_exec
local write_file = t.write_file
local api = t.api
local source = t.source

local file_base = 'Xtest-functional-ex_cmds-quickfix_commands'

before_each(clear)

for _, c in ipairs({ 'l', 'c' }) do
  local file = ('%s.%s'):format(file_base, c)
  local filecmd = c .. 'file'
  local getfcmd = c .. 'getfile'
  local addfcmd = c .. 'addfile'
  local getlist = (c == 'c') and fn.getqflist or function()
    return fn.getloclist(0)
  end

  describe((':%s*file commands'):format(c), function()
    before_each(function()
      write_file(
        file,
        ([[
        %s-1.res:700:10:Line 700
        %s-2.res:800:15:Line 800
      ]]):format(file, file)
      )
    end)
    after_each(function()
      os.remove(file)
    end)

    it('work', function()
      command(('%s %s'):format(filecmd, file))
      -- Second line of each entry (i.e. `nr=-1, …`) was obtained from actual
      -- results. First line (i.e. `{lnum=…`) was obtained from legacy test.
      local list = {
        {
          lnum = 700,
          end_lnum = 0,
          col = 10,
          end_col = 0,
          text = 'Line 700',
          module = '',
          nr = -1,
          bufnr = 2,
          valid = 1,
          pattern = '',
          vcol = 0,
          ['type'] = '',
        },
        {
          lnum = 800,
          end_lnum = 0,
          col = 15,
          end_col = 0,
          text = 'Line 800',
          module = '',
          nr = -1,
          bufnr = 3,
          valid = 1,
          pattern = '',
          vcol = 0,
          ['type'] = '',
        },
      }
      eq(list, getlist())
      eq(('%s-1.res'):format(file), fn.bufname(list[1].bufnr))
      eq(('%s-2.res'):format(file), fn.bufname(list[2].bufnr))

      -- Run cfile/lfile from a modified buffer
      command('set nohidden')
      command('enew!')
      api.nvim_buf_set_lines(0, 1, 1, true, { 'Quickfix' })
      eq(
        ('Vim(%s):E37: No write since last change (add ! to override)'):format(filecmd),
        exc_exec(('%s %s'):format(filecmd, file))
      )

      write_file(
        file,
        ([[
        %s-3.res:900:30:Line 900
      ]]):format(file)
      )
      command(('%s %s'):format(addfcmd, file))
      list[#list + 1] = {
        lnum = 900,
        end_lnum = 0,
        col = 30,
        end_col = 0,
        text = 'Line 900',
        module = '',
        nr = -1,
        bufnr = 5,
        valid = 1,
        pattern = '',
        vcol = 0,
        ['type'] = '',
      }
      eq(list, getlist())
      eq(('%s-3.res'):format(file), fn.bufname(list[3].bufnr))

      write_file(
        file,
        ([[
        %s-1.res:222:77:Line 222
        %s-2.res:333:88:Line 333
      ]]):format(file, file)
      )
      command('enew!')
      command(('%s %s'):format(getfcmd, file))
      list = {
        {
          lnum = 222,
          end_lnum = 0,
          col = 77,
          end_col = 0,
          text = 'Line 222',
          module = '',
          nr = -1,
          bufnr = 2,
          valid = 1,
          pattern = '',
          vcol = 0,
          ['type'] = '',
        },
        {
          lnum = 333,
          end_lnum = 0,
          col = 88,
          end_col = 0,
          text = 'Line 333',
          module = '',
          nr = -1,
          bufnr = 3,
          valid = 1,
          pattern = '',
          vcol = 0,
          ['type'] = '',
        },
      }
      eq(list, getlist())
      eq(('%s-1.res'):format(file), fn.bufname(list[1].bufnr))
      eq(('%s-2.res'):format(file), fn.bufname(list[2].bufnr))
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
    eq({ 0, 6, 1, 0, 1 }, fn.getcurpos())
  end)

  it('BufAdd does not cause E16 when reusing quickfix buffer #18135', function()
    local file = file_base .. '_reuse_qfbuf_BufAdd'
    write_file(file, ('\n'):rep(100) .. 'foo')
    source([[
      set grepprg=internal
      autocmd BufAdd * call and(0, 0)
      autocmd QuickFixCmdPost grep ++nested cclose | cwindow
    ]])
    command('grep foo ' .. file)
    command('grep foo ' .. file)
    os.remove(file)
  end)
end)

it(':vimgrep can specify Unicode pattern without delimiters', function()
  eq(
    'Vim(vimgrep):E480: No match: →',
    exc_exec('vimgrep → test/functional/fixtures/tty-test.c')
  )
  local screen = Screen.new(40, 6)
  screen:set_default_attr_ids({
    [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [1] = { reverse = true }, -- IncSearch
  })
  screen:attach()
  feed('i→<Esc>:vimgrep →')
  screen:expect([[
    {1:→}                                       |
    {0:~                                       }|*4
    :vimgrep →^                              |
  ]])
end)
