local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local lfs = require('lfs')
local neq, eq, command = helpers.neq, helpers.eq, helpers.command
local clear, curbufmeths = helpers.clear, helpers.curbufmeths
local exc_exec, expect, eval = helpers.exc_exec, helpers.expect, helpers.eval
local insert = helpers.insert

describe('api functions', function()
  before_each(clear)

  it("work", function()
    command("call nvim_command('let g:test = 1')")
    eq(1, eval("nvim_get_var('test')"))

    local buf = eval("nvim_get_current_buf()")
    command("call nvim_buf_set_lines("..buf..", 0, -1, v:true, ['aa', 'bb'])")
    expect([[
      aa
      bb]])

    command("call nvim_win_set_cursor(0, [1, 1])")
    command("call nvim_input('ax<esc>')")
    expect([[
      aax
      bb]])
  end)

  it("throw errors for invalid arguments", function()
    local err = exc_exec('call nvim_get_current_buf("foo")')
    eq('Vim(call):E118: Too many arguments for function: nvim_get_current_buf', err)

    err = exc_exec('call nvim_set_option("hlsearch")')
    eq('Vim(call):E119: Not enough arguments for function: nvim_set_option', err)

    err = exc_exec('call nvim_buf_set_lines(1, 0, -1, [], ["list"])')
    eq('Vim(call):Wrong type for argument 4, expecting Boolean', err)

    err = exc_exec('call nvim_buf_set_lines(0, 0, -1, v:true, "string")')
    eq('Vim(call):Wrong type for argument 5, expecting ArrayOf(String)', err)

    err = exc_exec('call nvim_buf_get_number("0")')
    eq('Vim(call):Wrong type for argument 1, expecting Buffer', err)

    err = exc_exec('call nvim_buf_line_count(17)')
    eq('Vim(call):Invalid buffer id', err)
  end)


  it("use buffer numbers and windows ids as handles", function()
    local screen = Screen.new(40, 8)
    screen:attach()
    local bnr = eval("bufnr('')")
    local bhnd = eval("nvim_get_current_buf()")
    local wid = eval("win_getid()")
    local whnd = eval("nvim_get_current_win()")
    eq(bnr, bhnd)
    eq(wid, whnd)

    command("new") -- creates new buffer and new window
    local bnr2 = eval("bufnr('')")
    local bhnd2 = eval("nvim_get_current_buf()")
    local wid2 = eval("win_getid()")
    local whnd2 = eval("nvim_get_current_win()")
    eq(bnr2, bhnd2)
    eq(wid2, whnd2)
    neq(bnr, bnr2)
    neq(wid, wid2)
    -- 0 is synonymous to the current buffer
    eq(bnr2, eval("nvim_buf_get_number(0)"))

    command("bn") -- show old buffer in new window
    eq(bnr, eval("nvim_get_current_buf()"))
    eq(bnr, eval("bufnr('')"))
    eq(bnr, eval("nvim_buf_get_number(0)"))
    eq(wid2, eval("win_getid()"))
    eq(whnd2, eval("nvim_get_current_win()"))
  end)

  it("get_lines and set_lines use NL to represent NUL", function()
    curbufmeths.set_lines(0, -1, true, {"aa\0", "b\0b"})
    eq({'aa\n', 'b\nb'}, eval("nvim_buf_get_lines(0, 0, -1, 1)"))

    command('call nvim_buf_set_lines(0, 1, 2, v:true, ["xx", "\\nyy"])')
    eq({'aa\0', 'xx', '\0yy'}, curbufmeths.get_lines(0, -1, 1))
  end)

  it("that are FUNC_ATTR_NOEVAL cannot be called", function()
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
    err = exc_exec('call nvim_subscribe("fancyevent")')
    eq('Vim(call):E117: Unknown function: nvim_subscribe', err)
  end)

  it('have metadata accessible with api_info()', function()
    local api_keys = eval("sort(keys(api_info()))")
    eq({'error_types', 'functions', 'types',
        'ui_events', 'ui_options', 'version'}, api_keys)
  end)

  it('are highlighted by vim.vim syntax file', function()
    if lfs.attributes("build/runtime/syntax/vim/generated.vim",'uid') == nil then
      pending("runtime was not built, skipping test")
      return
    end
    local screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Brown},
      [2] = {foreground = Screen.colors.DarkCyan},
      [3] = {foreground = Screen.colors.SlateBlue},
      [4] = {foreground = Screen.colors.Fuchsia},
      [5] = {bold = true, foreground = Screen.colors.Blue},
    })

    command("set ft=vim")
    command("let &rtp='build/runtime/,'.&rtp")
    command("syntax on")
    insert([[
      call bufnr('%')
      call nvim_input('typing...')
      call not_a_function(42)]])

    screen:expect([[
      {1:call} {2:bufnr}{3:(}{4:'%'}{3:)}                         |
      {1:call} {2:nvim_input}{3:(}{4:'typing...'}{3:)}            |
      {1:call} not_a_function{3:(}{4:42}{3:^)}                 |
      {5:~                                       }|
      {5:~                                       }|
      {5:~                                       }|
      {5:~                                       }|
                                              |
    ]])
    screen:detach()
  end)
end)
