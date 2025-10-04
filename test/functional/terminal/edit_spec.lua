local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local Screen = require('test.functional.ui.screen')

local testprg = n.testprg
local command = n.command
local fn = n.fn
local api = n.api
local clear = n.clear
local eq = t.eq
local matches = t.matches
local pesc = vim.pesc

before_each(function()
  clear()
  api.nvim_set_option_value('shell', testprg('shell-test'), {})
  api.nvim_set_option_value('shellcmdflag', 'EXE', {})
end)

describe(':edit term://*', function()
  it('runs TermOpen event', function()
    api.nvim_set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    local termopen_runs = api.nvim_get_var('termopen_runs')
    eq(1, #termopen_runs)
    local cwd = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    matches(
      '^term://' .. pesc(cwd) .. [[//%d+:%[".*shell%-test.?e?x?e?", "EXE", "\?"?\?"?"%]$]],
      termopen_runs[1]
    )
  end)

  it("runs TermOpen early enough to set buffer-local 'scrollback'", function()
    local columns, lines = 20, 4
    local scr = Screen.new(columns, lines, { rgb = false })
    local rep = 97
    api.nvim_set_option_value('shellcmdflag', 'REP ' .. rep, {})
    command('set shellxquote=') -- win: avoid extra quotes
    local sb = 10
    command(
      'autocmd TermOpen * :setlocal scrollback=' .. tostring(sb) .. '|call feedkeys("G", "n")'
    )
    command('edit term://foobar')

    local bufcontents = {}
    local winheight = api.nvim_win_get_height(0)
    local buf_cont_start = rep - sb - winheight + 2
    for i = buf_cont_start, (rep - 1) do
      bufcontents[#bufcontents + 1] = ('%d: foobar'):format(i)
    end
    bufcontents[#bufcontents + 1] = ''
    bufcontents[#bufcontents + 1] = '[Process exited 0]'

    local exp_screen = '\n'
    for i = 1, (winheight - 1) do
      local line = bufcontents[#bufcontents - winheight + i]
      exp_screen = (exp_screen .. line .. (' '):rep(columns - #line) .. '|\n')
    end
    exp_screen = exp_screen .. '^[Process exited 0]  |\n'

    exp_screen = exp_screen .. (' '):rep(columns) .. '|\n'
    scr:expect(exp_screen)
    eq(bufcontents, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('handles truncated command JSON', function()
    -- jobstart(term=true) will truncate very long commands.
    -- The term://* BufReadCmd handler should not attempt to execute them.
    matches(
      'Command was truncated',
      t.pcall_err(n.command, 'edit ' .. fn.fnameescape([=[term://["ls", "..."] ]=]))
    )
  end)
end)

describe('jobstart(term=true)', function()
  it('sets full command as JSON array in term://… name', function()
    fn.jobstart({ testprg('shell-test'), 'arg1', 'arg2 with spaces' }, { term = true })
    -- Should look like: `term:///cwd//PID:["/path/to/shell-test", "arg1", "arg2"]`
    matches(
      [[^term://.*/%d+:%[".*/shell%-test%.?e?x?e?", "arg1", "arg2 with spaces"%]$]],
      fn.bufname('%')
    )

    command('enew!')
    -- Try a command with complex quoted args.
    fn.jobstart({ testprg('shell-test'), 'arg1', [[["arg 2"] "with" 'quotes']] }, { term = true })
    matches(
      [[^term://.*/%d+:%[".*/shell%-test%.?e?x?e?", "arg1", "%[\"arg 2\"%] \"with\" 'quotes'"%]$]],
      fn.bufname('%')
    )
  end)

  it('truncates term://… command JSON if too long', function()
    local long_arg = string.rep('x', 600)
    fn.jobstart({ testprg('shell-test'), 'arg1', '["arg 2"}', long_arg }, { term = true })
    -- Should look like: `term:///cwd//PID:["/path/to/shell-test", "arg1", "..."]`
    matches(
      [[^term://.*/%d+:%[".*/shell%-test%.?e?x?e?", "arg1", "%[\"arg 2\"}", "%.%.%."%]$]],
      fn.bufname('%')
    )
  end)
end)
