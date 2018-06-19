local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local feed = helpers.feed
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local read_file = helpers.read_file
local retry = helpers.retry
local sleep = helpers.sleep
local iswin = helpers.iswin

describe('startup', function()
  before_each(function()
    clear()
    os.remove('Xtest_startup_ttyout')
  end)
  after_each(function()
    os.remove('Xtest_startup_ttyout')
  end)

  it('pipe at both ends: has("ttyin")==0 has("ttyout")==0', function()
    -- system() puts a pipe at both ends.
    local out = funcs.system({ nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                               '--cmd', nvim_set,
                               '-c', [[echo has('ttyin') has('ttyout')]],
                               '+q' })
    eq('0 0', out)
  end)
  it('with --embed: has("ttyin")==0 has("ttyout")==0', function()
    local screen = Screen.new(25, 3)
    -- Remote UI connected by --embed.
    screen:attach()
    command([[echo has('ttyin') has('ttyout')]])
    screen:expect([[
      ^                         |
      ~                        |
      0 0                      |
    ]])
  end)
  it('in a TTY: has("ttyin")==1 has("ttyout")==1', function()
    local screen = Screen.new(25, 3)
    screen:attach()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"echo has('ttyin') has('ttyout')\""]]
            ..[[, shellescape(v:progpath))]])
    screen:expect([[
      ^                         |
      1 1                      |
                               |
    ]])
  end)
  it('output to pipe: has("ttyin")==1 has("ttyout")==0', function()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[ -c q | cat -v"]]  -- Output to a pipe.
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      sleep(1)
      eq('1\n0\n',  -- stdin is a TTY, stdout is a pipe
         read_file('Xtest_startup_ttyout'))
    end)
  end)
  it('input from pipe: has("ttyin")==0 has("ttyout")==1', function()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal echo foo | ]]  -- Input from a pipe.
            ..[[%s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[ -c q -- -"]]
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      sleep(1)
      eq('0\n1\n',  -- stdin is a pipe, stdout is a TTY
         read_file('Xtest_startup_ttyout'))
    end)
  end)
  it('input from pipe (implicit) #7679', function()
    local screen = Screen.new(25, 3)
    screen:attach()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal echo foo | ]]  -- Input from a pipe.
            ..[[%s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"echo has('ttyin') has('ttyout')\""]]
            ..[[, shellescape(v:progpath))]])
    screen:expect([[
      ^foo                      |
      0 1                      |
                               |
    ]])
  end)
  it('input from pipe + file args #7679', function()
    eq('ohyeah\r\n0 0 bufs=3',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '--headless',
                     '+.print',
                     "+echo has('ttyin') has('ttyout') 'bufs='.bufnr('$')",
                     '+qall!',
                     '-',
                     'test/functional/fixtures/tty-test.c',
                     'test/functional/fixtures/shell-test.c',
                    },
                    { 'ohyeah', '' }))
  end)

  it('if stdin is empty: selects buffer 2, deletes buffer 1 #8561', function()
    eq('\r\n  2 %a   "file1"                        line 0\r\n  3      "file2"                        line 0',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '--headless',
                     '+ls!',
                     '+qall!',
                     '-',
                     'file1',
                     'file2',
                    },
                    { '' }))
  end)

  it('-e/-E interactive #7679', function()
    clear('-e')
    local screen = Screen.new(25, 3)
    screen:attach()
    feed("put ='from -e'<CR>")
    screen:expect([[
      :put ='from -e'          |
      from -e                  |
      :^                        |
    ]])

    clear('-E')
    screen = Screen.new(25, 3)
    screen:attach()
    feed("put ='from -E'<CR>")
    screen:expect([[
      :put ='from -E'          |
      from -E                  |
      :^                        |
    ]])
  end)

  it('stdin with -es/-Es #7679', function()
    local input = { 'append', 'line1', 'line2', '.', '%print', '' }
    local inputstr = table.concat(input, '\n')

    --
    -- -Es: read stdin as text
    --
    eq('partylikeits1999\n',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '-Es', '+.print', 'test/functional/fixtures/tty-test.c' },
                    { 'partylikeits1999', '' }))
    eq(inputstr,
       funcs.system({nvim_prog, '-i', 'NONE', '-Es', '+%print', '-' },
                    input))
    -- with `-u NORC`
    eq('thepartycontinues\n',
       funcs.system({nvim_prog, '-n', '-u', 'NORC', '-Es', '+.print' },
                    { 'thepartycontinues', '' }))
    -- without `-u`
    eq('thepartycontinues\n',
       funcs.system({nvim_prog, '-n', '-Es', '+.print' },
                    { 'thepartycontinues', '' }))

    --
    -- -es: read stdin as ex-commands
    --
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '-es', 'test/functional/fixtures/tty-test.c' },
                    { 'set encoding', '' }))
    eq('line1\nline2\n',
       funcs.system({nvim_prog, '-i', 'NONE', '-es', '-' },
                    input))
    -- with `-u NORC`
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-u', 'NORC', '-es' },
                    { 'set encoding', '' }))
    -- without `-u`
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-es' },
                    { 'set encoding', '' }))
  end)
end)

