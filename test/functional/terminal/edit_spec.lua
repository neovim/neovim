local t = require('test.functional.testutil')()
local screen = require('test.functional.ui.screen')

local testprg = t.testprg
local command = t.command
local fn = t.fn
local api = t.api
local clear = t.clear
local eq = t.eq
local matches = t.matches
local pesc = vim.pesc

describe(':edit term://*', function()
  local get_screen = function(columns, lines)
    local scr = screen.new(columns, lines)
    scr:attach({ rgb = false })
    return scr
  end

  before_each(function()
    clear()
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    api.nvim_set_option_value('shellcmdflag', 'EXE', {})
  end)

  it('runs TermOpen event', function()
    api.nvim_set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    local termopen_runs = api.nvim_get_var('termopen_runs')
    eq(1, #termopen_runs)
    local cwd = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    matches('^term://' .. pesc(cwd) .. '//%d+:$', termopen_runs[1])
  end)

  it("runs TermOpen early enough to set buffer-local 'scrollback'", function()
    local columns, lines = 20, 4
    local scr = get_screen(columns, lines)
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
end)
