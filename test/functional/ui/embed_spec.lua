local uv = require'luv'

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local thelpers = require('test.functional.terminal.helpers')

local feed = helpers.feed
local eq = helpers.eq
local clear = helpers.clear
local ok = helpers.ok


local function test_embed(ext_linegrid)
  local screen
  local function startup(...)
    clear{args_rm={'--headless'}, args={...}}

    -- attach immediately after startup, for early UI
    screen = Screen.new(60, 8)
    screen:attach{ext_linegrid=ext_linegrid}
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [2] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [3] = {bold = true, foreground = Screen.colors.Blue1},
      [4] = {bold = true, foreground = Screen.colors.Green},
      [5] = {bold = true, reverse = true},
    })
  end

  it('can display errors', function()
    startup('--cmd', 'echoerr invalid+')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      E121: Undefined variable: invalid                           |
      Press ENTER or type command to continue^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)

  it("doesn't erase output when setting color scheme", function()
    if helpers.is_os('openbsd') then
      pending('FIXME #10804')
    end
    startup('--cmd', 'echoerr "foo"', '--cmd', 'color default', '--cmd', 'echoerr "bar"')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
      {5:                                                            }|
      Error detected while processing pre-vimrc command line:     |
      foo                                                         |
      {1:bar}                                                         |
      {4:Press ENTER or type command to continue}^                     |
    ]])
  end)

  it("doesn't erase output when setting Normal colors", function()
    startup('--cmd', 'echoerr "foo"', '--cmd', 'hi Normal guibg=Green', '--cmd', 'echoerr "bar"')
    screen:expect{grid=[[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      foo                                                         |
      bar                                                         |
      Press ENTER or type command to continue^                     |
    ]], condition=function()
      eq(Screen.colors.Green, screen.default_colors.rgb_bg)
    end}
  end)
end

describe('--embed UI on startup (ext_linegrid=true)', function() test_embed(true) end)
describe('--embed UI on startup (ext_linegrid=false)', function() test_embed(false) end)

describe('--embed UI', function()
  it('can pass stdin', function()
    local pipe = assert(uv.pipe())

    local writer = assert(uv.new_pipe(false))
    writer:open(pipe.write)

    clear {args_rm={'--headless'}, io_extra=pipe.read}

    -- attach immediately after startup, for early UI
    local screen = Screen.new(40, 8)
    screen.rpc_async = true  -- Avoid hanging. #24888
    screen:attach {stdin_fd=3}
    screen:set_default_attr_ids {
      [1] = {bold = true, foreground = Screen.colors.Blue1};
      [2] = {bold = true};
    }

    writer:write "hello nvim\nfrom external input\n"
    writer:shutdown(function() writer:close() end)

    screen:expect{grid=[[
      ^hello nvim                              |
      from external input                     |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}

    -- stdin (rpc input) still works
    feed 'o'
    screen:expect{grid=[[
      hello nvim                              |
      ^                                        |
      from external input                     |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]]}
  end)
end)

describe('--embed --listen UI', function()
  it('waits for connection on listening address', function()
    helpers.skip(helpers.is_os('win'))
    clear()
    local child_server = assert(helpers.new_pipename())

    local screen = thelpers.screen_setup(0,
      string.format(
        [=[["%s", "--embed", "--listen", "%s", "-u", "NONE", "-i", "NONE", "--cmd", "%s"]]=],
        helpers.nvim_prog, child_server, helpers.nvim_set))
    screen:expect{grid=[[
      {1: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    local child_session = helpers.connect(child_server)

    local info_ok, api_info = child_session:request('nvim_get_api_info')
    ok(info_ok)
    eq(2, #api_info)
    ok(api_info[1] > 2, 'channel_id > 2', api_info[1])

    child_session:request('nvim_exec2', [[
      let g:evs = []
      autocmd UIEnter * call add(g:evs, $"UIEnter:{v:event.chan}")
      autocmd VimEnter * call add(g:evs, "VimEnter")
    ]], {})

    -- VimEnter and UIEnter shouldn't be triggered until after attach
    local var_ok, var = child_session:request('nvim_get_var', 'evs')
    ok(var_ok)
    eq({}, var)

    local child_screen = Screen.new(40, 6)
    child_screen:attach(nil, child_session)
    child_screen:expect{grid=[[
      ^                                        |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]], attr_ids={
      [1] = {foreground = Screen.colors.Blue, bold = true};
    }}

    -- VimEnter and UIEnter should now be triggered
    var_ok, var = child_session:request('nvim_get_var', 'evs')
    ok(var_ok)
    eq({'VimEnter', ('UIEnter:%d'):format(api_info[1])}, var)
  end)
end)
