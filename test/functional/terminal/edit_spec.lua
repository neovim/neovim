local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local testprg = n.testprg
local command = n.command
local fn = n.fn
local api = n.api
local clear = n.clear
local eq = t.eq
local matches = t.matches
local pesc = vim.pesc

describe(':edit term://*', function()
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
    local cwd = fn.fnamemodify('.', ':p:~'):gsub([[/*$]], '')
    matches('^term://' .. pesc(cwd) .. '//%d+:$', termopen_runs[1])
  end)

  it("runs TermOpen early enough to set buffer-local 'scrollback'", function()
    local columns, lines = 20, 4
    local scr = Screen.new(columns, lines, { rgb = false })
    -- Enough output for Ghostty to prune whole scrollback pages with the TermOpen limit, but not
    -- with the default one.
    local rep = 5000
    api.nvim_set_option_value('shellcmdflag', 'REP ' .. rep, {})
    command('set shellxquote=') -- win: avoid extra quotes
    local sb = 10
    command(
      'autocmd TermOpen * :setlocal scrollback=' .. tostring(sb) .. '|call feedkeys("G", "n")'
    )
    command('edit term://foobar')

    local bufcontents = {}
    local winheight = api.nvim_win_get_height(0)
    for i = 0, (rep - 1) do
      bufcontents[#bufcontents + 1] = ('%d: foobar'):format(i)
    end
    bufcontents[#bufcontents + 1] = ''

    local exp_screen = '\n'
    for i = 1, (winheight - 1) do
      local line = bufcontents[#bufcontents - winheight + i]
      exp_screen = (exp_screen .. line .. (' '):rep(columns - #line) .. '|\n')
    end
    exp_screen = exp_screen .. '^[Process exited 0]  |\n'

    exp_screen = exp_screen .. (' '):rep(columns) .. '|\n'
    scr:expect(exp_screen)
    eq(sb, api.nvim_get_option_value('scrollback', { buf = 0 }))
    local lines = api.nvim_buf_get_lines(0, 0, -1, true)
    if t.is_os('win') then
      -- ConPTY may pad lines with spaces.
      lines = vim.tbl_map(function(line)
        return (line:gsub(' +$', ''))
      end, lines)
    end
    eq(true, #lines < rep)
    eq(vim.list_slice(bufcontents, #bufcontents - #lines + 1), lines)
  end)
end)
