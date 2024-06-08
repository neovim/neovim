local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local neq, eq, command = t.neq, t.eq, n.command
local clear = n.clear
local exc_exec, expect, eval = n.exc_exec, n.expect, n.eval
local exec_lua = n.exec_lua
local insert, pcall_err = n.insert, t.pcall_err
local matches = t.matches
local api = n.api
local feed = n.feed

describe('eval-API', function()
  before_each(clear)

  it('work', function()
    command("call nvim_command('let g:test = 1')")
    eq(1, eval("nvim_get_var('test')"))

    local buf = eval('nvim_get_current_buf()')
    command('call nvim_buf_set_lines(' .. buf .. ", 0, -1, v:true, ['aa', 'bb'])")
    expect([[
      aa
      bb]])

    command('call nvim_win_set_cursor(0, [1, 1])')
    command("call nvim_input('ax<esc>')")
    expect([[
      aax
      bb]])
  end)

  it('throw errors for invalid arguments', function()
    local err = exc_exec('call nvim_get_current_buf("foo")')
    eq('Vim(call):E118: Too many arguments for function: nvim_get_current_buf', err)

    err = exc_exec('call nvim_set_option_value("hlsearch")')
    eq('Vim(call):E119: Not enough arguments for function: nvim_set_option_value', err)

    err = exc_exec('call nvim_buf_set_lines(1, 0, -1, [], ["list"])')
    eq(
      'Vim(call):E5555: API call: Wrong type for argument 4 when calling nvim_buf_set_lines, expecting Boolean',
      err
    )

    err = exc_exec('call nvim_buf_set_lines(0, 0, -1, v:true, "string")')
    eq(
      'Vim(call):E5555: API call: Wrong type for argument 5 when calling nvim_buf_set_lines, expecting ArrayOf(String)',
      err
    )

    err = exc_exec('call nvim_buf_get_number("0")')
    eq(
      'Vim(call):E5555: API call: Wrong type for argument 1 when calling nvim_buf_get_number, expecting Buffer',
      err
    )

    err = exc_exec('call nvim_buf_line_count(17)')
    eq('Vim(call):E5555: API call: Invalid buffer id: 17', err)
  end)

  it('cannot change text or window if textlocked', function()
    command('autocmd TextYankPost <buffer> ++once call nvim_buf_set_lines(0, 0, -1, v:false, [])')
    matches(
      'Vim%(call%):E5555: API call: E565: Not allowed to change text or change window$',
      pcall_err(command, 'normal! yy')
    )

    command('autocmd TextYankPost <buffer> ++once call nvim_open_term(0, {})')
    matches(
      'Vim%(call%):E5555: API call: E565: Not allowed to change text or change window$',
      pcall_err(command, 'normal! yy')
    )

    -- Functions checking textlock should also not be usable from <expr> mappings.
    command('inoremap <expr> <f2> nvim_win_close(0, 1)')
    eq(
      'Vim(normal):E5555: API call: E565: Not allowed to change text or change window',
      pcall_err(command, [[execute "normal i\<f2>"]])
    )

    -- Text-changing functions gave a "Failed to save undo information" error when called from an
    -- <expr> mapping outside do_cmdline() (msg_list == NULL), so use feed() to test this.
    command("inoremap <expr> <f2> nvim_buf_set_text(0, 0, 0, 0, 0, ['hi'])")
    api.nvim_set_vvar('errmsg', '')
    feed('i<f2><esc>')
    eq(
      'E5555: API call: E565: Not allowed to change text or change window',
      api.nvim_get_vvar('errmsg')
    )

    -- Some functions checking textlock (usually those that may change the current window or buffer)
    -- also ought to not be usable in the cmdwin.
    local old_win = api.nvim_get_current_win()
    feed('q:')
    eq(
      'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
      pcall_err(api.nvim_set_current_win, old_win)
    )

    -- But others, like nvim_buf_set_lines(), which just changes text, is OK.
    api.nvim_buf_set_lines(0, 0, -1, 1, { 'wow!' })
    eq({ 'wow!' }, api.nvim_buf_get_lines(0, 0, -1, 1))

    -- Turning the cmdwin buffer into a terminal buffer would be pretty weird.
    eq(
      'E11: Invalid in command-line window; <CR> executes, CTRL-C quits',
      pcall_err(api.nvim_open_term, 0, {})
    )

    matches(
      'E11: Invalid in command%-line window; <CR> executes, CTRL%-C quits$',
      pcall_err(
        exec_lua,
        [[
         local cmdwin_buf = vim.api.nvim_get_current_buf()
         vim._with({buf = vim.api.nvim_create_buf(false, true)}, function()
           vim.api.nvim_open_term(cmdwin_buf, {})
         end)
       ]]
      )
    )

    -- But turning a different buffer into a terminal from the cmdwin is OK.
    local term_buf = api.nvim_create_buf(false, true)
    api.nvim_open_term(term_buf, {})
    eq('terminal', api.nvim_get_option_value('buftype', { buf = term_buf }))
  end)

  it('use buffer numbers and windows ids as handles', function()
    local screen = Screen.new(40, 8)
    screen:attach()
    local bnr = eval("bufnr('')")
    local bhnd = eval('nvim_get_current_buf()')
    local wid = eval('win_getid()')
    local whnd = eval('nvim_get_current_win()')
    eq(bnr, bhnd)
    eq(wid, whnd)

    command('new') -- creates new buffer and new window
    local bnr2 = eval("bufnr('')")
    local bhnd2 = eval('nvim_get_current_buf()')
    local wid2 = eval('win_getid()')
    local whnd2 = eval('nvim_get_current_win()')
    eq(bnr2, bhnd2)
    eq(wid2, whnd2)
    neq(bnr, bnr2)
    neq(wid, wid2)
    -- 0 is synonymous to the current buffer
    eq(bnr2, eval('nvim_buf_get_number(0)'))

    command('bn') -- show old buffer in new window
    eq(bnr, eval('nvim_get_current_buf()'))
    eq(bnr, eval("bufnr('')"))
    eq(bnr, eval('nvim_buf_get_number(0)'))
    eq(wid2, eval('win_getid()'))
    eq(whnd2, eval('nvim_get_current_win()'))
  end)

  it('get_lines and set_lines use NL to represent NUL', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aa\0', 'b\0b' })
    eq({ 'aa\n', 'b\nb' }, eval('nvim_buf_get_lines(0, 0, -1, 1)'))

    command('call nvim_buf_set_lines(0, 1, 2, v:true, ["xx", "\\nyy"])')
    eq({ 'aa\0', 'xx', '\0yy' }, api.nvim_buf_get_lines(0, 0, -1, 1))
  end)

  it('that are FUNC_ATTR_NOEVAL cannot be called', function()
    -- Deprecated vim_ prefix is not exported.
    local err = exc_exec('call vim_get_current_buffer("foo")')
    eq('Vim(call):E117: Unknown function: vim_get_current_buffer', err)

    -- Deprecated buffer_ prefix is not exported.
    err = exc_exec('call buffer_line_count(0)')
    eq('Vim(call):E117: Unknown function: buffer_line_count', err)

    -- Functions deprecated before the api functions became available
    -- in vimscript are not exported.
    err = exc_exec('call buffer_get_line(0, 1)')
    eq('Vim(call):E117: Unknown function: buffer_get_line', err)

    -- some api functions are only useful from a msgpack-rpc channel
    err = exc_exec('call nvim_set_client_info()')
    eq('Vim(call):E117: Unknown function: nvim_set_client_info', err)
  end)

  it('have metadata accessible with api_info()', function()
    local api_keys = eval('sort(keys(api_info()))')
    eq({ 'error_types', 'functions', 'types', 'ui_events', 'ui_options', 'version' }, api_keys)
  end)

  it('are highlighted by vim.vim syntax file', function()
    local screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Brown },
      [2] = { foreground = Screen.colors.DarkCyan },
      [3] = { foreground = Screen.colors.SlateBlue },
      [4] = { foreground = Screen.colors.Fuchsia },
      [5] = { bold = true, foreground = Screen.colors.Blue },
    })

    command('set ft=vim')
    command('set rtp^=build/runtime/')
    command('syntax on')
    insert([[
      call bufnr('%')
      call nvim_input('typing...')
      call not_a_function(42)]])

    screen:expect([[
      {1:call} {2:bufnr}{3:(}{4:'%'}{3:)}                         |
      {1:call} {2:nvim_input}{3:(}{4:'typing...'}{3:)}            |
      {1:call} not_a_function{3:(}{4:42}{3:^)}                 |
      {5:~                                       }|*4
                                              |
    ]])
  end)

  it('cannot be called from sandbox', function()
    eq(
      'Vim(call):E48: Not allowed in sandbox',
      pcall_err(command, "sandbox call nvim_input('ievil')")
    )
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('converts blobs to API strings', function()
    command('let g:v1 = nvim__id(0z68656c6c6f)')
    command('let g:v2 = nvim__id(v:_null_blob)')
    eq(1, eval('type(g:v1)'))
    eq(1, eval('type(g:v2)'))
    eq('hello', eval('g:v1'))
    eq('', eval('g:v2'))
  end)
end)
