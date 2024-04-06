local uv = vim.uv

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local api = helpers.api
local feed = helpers.feed
local eq = helpers.eq
local neq = helpers.neq
local clear = helpers.clear
local ok = helpers.ok
local fn = helpers.fn
local nvim_prog = helpers.nvim_prog
local retry = helpers.retry
local write_file = helpers.write_file
local assert_log = helpers.assert_log
local check_close = helpers.check_close
local is_os = helpers.is_os

local testlog = 'Xtest-embed-log'

local function test_embed(ext_linegrid)
  local screen
  local function startup(...)
    clear { args_rm = { '--headless' }, args = { ... } }

    -- attach immediately after startup, for early UI
    screen = Screen.new(60, 8)
    screen:attach { ext_linegrid = ext_linegrid }
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [2] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [3] = { bold = true, foreground = Screen.colors.Blue1 },
      [4] = { bold = true, foreground = Screen.colors.Green },
      [5] = { bold = true, reverse = true },
      [6] = { foreground = Screen.colors.NvimLightGrey3, background = Screen.colors.NvimDarkGrey3 },
      [7] = { foreground = Screen.colors.NvimDarkRed },
      [8] = { foreground = Screen.colors.NvimDarkCyan },
    })
  end

  it('can display errors', function()
    startup('--cmd', 'echoerr invalid+')
    screen:expect([[
                                                                  |*4
      {6:                                                            }|
      {7:Error detected while processing pre-vimrc command line:}     |
      {7:E121: Undefined variable: invalid}                           |
      {8:Press ENTER or type command to continue}^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                            |
      {3:~                                                           }|*6
                                                                  |
    ]])
  end)

  it("doesn't erase output when setting color scheme", function()
    if helpers.is_os('openbsd') then
      pending('FIXME #10804')
    end
    startup('--cmd', 'echoerr "foo"', '--cmd', 'color default', '--cmd', 'echoerr "bar"')
    screen:expect([[
                                                                  |*3
      {6:                                                            }|
      {7:Error detected while processing pre-vimrc command line:}     |
      {7:foo}                                                         |
      {7:bar}                                                         |
      {8:Press ENTER or type command to continue}^                     |
    ]])
  end)

  it("doesn't erase output when setting Normal colors", function()
    startup('--cmd', 'echoerr "foo"', '--cmd', 'hi Normal guibg=Green', '--cmd', 'echoerr "bar"')
    screen:expect {
      grid = [[
                                                                  |*3
      {6:                                                            }|
      {7:Error detected while processing pre-vimrc command line:}     |
      {7:foo}                                                         |
      {7:bar}                                                         |
      {8:Press ENTER or type command to continue}^                     |
    ]],
      condition = function()
        eq(Screen.colors.Green, screen.default_colors.rgb_bg)
      end,
    }
  end)
end

describe('--embed UI on startup (ext_linegrid=true)', function()
  test_embed(true)
end)
describe('--embed UI on startup (ext_linegrid=false)', function()
  test_embed(false)
end)

