local helpers = require('test.functional.helpers')(after_each)
local screen = require('test.functional.ui.screen')

local curbufmeths = helpers.curbufmeths
local curwinmeths = helpers.curwinmeths
local nvim_dir = helpers.nvim_dir
local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq

describe(':edit term://*', function()
  local get_screen = function(columns, lines)
    local scr = screen.new(columns, lines)
    scr:attach({rgb=false})
    return scr
  end

  before_each(function()
    clear()
    meths.set_option('shell', nvim_dir .. '/shell-test')
    meths.set_option('shellcmdflag', 'EXE')
  end)

  it('runs TermOpen event', function()
    meths.set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    local termopen_runs = meths.get_var('termopen_runs')
    eq(1, #termopen_runs)
    eq(termopen_runs[1], termopen_runs[1]:match('^term://.//%d+:$'))
  end)

  it("runs TermOpen early enough to set buffer-local 'scrollback'", function()
    local columns, lines = 20, 4
    local scr = get_screen(columns, lines)
    local rep = 97
    meths.set_option('shellcmdflag', 'REP ' .. rep)
    command('set shellxquote=')  -- win: avoid extra quotes
    local sb = 10
    command('autocmd TermOpen * :setlocal scrollback='..tostring(sb)
            ..'|call feedkeys("G", "n")')
    command('edit term://foobar')

    local bufcontents = {}
    local winheight = curwinmeths.get_height()
    local buf_cont_start = rep - sb - winheight + 2
    for i = buf_cont_start,(rep - 1) do
      bufcontents[#bufcontents + 1] = ('%d: foobar'):format(i)
    end
    bufcontents[#bufcontents + 1] = ''
    bufcontents[#bufcontents + 1] = '[Process exited 0]'

    local exp_screen = '\n'
    for i = 1,(winheight - 1) do
      local line = bufcontents[#bufcontents - winheight + i]
      exp_screen = (exp_screen
                    .. line
                    .. (' '):rep(columns - #line)
                    .. '|\n')
    end
    exp_screen = exp_screen..'^[Process exited 0]  |\n'

    exp_screen = exp_screen..(' '):rep(columns)..'|\n'
    scr:expect(exp_screen)
    eq(bufcontents, curbufmeths.get_lines(0, -1, true))
  end)
end)
