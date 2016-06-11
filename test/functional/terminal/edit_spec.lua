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
    scr:attach(false)
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

  it('runs TermOpen early enough to respect terminal_scrollback_buffer_size', function()
    local columns, lines = 20, 4
    local scr = get_screen(columns, lines)
    local rep = 'a'
    meths.set_option('shellcmdflag', 'REP ' .. rep)
    local rep_size = rep:byte()
    local sb = 10
    local gsb = 20
    meths.set_var('terminal_scrollback_buffer_size', gsb)
    command('autocmd TermOpen * :let b:terminal_scrollback_buffer_size = '
            .. tostring(sb))
    command('edit term://foobar')
    local bufcontents = {}
    local winheight = curwinmeths.get_height()
    -- I have no idea why there is + 4 needed. But otherwise it works fine with 
    -- different scrollbacks.
    local shift = -4
    local buf_cont_start = rep_size - 1 - sb - winheight - shift
    local bufline = function(i) return ('%d: foobar'):format(i) end
    for i = buf_cont_start,(rep_size - 1) do
      bufcontents[#bufcontents + 1] = bufline(i)
    end
    bufcontents[#bufcontents + 1] = ''
    bufcontents[#bufcontents + 1] = '[Process exited 0]'
    -- Do not ask me why displayed screen is one line *before* buffer
    -- contents: buffer starts with 87:, screen with 86:.
    local exp_screen = '\n'
    local did_cursor = false
    for i = 0,(winheight - 1) do
      local line = bufline(buf_cont_start + i - 1)
      exp_screen = (exp_screen
                    .. (did_cursor and '' or '^')
                    .. line
                    .. (' '):rep(columns - #line)
                    .. '|\n')
      did_cursor = true
    end
    exp_screen = exp_screen .. (' '):rep(columns) .. '|\n'
    scr:expect(exp_screen)
    eq(bufcontents, curbufmeths.get_lines(1, -1, true))
  end)
end)