describe('--embed UI', function()
  after_each(function()
    check_close()
    os.remove(testlog)
  end)

  it('can pass stdin', function()
    local pipe = assert(uv.pipe())

    local writer = assert(uv.new_pipe(false))
    writer:open(pipe.write)

    clear { args_rm = { '--headless' }, io_extra = pipe.read, env = { NVIM_LOG_FILE = testlog } }

    -- attach immediately after startup, for early UI
    local screen = Screen.new(40, 8)
    screen.rpc_async = true -- Avoid hanging. #24888
    screen:attach { stdin_fd = 3 }
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true },
    }

    writer:write 'hello nvim\nfrom external input\n'
    writer:shutdown(function()
      writer:close()
    end)

    screen:expect [[
      ^hello nvim                              |
      from external input                     |
      {1:~                                       }|*5
                                              |
    ]]

    -- stdin (rpc input) still works
    feed 'o'
    screen:expect [[
      hello nvim                              |
      ^                                        |
      from external input                     |
      {1:~                                       }|*4
      {2:-- INSERT --}                            |
    ]]

    if not is_os('win') then
      assert_log('Failed to get flags on descriptor 3: Bad file descriptor', testlog)
    end
  end)

  it('can pass stdin to -q - #17523', function()
    write_file(
      'Xbadfile.c',
      [[
      /* some file with an error */
      main() {
        functionCall(arg; arg, arg);
        return 666
      }
      ]]
    )
    finally(function()
      os.remove('Xbadfile.c')
    end)

    local pipe = assert(uv.pipe())

    local writer = assert(uv.new_pipe(false))
    writer:open(pipe.write)

    clear { args_rm = { '--headless' }, args = { '-q', '-' }, io_extra = pipe.read }

    -- attach immediately after startup, for early UI
    local screen = Screen.new(60, 8)
    screen.rpc_async = true -- Avoid hanging. #24888
    screen:attach { stdin_fd = 3 }
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true },
    }

    writer:write [[Xbadfile.c:4:12: error: expected ';' before '}' token]]
    writer:shutdown(function()
      writer:close()
    end)

    screen:expect [[
      /* some file with an error */                               |
      main() {                                                    |
        functionCall(arg; arg, arg);                              |
        return 66^6                                                |
      }                                                           |
      {1:~                                                           }|*2
      (1 of 1): error: expected ';' before '}' token              |
    ]]

    -- stdin (rpc input) still works
    feed 'A'
    screen:expect [[
      /* some file with an error */                               |
      main() {                                                    |
        functionCall(arg; arg, arg);                              |
        return 666^                                                |
      }                                                           |
      {1:~                                                           }|*2
      {2:-- INSERT --}                                                |
    ]]

    eq('-', api.nvim_get_option_value('errorfile', {}))
  end)

  it('only sets background colors once even if overridden', function()
    local screen, current, seen
    local function handle_default_colors_set(_, _, rgb_bg, _, _, _)
      seen[rgb_bg] = true
      current = rgb_bg
    end
    local function startup(...)
      seen = {}
      current = nil
      clear { args_rm = { '--headless' }, args = { ... } }

      -- attach immediately after startup, for early UI
      screen = Screen.new(40, 8)
      screen._handle_default_colors_set = handle_default_colors_set
      screen:attach()
    end

    startup()
    screen:expect {
      condition = function()
        eq(16777215, current)
      end,
    }
    eq({ [16777215] = true }, seen)

    -- NB: by accident how functional/helpers.lua currently handles the default color scheme, the
    -- above is sufficient to test the behavior. But in case that workaround is removed, we need
    -- a test with an explicit override like below, so do it to remain safe.
    startup('--cmd', 'hi NORMAL guibg=#FF00FF')
    screen:expect {
      condition = function()
        eq(16711935, current)
      end,
    }
    eq({ [16711935] = true }, seen) -- we only saw the last one, despite 16777215 was set internally earlier
  end)

  it('updates cwd of attached UI #21771', function()
    clear { args_rm = { '--headless' } }

    local screen = Screen.new(40, 8)
    screen:attach()

    screen:expect {
      condition = function()
        eq(helpers.paths.test_source_path, screen.pwd)
      end,
    }

    -- Change global cwd
    helpers.command(string.format('cd %s/src/nvim', helpers.paths.test_source_path))

    screen:expect {
      condition = function()
        eq(string.format('%s/src/nvim', helpers.paths.test_source_path), screen.pwd)
      end,
    }

    -- Split the window and change the cwd in the split
    helpers.command('new')
    helpers.command(string.format('lcd %s/test', helpers.paths.test_source_path))

    screen:expect {
      condition = function()
        eq(string.format('%s/test', helpers.paths.test_source_path), screen.pwd)
      end,
    }

    -- Move to the original window
    helpers.command('wincmd p')

    screen:expect {
      condition = function()
        eq(string.format('%s/src/nvim', helpers.paths.test_source_path), screen.pwd)
      end,
    }

    -- Change global cwd again
    helpers.command(string.format('cd %s', helpers.paths.test_source_path))

    screen:expect {
      condition = function()
        eq(helpers.paths.test_source_path, screen.pwd)
      end,
    }
  end)
end)

describe('--embed --listen UI', function()
  it('waits for connection on listening address', function()
    helpers.skip(helpers.is_os('win'))
    clear()
    local child_server = assert(helpers.new_pipename())
    fn.jobstart({
      nvim_prog,
      '--embed',
      '--listen',
      child_server,
      '--clean',
      '--cmd',
      'colorscheme vim',
    })
    retry(nil, nil, function()
      neq(nil, uv.fs_stat(child_server))
    end)

    local child_session = helpers.connect(child_server)

    local info_ok, api_info = child_session:request('nvim_get_api_info')
    ok(info_ok)
    eq(2, #api_info)
    ok(api_info[1] > 2, 'channel_id > 2', api_info[1])

    child_session:request(
      'nvim_exec2',
      [[
      let g:evs = []
      autocmd UIEnter * call add(g:evs, $"UIEnter:{v:event.chan}")
      autocmd VimEnter * call add(g:evs, "VimEnter")
    ]],
      {}
    )

    -- VimEnter and UIEnter shouldn't be triggered until after attach
    local var_ok, var = child_session:request('nvim_get_var', 'evs')
    ok(var_ok)
    eq({}, var)

    local child_screen = Screen.new(40, 6)
    child_screen:attach(nil, child_session)
    child_screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*3
      {2:[No Name]             0,0-1          All}|
                                              |
    ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.Blue, bold = true },
        [2] = { reverse = true, bold = true },
      },
    }

    -- VimEnter and UIEnter should now be triggered
    var_ok, var = child_session:request('nvim_get_var', 'evs')
    ok(var_ok)
    eq({ 'VimEnter', ('UIEnter:%d'):format(api_info[1]) }, var)
  end)
end)
